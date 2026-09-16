import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("./worker.js", import.meta.url), "utf8")
  .replace("export default {", "const worker = {")
  .replaceAll("export class ", "class ");

const apple = { id: 1, name: "Apple", image: "apple.jpg" };
const skin = { id: 2, name: "Apple with skin", image: "apple-skin.jpg" };
const banana = { id: 4, name: "Banana", image: "banana.jpg" };

function action(name, args, id = "food-action") {
  return { type: "function_call", id, call_id: id, name,
    arguments: JSON.stringify(args), status: "completed" };
}

function food(catalogQuery, extra = {}) {
  return { name: catalogQuery, catalogQuery, mealType: "breakfast", calories: 999,
    protein: 99, carbs: 99, fats: 99, confidence: 0.5, source: "text",
    portionGrams: 150, kind: "product", ...extra };
}

function runtime(output, options = {}) {
  const requests = [];
  const upstream = [];
  const translations = [];
  const localizationLocales = [];
  const errors = [];
  const edge = new Map();
  const env = { OPENAI_API_KEY: "test-ai", SPOONACULAR_API_KEY: "test-catalog" };
  const context = vm.createContext({
    URL, URLSearchParams, Request, Response, Headers, TextEncoder, TextDecoder, AbortSignal,
    setTimeout, clearTimeout,
    reportError(error) { errors.push(String(error.stack || error)); },
    caches: { default: {
      async match(request) { return edge.get(request.url)?.clone(); },
      async put(request, response) { edge.set(request.url, response.clone()); },
    } },
    fetch: async (rawURL, init) => {
      const url = new URL(rawURL);
      if (url.origin === "https://api.openai.com") {
        assert.equal(url.pathname, "/v1/responses");
        requests.push(JSON.parse(init.body));
        assert.equal(requests.length, 1, "Catalog resolution must not re-run the conversation");
        return Response.json({ status: "completed", model: "gpt-6-astra", output });
      }
      assert.equal(url.origin, "https://api.spoonacular.com");
      upstream.push(url);
      if (options.unavailable) return Response.json({ message: "Quota exhausted" }, { status: 402 });
      const query = url.searchParams.get("query");
      if (url.pathname === "/food/ingredients/search") {
        return Response.json({ results: options.candidates?.[query] || [skin, apple] });
      }
      if (url.pathname === "/food/products/search") {
        return Response.json({ products: options.products?.[query] || [{ id: 10, title: "Apple pie", image: "apple-pie.jpg" }] });
      }
      if (url.pathname === "/recipes/complexSearch") {
        return Response.json({ results: options.recipes?.[query] || [] });
      }
      const product = url.pathname.match(/^\/food\/products\/(\d+)$/);
      if (product) {
        assert.ok(options.productDetails?.[product[1]], "Only a matching product should be hydrated");
        return Response.json(options.productDetails[product[1]]);
      }
      const ingredient = url.pathname.match(/^\/food\/ingredients\/(\d+)\/information$/);
      assert.ok(ingredient, `Unexpected catalog path: ${url.pathname}`);
      assert.equal(url.searchParams.get("amount"), "100");
      assert.equal(url.searchParams.get("unit"), "grams");
      const id = Number(ingredient[1]);
      const calories = { 1: 52, 2: 60, 4: 89, 5: 61 }[id];
      assert.ok(calories, "Only a matching ingredient should be hydrated");
      return Response.json({ id, amount: 100, unit: "grams", nutrition: { nutrients: [
        { name: "Calories", amount: calories },
        { name: "Protein", amount: 0.4 },
        { name: "Carbohydrates", amount: 14 },
        { name: "Fat", amount: 0.2 },
      ] } });
    },
    async translateQuery(_env, query) {
      translations.push(query);
      return { "Яблуко": "apple", "Яблуко зі шкіркою": "apple with skin" }[query] || query;
    },
    async localizeCatalog(_env, _path, data, locale) {
      localizationLocales.push(locale);
      if (options.collapseTranslatedTitles && locale?.startsWith("uk")) {
        return { ...data, results: data.results?.map(item => ({ ...item, name: "Яблуко" })) };
      }
      return data;
    },
  });
  vm.runInContext(source + `
    globalThis.worker = worker;
    translateFoodQueryToEnglish = translateQuery;
    localizeSpoonacularPayload = localizeCatalog;
    // Image generation has independent coverage. These assertions inspect the
    // actual matched catalog image delivered to that stage.
    enrichAssistantImages = async (_env, _ctx, _origin, calls) => calls;
    const lookup = findSpoonacularCatalogMatch;
    findSpoonacularCatalogMatch = async (...args) => {
      try { return await lookup(...args); }
      catch (error) { reportError(error); throw error; }
    };
    const proxy = handleSpoonacularProxy;
    handleSpoonacularProxy = async (...args) => {
      try { return await proxy(...args); }
      catch (error) { reportError(error); throw error; }
    };
  `, context);
  return {
    requests, upstream, translations, localizationLocales, errors,
    async chat(message, extra = {}) {
      const response = await context.worker.fetch(new Request("https://assistant.test/v1/chat", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ message, userContext: { locale: "uk",
          mealEditing: { mealType: "breakfast", entryIDs: ["entry-1"] } }, ...extra }),
      }), env, {});
      const body = await response.json();
      assert.equal(response.status, 200, JSON.stringify(body));
      assert.deepEqual(errors, [], "Unexpected errors must not masquerade as a catalog miss");
      return body;
    },
  };
}

test("Edit Meal resolves a generic apple through Spoonacular before the skin variant", async () => {
  const app = runtime([action("propose_food_log", food("Яблуко", { name: "Яблуко зі шкіркою" }))]);
  const result = await app.chat("Яблуко");
  const item = result.message.toolCalls[0].arguments;
  assert.equal(item.name, "Яблуко");
  assert.equal(item.calories, 78, JSON.stringify({ urls: app.upstream.map(url => String(url)), errors: app.errors }));
  assert.equal(item.protein, 0.6);
  assert.equal(item.carbs, 21);
  assert.equal(item.fats, 0.3);
  assert.equal(item.portionGrams, 150);
  assert.equal(item.kind, "ingredient");
  assert.equal(item.source, "spoonacular");
  assert.equal(item.catalogSource, "spoonacular");
  assert.equal(item.catalogExternalId, "1");
  assert.equal(item.imageURL, "https://img.spoonacular.com/ingredients_100x100/apple.jpg");
  assert.deepEqual(app.translations, ["Яблуко"]);
  assert.ok(app.upstream.some(url => url.pathname === "/food/ingredients/1/information"));
  assert.ok(!app.upstream.some(url => url.pathname === "/food/ingredients/2/information"));
  assert.match(app.requests[0].instructions, /bare food name means add that exact food/);
  assert.match(app.requests[0].instructions, /entryIDs/);
  assert.equal(app.requests[0].tool_choice, "auto");
});

test("an explicitly requested skin qualifier remains part of the matched food", async () => {
  const app = runtime([action("propose_food_log", food("Яблуко зі шкіркою", { portionGrams: 100 }))], {
    candidates: { "apple with skin": [apple, skin] },
  });
  const result = await app.chat("Яблуко зі шкіркою");
  const item = result.message.toolCalls[0].arguments;
  assert.equal(item.name, "Яблуко зі шкіркою");
  assert.equal(item.catalogExternalId, "2");
  assert.equal(item.calories, 60);
  assert.match(item.imageURL, /apple-skin\.jpg$/);
});

test("localized titles cannot collapse a qualified variant ahead of the original exact catalog name", async () => {
  const app = runtime([action("propose_food_log", food("Яблуко"))], { collapseTranslatedTitles: true });
  const result = await app.chat("Яблуко");
  assert.equal(result.message.toolCalls[0].arguments.catalogExternalId, "1");
  assert.equal(result.message.toolCalls[0].arguments.name, "Яблуко");
  assert.ok(app.localizationLocales.includes("en"));
  assert.ok(!app.localizationLocales.some(locale => locale?.startsWith("uk")));
});

test("the initial exact food name overrides an invented model name even without catalogQuery", async () => {
  const args = food("Banana");
  delete args.catalogQuery;
  const app = runtime([action("propose_food_log", args)]);
  const result = await app.chat("Яблуко");
  const item = result.message.toolCalls[0].arguments;
  assert.equal(item.name, "Яблуко");
  assert.equal(item.catalogExternalId, "1");
  assert.deepEqual(app.translations, ["Яблуко"]);
});

test("a qualified apple is a fallback only when the exact generic entry is absent", async () => {
  const app = runtime([action("propose_food_log", food("Яблуко", { portionGrams: 100 }))], {
    candidates: { apple: [skin] },
  });
  const result = await app.chat("Яблуко");
  const item = result.message.toolCalls[0].arguments;
  assert.equal(item.name, "Яблуко");
  assert.equal(item.catalogExternalId, "2");
  assert.equal(item.calories, 60);
});

test("replacement searches the requested new food and preserves its target", async () => {
  const app = runtime([action("propose_food_replace", {
    targetEntryId: "entry-1", targetName: "Toast",
    newItem: food("Banana", { name: "Banana with peel", portionGrams: 80 }),
  })], { candidates: { Banana: [banana] } });
  const result = await app.chat("Replace my toast with 80 g of banana");
  const args = result.message.toolCalls[0].arguments;
  assert.equal(args.targetEntryId, "entry-1");
  assert.equal(args.newItem.name, "Banana");
  assert.equal(args.newItem.calories, 71);
  assert.equal(args.newItem.catalogExternalId, "4");
  assert.ok(app.upstream.filter(url => url.searchParams.has("query"))
    .every(url => url.searchParams.get("query") === "Banana"));
});

test("unrelated catalog results retain the estimate instead of substituting a different food", async () => {
  const app = runtime([action("propose_food_log", food("Pear", {
    calories: 88, externalRecipeId: "invented-id", catalogExternalId: "invented-id",
    catalogSource: "spoonacular",
  }))]);
  const result = await app.chat("Pear");
  const item = result.message.toolCalls[0].arguments;
  assert.equal(item.name, "Pear");
  assert.equal(item.calories, 88);
  assert.equal(item.catalogSource, undefined);
  assert.equal(item.catalogExternalId, undefined);
  assert.equal(item.externalRecipeId, undefined);
  assert.ok(!app.upstream.some(url => url.pathname.endsWith("/information")));
});

test("Spoonacular failure keeps the requested identity and does not fail a valid proposal", async () => {
  const app = runtime([action("propose_food_log", food("Apple", { calories: 80 }))], { unavailable: true });
  const result = await app.chat("Apple");
  assert.equal(result.message.toolCalls[0].arguments.name, "Apple");
  assert.equal(result.message.toolCalls[0].arguments.calories, 80);
  assert.equal(result.message.toolCalls[0].arguments.catalogSource, undefined);
});

test("mass-based milk nutrition cannot overwrite a requested milliliter portion", async () => {
  const app = runtime([action("propose_food_log", food("Milk", {
    portionGrams: null, portionMilliliters: 250, calories: 153,
  }))], { candidates: { Milk: [{ id: 5, name: "Milk", image: "milk.jpg" }] } });
  const result = await app.chat("250 ml milk");
  const item = result.message.toolCalls[0].arguments;
  assert.equal(item.calories, 153);
  assert.equal(item.portionGrams, null);
  assert.equal(item.portionMilliliters, 250);
  assert.equal(item.source, "text");
  assert.equal(item.catalogSource, undefined);
  assert.equal(item.catalogExternalId, undefined);
});

test("a recipe without serving weight cannot replace nutrition for an explicit gram portion", async () => {
  const app = runtime([action("propose_food_log", food("Chicken soup", {
    portionGrams: 80, calories: 123, kind: "recipe",
  }))], { candidates: { "Chicken soup": [] }, recipes: { "Chicken soup": [{
    id: 20, title: "Chicken soup", image: "https://img.spoonacular.com/recipes/20-312x231.jpg",
    nutrition: { nutrients: [{ name: "Calories", amount: 450 }] },
  }] } });
  const result = await app.chat("80 g chicken soup");
  const item = result.message.toolCalls[0].arguments;
  assert.equal(item.calories, 123);
  assert.equal(item.portionGrams, 80);
  assert.equal(item.source, "text");
  assert.equal(item.catalogSource, undefined);
  assert.equal(item.catalogExternalId, undefined);
});

test("a packaged drink measured in cups cannot be scaled as if the serving were milliliters", async () => {
  const app = runtime([action("propose_food_log", food("Orange juice", {
    portionGrams: null, portionMilliliters: 250, calories: 115,
  }))], { candidates: { "Orange juice": [] }, products: { "Orange juice": [{
    id: 6, title: "Orange juice", image: "orange-juice.jpg",
  }] }, productDetails: { 6: {
    title: "Orange juice", servings: { size: 1, unit: "cup" },
    nutrition: { nutrients: [{ name: "Calories", amount: 110 }] },
  } } });
  const result = await app.chat("250 ml orange juice");
  const item = result.message.toolCalls[0].arguments;
  assert.equal(item.calories, 115);
  assert.equal(item.portionMilliliters, 250);
  assert.equal(item.portionGrams, null);
  assert.equal(item.source, "text");
  assert.equal(item.catalogSource, undefined);
});

test("multiple food additions search each extracted food rather than the whole message", async () => {
  const app = runtime([
    action("propose_food_log", food("Apple"), "apple-log"),
    action("propose_food_log", food("Banana"), "banana-log"),
  ], { candidates: { Apple: [apple], Banana: [banana] } });
  const result = await app.chat("Add an apple and a banana to breakfast");
  assert.deepEqual(result.message.toolCalls.map(call => call.arguments.catalogExternalId), ["1", "4"]);
  const queries = new Set(app.upstream.map(url => url.searchParams.get("query")).filter(Boolean));
  assert.deepEqual([...queries].sort(), ["Apple", "Banana"]);
});

test("questions and clarification do not trigger food search or force a food log", async () => {
  const app = runtime([{ type: "message", role: "assistant", content: [
    { type: "output_text", text: "Який саме продукт ви хочете замінити?" },
  ] }]);
  const result = await app.chat("Заміни це");
  assert.equal(result.hasActions, false);
  assert.deepEqual(result.message.toolCalls, []);
  assert.equal(app.upstream.length, 0);
  assert.equal(app.requests[0].tool_choice, "auto");
});

test("meal ideas remain suggestions instead of becoming catalog food logs", async () => {
  const app = runtime([action("propose_meal_suggestions", {
    mealType: "breakfast", options: [{ title: "Oatmeal", calories: 300,
      protein: 10, carbs: 40, fats: 9, ingredients: ["Oats"], steps: ["Cook oats"] }],
  })]);
  const result = await app.chat("What could I eat for breakfast?");
  assert.equal(result.message.toolCalls[0].name, "propose_meal_suggestions");
  assert.equal(app.upstream.length, 0);
});
