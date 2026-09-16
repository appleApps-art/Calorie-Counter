import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("./worker.js", import.meta.url), "utf8")
  .replace("export default {", "const worker = {")
  .replaceAll("export class ", "class ");

function runtime(storage = new Map()) {
  const edge = new Map();
  const upstream = [];
  const translations = [];
  const paths = [];
  const storageReads = [];
  const state = { translationFails: false, upstreamFails: false, total: 45 };
  const context = vm.createContext({
    URL, Request, Response, Headers, TextEncoder, TextDecoder, AbortSignal,
    setTimeout, clearTimeout,
    fetch: async () => { throw new Error("Unexpected external request"); },
    caches: { default: {
      async match(request) { return edge.get(request.url)?.clone(); },
      async put(request, response) { edge.set(request.url, response.clone()); },
    } },
    async upstreamRequest(rawURL) {
      const url = new URL(rawURL);
      const query = url.searchParams.get("query");
      const offset = Number(url.searchParams.get("offset"));
      const number = Number(url.searchParams.get("number"));
      upstream.push({ query, offset, number });
      paths.push(url.pathname);
      if (state.upstreamFails) return new Response("Unavailable", { status: 503 });
      const results = Array.from({ length: Math.max(0, Math.min(number, state.total - offset)) }, (_, index) => ({
        id: `${query}-${offset + index}`, name: `${query} ${offset + index}`,
        nutrition: url.searchParams.get("addRecipeNutrition") === "true" ? { nutrients: [{ name: "Calories", amount: 320 }] } : undefined,
        title: state.recipeTitle || `Chicken soup ${offset + index}`, image: "https://img.spoonacular.com/recipes/meal-312x231.jpg",
      }));
      return Response.json({ results, totalResults: state.total });
    },
    async translate(_env, language, values) {
      translations.push({ language, values: Object.values(values) });
      if (state.translationFails) return {};
      if (state.partialTranslation) return Object.fromEntries(Object.keys(values).map((key) => [key, "Курячий chicken"]));
      return Object.fromEntries(Object.entries(values).map(([key, title]) => [
        key, language === "uk" ? `Їжа ${title.replace(/[a-z]+/g, "").trim()}` : `Aliment ${title}`,
      ]));
    },
  });
  vm.runInContext(source + `
    fetchSpoonacularWithRetry = upstreamRequest;
    translateKeyedObject = translate;
    globalThis.api = { home: foodSearchCatalogResponse, page: foodSearchCatalogSectionResponse,
      sections: FOOD_SEARCH_SPOONACULAR_SECTIONS, localizeCatalogItems };
  `, context);
  const env = {
    SPOONACULAR_API_KEY: "test", OPENAI_API_KEY: "test",
    BITY_BUCKET: {
      async get(key) {
        storageReads.push(key);
        if (state.storageFailures?.[key] > 0) {
          state.storageFailures[key]--;
          throw new Error("Temporary R2 read failure");
        }
        const body = storage.get(key);
        return body ? { async json() { return JSON.parse(body); } } : null;
      },
      async put(key, body) { storage.set(key, body); },
    },
  };
  return { ...context.api, env, state, upstream, translations, storage, paths, storageReads };
}

test("home has the seven Figma sections and translates only two items each", async () => {
  const app = runtime();
  const background = [];
  const response = await app.home(app.env, { waitUntil: (work) => background.push(work) }, "uk_UA", false);
  const data = await response.json();
  assert.equal(response.status, 200);
  assert.deepEqual(data.sections.map((section) => section.id), [
    "vegetablesGreens", "fruitsBerries", "meatPoultry", "fishSeafood", "dairyEggs", "grainsCereals", "beverages",
  ]);
  assert.ok(data.sections.every((section) => section.items.length === 2));
  assert.ok(data.sections.flatMap((section) => section.items).every((item) => item.name.startsWith("Їжа")));
  await Promise.all(background);
  assert.equal(app.translations.flatMap((call) => call.values).length, 14);
  assert.equal(app.upstream.length, 7);
});

test("More loads one page, reuses preview translations, then fetches and translates the next page", async () => {
  const app = runtime();
  const home = await (await app.home(app.env, null, "uk", false)).json();
  const previousTranslations = app.translations.flatMap((call) => call.values).length;
  const first = await (await app.page(app.env, null, "uk", "vegetablesGreens", 0, 20)).json();
  assert.equal(first.items.length, 20);
  assert.equal(first.nextOffset, 20);
  assert.equal(first.hasMore, true);
  assert.deepEqual(first.items.slice(0, 2), home.sections[0].items);
  assert.equal(app.translations.flatMap((call) => call.values).length - previousTranslations, 18);
  assert.equal(app.upstream.length, 7);
  const second = await (await app.page(app.env, null, "uk", "vegetablesGreens", 20, 20)).json();
  assert.equal(second.items.length, 20);
  assert.equal(second.nextOffset, 40);
  assert.equal(app.upstream.length, 8);
  assert.deepEqual(app.upstream.at(-1), { query: "tomato", offset: 20, number: 20 });
  assert.equal(new Set([...first.items, ...second.items].map((item) => item.externalId)).size, 40);
  assert.equal(app.translations.flatMap((call) => call.values).length - previousTranslations, 38);
});

test("source expansion appends the next query without reordering or skipping the previous page", async () => {
  const app = runtime();
  app.state.total = 3;
  const first = await (await app.page(app.env, null, "en", "vegetablesGreens", 0, 5)).json();
  const second = await (await app.page(app.env, null, "en", "vegetablesGreens", first.nextOffset, 5)).json();
  assert.deepEqual([...first.items, ...second.items].map((item) => item.externalId), [
    "tomato-0", "tomato-1", "tomato-2", "broccoli-0", "broccoli-1", "broccoli-2", "lettuce-0", "lettuce-1", "lettuce-2", "cucumber-0",
  ]);
});

test("cold workers reuse localized home and pages from R2 without Spoonacular or AI", async () => {
  const original = runtime();
  await original.home(original.env, null, "uk", false);
  const expected = await (await original.page(original.env, null, "uk", "meatPoultry", 0, 20)).json();
  const cold = runtime(original.storage);
  cold.state.upstreamFails = true;
  cold.state.translationFails = true;
  const page = await (await cold.page(cold.env, null, "uk-UA", "meatPoultry", 0, 20)).json();
  const home = await (await cold.home(cold.env, null, "uk-UA", false)).json();
  assert.deepEqual(page, expected);
  assert.equal(home.sections.length, 7);
  assert.equal(cold.upstream.length, 0);
  assert.equal(cold.translations.length, 0);
});

test("failed translation returns retryable failure and does not cache English as Ukrainian", async () => {
  const app = runtime();
  app.state.translationFails = true;
  const failed = await app.page(app.env, null, "uk", "fishSeafood", 0, 20);
  assert.equal(failed.status, 503);
  assert.equal(failed.headers.get("cache-control"), "no-store");
  assert.ok(![...app.storage.keys()].some((key) => key.includes("/uk/")));
  app.state.translationFails = false;
  const recovered = await app.page(app.env, null, "uk", "fishSeafood", 0, 20);
  assert.equal(recovered.status, 200);
  assert.ok((await recovered.json()).items.every((item) => item.localizedLanguage === "uk"));
  assert.equal(app.upstream.length, 1);
});

test("pages and translation completion are isolated by language including Latin-script locales", async () => {
  const app = runtime();
  const uk = await (await app.page(app.env, null, "uk", "beverages", 0, 3)).json();
  const fr = await (await app.page(app.env, null, "fr", "beverages", 0, 3)).json();
  assert.ok(uk.items.every((item) => item.name.startsWith("Їжа")));
  assert.ok(fr.items.every((item) => item.name.startsWith("Aliment")));
  assert.equal(app.translations.length, 2);
  assert.equal(app.upstream.length, 1);
});

test("simultaneous requests share page fetching and translation", async () => {
  const app = runtime();
  const responses = await Promise.all(Array.from({ length: 3 }, () => app.page(app.env, null, "uk", "dairyEggs", 0, 20)));
  assert.ok(responses.every((response) => response.status === 200));
  assert.equal(app.upstream.length, 1);
  assert.equal(app.translations.length, 1);
});

test("catalog exhaustion returns a stable empty last page instead of restarting a fallback catalog", async () => {
  const app = runtime();
  app.state.total = 1;
  let offset = 0;
  let hasMore = true;
  const ids = [];
  while (hasMore) {
    const response = await app.page(app.env, null, "uk", "beverages", offset, 3);
    assert.equal(response.status, 200);
    const page = await response.json();
    ids.push(...page.items.map((item) => item.externalId));
    assert.ok(page.nextOffset > offset);
    offset = page.nextOffset;
    hasMore = page.hasMore;
  }
  assert.equal(ids.length, 12);
  assert.equal(new Set(ids).size, 12);
  const end = await (await app.page(app.env, null, "uk", "beverages", offset, 3)).json();
  assert.deepEqual(end.items, []);
  assert.equal(end.nextOffset, offset);
  assert.equal(end.hasMore, false);
});


test("partially translated English names are rejected and remain retryable", async () => {
  const app = runtime();
  app.state.partialTranslation = true;
  assert.equal((await app.page(app.env, null, "uk", "meatPoultry", 0, 2)).status, 503);
  assert.ok(![...app.storage.keys()].some((key) => key.includes("/uk/")));
});

test("an upstream failure preserves the raw cursor for a successful retry", async () => {
  const app = runtime();
  const first = await (await app.page(app.env, null, "uk", "meatPoultry", 0, 20)).json();
  app.state.upstreamFails = true;
  assert.equal((await app.page(app.env, null, "uk", "meatPoultry", 20, 20)).status, 503);
  app.state.upstreamFails = false;
  const second = await (await app.page(app.env, null, "uk", "meatPoultry", 20, 20)).json();
  assert.deepEqual(app.upstream.map((call) => call.offset), [0, 20, 20]);
  assert.equal(new Set([...first.items, ...second.items].map((item) => item.externalId)).size, 40);
});

test("home uses only two localized stored fallback items per section when APIs are unavailable", async () => {
  const fallback = readFileSync(new URL("../../Calorie Counter/Calorie Counter/Resources/food-search-catalog.json", import.meta.url), "utf8");
  const app = runtime(new Map([["food-search-catalog.json", fallback]]));
  app.state.upstreamFails = true;
  const data = await (await app.home(app.env, null, "uk", false)).json();
  assert.equal(data.sections.length, 7);
  assert.ok(data.sections.every((section) => section.items.length === 2));
  assert.ok(data.sections.flatMap((section) => section.items).every((item) => /[а-яіїєґ]/i.test(item.name)));
  assert.equal(app.translations.length, 0);
});


test("shared browse translates exactly two meals and two products from the correct sources", async () => {
  const app = runtime();
  const meal = await (await app.page(app.env, null, "uk", "preparedMeals", 0, 2)).json();
  const product = await (await app.page(app.env, null, "uk", "products", 0, 2)).json();
  assert.equal(meal.items.length, 2);
  assert.equal(meal.items[0].calories, 320);
  assert.equal(product.items.length, 2);
  assert.ok(meal.items.every(item => item.kind === "recipe" && item.localizedLanguage === "uk"));
  assert.ok(product.items.every(item => item.kind === "ingredient" && item.localizedLanguage === "uk"));
  assert.deepEqual(app.paths, ["/recipes/complexSearch", "/food/ingredients/search"]);
  assert.equal(app.translations.flatMap(call => call.values).length, 4);
});

test("prepared meal More reuses two preview translations and paginates only meals", async () => {
  const app = runtime();
  const preview = await (await app.page(app.env, null, "uk", "preparedMeals", 0, 2)).json();
  const first = await (await app.page(app.env, null, "uk", "preparedMeals", 0, 20)).json();
  assert.deepEqual(first.items.slice(0, 2), preview.items);
  assert.deepEqual(app.translations.map(call => call.values.length), [2, 18]);
  const second = await (await app.page(app.env, null, "uk", "preparedMeals", 20, 20)).json();
  assert.equal(second.nextOffset, 40);
  assert.equal(new Set([...first.items, ...second.items].map(item => item.externalId)).size, 40);
  assert.ok(second.items.every(item => item.kind === "recipe"));
  assert.deepEqual(app.upstream.map(call => call.offset), [0, 20]);
  assert.ok(app.paths.every(path => path === "/recipes/complexSearch"));
  const cold = runtime(app.storage);
  cold.state.upstreamFails = true;
  cold.state.translationFails = true;
  assert.deepEqual(await (await cold.page(cold.env, null, "uk", "preparedMeals", 20, 20)).json(), second);
  assert.equal(cold.upstream.length, 0);
  assert.equal(cold.translations.length, 0);
});

test("prepared meals use existing recipe storage before fetching Spoonacular and append stably", async () => {
  const recipes = [{ id: "stored-1", title: "Borscht", imageURL: "https://example.com/borscht.jpg" },
                   { id: "stored-2", title: "Chicken pilaf", imageURL: "https://example.com/pilaf.jpg" }];
  const app = runtime(new Map([["recipe-sections/v10/en-US.json", JSON.stringify({ sections: [{ recipes }] })]]));
  const preview = await (await app.page(app.env, null, "uk", "preparedMeals", 0, 2)).json();
  assert.equal(app.upstream.length, 0);
  assert.equal(app.translations.flatMap(call => call.values).length, 2);
  const more = await (await app.page(app.env, null, "uk", "preparedMeals", 0, 20)).json();
  assert.deepEqual(more.items.slice(0, 2), preview.items);
  assert.equal(more.items.length, 20);
  assert.equal(app.upstream.length, 1);
  assert.deepEqual(app.translations.map(call => call.values.length), [2, 18]);
});

test("a full stored meal catalog is exhausted without extra requests or a stuck final page", async () => {
  const recipes = Array.from({ length: 130 }, (_, i) => ({ id: `stored-${i}`, title: `Soup ${i}`, imageURL: "https://example.com/soup.jpg" }));
  const app = runtime(new Map([["recipe-sections/v10/en-US.json", JSON.stringify({ sections: [{ recipes }] })]]));
  const last = await (await app.page(app.env, null, "en", "preparedMeals", 100, 20)).json();
  assert.equal(last.items.length, 20);
  assert.equal(last.nextOffset, 120);
  assert.equal(last.hasMore, false);
  const end = await (await app.page(app.env, null, "en", "preparedMeals", 120, 20)).json();
  assert.deepEqual(end.items, []);
  assert.equal(end.hasMore, false);
  assert.equal(app.upstream.length, 0);
});

test("shared products reuse diverse stored categories before another Spoonacular request", async () => {
  const fallback = readFileSync(new URL("../../Calorie Counter/Calorie Counter/Resources/food-search-catalog.json", import.meta.url), "utf8");
  const app = runtime(new Map([["food-search-catalog.json", fallback]]));
  const raw = JSON.parse(fallback);
  const preview = await (await app.page(app.env, null, "uk", "products", 0, 2)).json();
  assert.equal(preview.items.length, 2);
  assert.deepEqual(preview.items.map(item => item.externalId), raw.sections.slice(0, 2).map(section => section.items[0].id));
  assert.ok(preview.items.every(item => item.source === "catalog" && item.kind === "product"));
  assert.equal(preview.items[0].amount, raw.sections[0].items[0].amount);
  assert.equal(app.upstream.length, 0);
  assert.equal(app.translations.length, 0);
  assert.equal(preview.items[0].name, raw.sections[0].items[0].name.uk);
  assert.equal(preview.items[0].summary, "");
  const more = await (await app.page(app.env, null, "uk", "products", 0, 20)).json();
  assert.equal(more.items.length, 20);
  assert.deepEqual(more.items.slice(0, 2), preview.items);
  assert.equal(app.upstream.length, 0);
});

test("Ukrainian prepared meals use existing uk-UA storage when en-US is absent and both upstreams fail", async () => {
  const recipes = [
    { externalId: "879449", source: "spoonacular", kind: "recipe", title: "Курячий салат", sourceTitle: "Cranberry Pecan Greek Yogurt Chicken Salad", imageURL: "https://img.spoonacular.com/recipes/879449-312x231.png" },
    { externalId: "633754", source: "spoonacular", kind: "recipe", title: "Рататуй", sourceTitle: "Baked Ratatouille", imageURL: "https://img.spoonacular.com/recipes/633754-312x231.jpg" },
  ];
  const old = { sections: [{ id: "preparedMeals", items: [{ externalId: "945221", name: "Watching What I Eat" }], queryIndex: 0, queryOffset: 20 }] };
  const app = runtime(new Map([
    ["recipe-sections/v10/uk-UA.json", JSON.stringify({ language: "uk", sections: [{ recipes }] })],
    ["food-search-catalog/spoonacular/v4/en/section-preparedMeals.json", JSON.stringify(old)],
  ]));
  app.state.upstreamFails = true;
  app.state.translationFails = true;
  const response = await app.page(app.env, null, "uk", "preparedMeals", 0, 2);
  assert.equal(response.status, 200);
  const page = await response.json();
  assert.deepEqual(page.items.map(item => item.name), recipes.map(item => item.title));
  assert.deepEqual(page.items.map(item => item.kind), ["recipe", "recipe"]);
  assert.ok(page.items.every(item => item.localizedLanguage === "uk"));
  assert.equal(app.upstream.length, 0);
  assert.equal(app.translations.length, 0);
  assert.ok(app.storage.has("food-search-catalog/spoonacular/v4/en/section-preparedMeals-v2.json"));
});

test("stored native recipe titles support preview, More and subsequent pages without translation", async () => {
  const recipes = Array.from({ length: 25 }, (_, index) => ({ externalId: String(index), title: `Страва ${index}`, sourceTitle: `Meal ${index}`, imageURL: "https://example.com/meal.jpg" }));
  const app = runtime(new Map([["recipe-sections/v10/uk-UA.json", JSON.stringify({ language: "uk", sections: [{ recipes }] })]]));
  const preview = await (await app.page(app.env, null, "uk-UA", "preparedMeals", 0, 2)).json();
  const first = await (await app.page(app.env, null, "uk-UA", "preparedMeals", 0, 20)).json();
  assert.deepEqual(first.items.slice(0, 2), preview.items);
  const second = await (await app.page(app.env, null, "uk-UA", "preparedMeals", 20, 2)).json();
  assert.deepEqual(second.items.map(item => item.name), ["Страва 20", "Страва 21"]);
  assert.equal(second.nextOffset, 22);
  assert.equal(app.upstream.length, 0);
  assert.equal(app.translations.length, 0);
});

test("native recipe translations are matched by source id even after a different language seeded the catalog", async () => {
  const english = [{ externalId: "999", title: "Pea soup", imageURL: "https://example.com/soup.jpg" }];
  const ukrainian = Array.from({ length: 140 }, (_, index) => ({ externalId: String(index), title: `Страва ${index}`, sourceTitle: `Meal ${index}`, imageURL: "https://example.com/meal.jpg" }));
  ukrainian.push({ ...english[0], title: "Гороховий суп", sourceTitle: "Pea soup" });
  const app = runtime(new Map([
    ["recipe-sections/v10/en.json", JSON.stringify({ language: "en", sections: [{ recipes: english }] })],
    ["recipe-sections/v10/uk-UA.json", JSON.stringify({ language: "uk", sections: [{ recipes: ukrainian }] })],
  ]));
  await app.page(app.env, null, "en", "preparedMeals", 0, 1);
  app.state.translationFails = true;
  const response = await app.page(app.env, null, "uk-UA", "preparedMeals", 0, 1);
  assert.equal(response.status, 200);
  const page = await response.json();
  assert.equal(page.items[0].externalId, "999");
  assert.equal(page.items[0].name, "Гороховий суп");
  assert.equal(app.translations.length, 0);
});

test("prepared meal translation retains the full original title after a publisher prefix", async () => {
  const app = runtime();
  app.state.recipeTitle = "Watching What I Eat: Peanut Butter Banana Oat Cookies";
  const response = await app.page(app.env, null, "uk", "preparedMeals", 0, 2);
  assert.equal(response.status, 200);
  assert.equal(app.translations[0].values[0], app.state.recipeTitle);
});

test("one unavailable translation does not block ready meals or corrupt the source cursor", async () => {
  const recipes = [
    { externalId: "1", title: "Рататуй", sourceTitle: "Ratatouille", imageURL: "https://example.com/ratatouille.jpg" },
    { externalId: "2", title: "Chicken Soup", sourceTitle: "Chicken Soup", imageURL: "https://example.com/soup.jpg" },
    { externalId: "3", title: "Омлет", sourceTitle: "Omelette", imageURL: "https://example.com/omelette.jpg" },
  ];
  const app = runtime(new Map([["recipe-sections/v10/uk-UA.json", JSON.stringify({ language: "uk", sections: [{ recipes }] })]]));
  app.state.translationFails = true;
  const response = await app.page(app.env, null, "uk", "preparedMeals", 0, 2);
  assert.equal(response.status, 200);
  const page = await response.json();
  assert.deepEqual(page.items.map(item => item.name), ["Рататуй"]);
  assert.equal(page.nextOffset, 2);
  assert.equal(page.hasMore, true);
  const next = await (await app.page(app.env, null, "uk", "preparedMeals", page.nextOffset, 1)).json();
  assert.deepEqual(next.items.map(item => item.name), ["Омлет"]);
  assert.equal(next.nextOffset, 3);
});


test("a transient cold R2 read is retried before falling back to Spoonacular or AI", async () => {
  const key = "recipe-sections/v10/uk-UA.json";
  const recipes = [{ externalId: "633754", title: "Рататуй", sourceTitle: "Ratatouille", imageURL: "https://example.com/ratatouille.jpg" }];
  const app = runtime(new Map([[key, JSON.stringify({ language: "uk", sections: [{ recipes }] })]]));
  app.state.storageFailures = { [key]: 1 };
  app.state.upstreamFails = true;
  app.state.translationFails = true;
  const response = await app.page(app.env, null, "uk-UA", "preparedMeals", 0, 1);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).items[0].name, "Рататуй");
  assert.equal(app.storageReads.filter(read => read === key).length, 2);
  assert.equal(app.storageReads.filter(read => read === "recipe-sections/v10/en-US.json").length, 1);
  assert.equal(app.upstream.length, 0);
  assert.equal(app.translations.length, 0);
});

test("an R2 outage is not cached as an absent catalog and a later request recovers", async () => {
  const key = "recipe-sections/v10/uk-UA.json";
  const recipes = [{ externalId: "633754", title: "Рататуй", sourceTitle: "Ratatouille", imageURL: "https://example.com/ratatouille.jpg" }];
  const app = runtime(new Map([[key, JSON.stringify({ language: "uk", sections: [{ recipes }] })]]));
  app.state.storageFailures = { [key]: 2 };
  const failed = await app.page(app.env, null, "uk-UA", "preparedMeals", 0, 1);
  assert.equal(failed.status, 503);
  assert.equal(failed.headers.get("cache-control"), "no-store");
  assert.equal(app.upstream.length, 0);
  assert.ok(!app.storage.has("food-search-catalog/spoonacular/v4/en/section-preparedMeals-v2.json"));
  const recovered = await app.page(app.env, null, "uk-UA", "preparedMeals", 0, 1);
  assert.equal(recovered.status, 200);
  assert.equal((await recovered.json()).items[0].name, "Рататуй");
  assert.equal(app.translations.length, 0);
});
