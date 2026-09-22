import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("./worker.js", import.meta.url), "utf8")
  .replace("export default {", "const worker = {")
  .replaceAll("export class ", "class ");

const env = { OPENAI_API_KEY: "test-ai", SPOONACULAR_API_KEY: "test-catalog" };
const translations = { "Яйця": "eggs", "Шпинат": "spinach", "Оливкова олія": "olive oil" };

function information(id, overrides = {}) {
  return {
    id,
    title: `Recipe ${id}`,
    image: `https://img.spoonacular.com/recipes/${id}-556x370.jpg`,
    readyInMinutes: 15,
    servings: 1,
    dishTypes: ["breakfast"],
    cuisines: [],
    vegetarian: true,
    vegan: false,
    nutrition: {
      nutrients: [
        { name: "Calories", amount: 210, unit: "kcal" },
        { name: "Protein", amount: 14, unit: "g" },
        { name: "Carbohydrates", amount: 4, unit: "g" },
        { name: "Fat", amount: 15, unit: "g" },
      ],
    },
    extendedIngredients: [
      { id: 1, nameClean: "egg", name: "eggs" },
      { id: 2, nameClean: "spinach", name: "spinach" },
      { id: 3, nameClean: "salt", name: "salt" },
    ],
    analyzedInstructions: [{ steps: [{ number: 1, step: "Whisk the eggs." }, { number: 2, step: "Cook with spinach." }] }],
    ...overrides,
  };
}

const chefRecipe = {
  title: "Омлет зі шпинатом",
  summary: "Швидкий сніданок.",
  servings: 1,
  readyInMinutes: 10,
  calories: 220,
  protein: 15,
  carbs: 3,
  fats: 16,
  ingredients: [
    { from: "Яйця", name: "Яйця", amount: 2, unit: "pcs" },
    { from: "Шпинат", name: "Шпинат", amount: 50, unit: "g" },
    { from: "salt", name: "Сіль", amount: 1, unit: "g" },
  ],
  steps: ["Збийте яйця.", "Обсмажте зі шпинатом."],
};

function runtime({ pantry = [], details = {}, chef = [chefRecipe] } = {}) {
  const calls = [];
  const edge = new Map();
  const bucket = new Map();
  const runtimeEnv = {
    ...env,
    BITY_BUCKET: {
      async get(key) {
        return bucket.has(key) ? { json: async () => JSON.parse(bucket.get(key)) } : null;
      },
      async put(key, value) { bucket.set(key, String(value)); },
    },
  };
  let chefAttempt = 0;
  const context = vm.createContext({
    URL, URLSearchParams, Request, Response, Headers, TextEncoder, TextDecoder, AbortSignal, AbortController,
    setTimeout, clearTimeout, console, crypto,
    caches: { default: {
      async match(request) { return edge.get(request.url)?.clone(); },
      async put(request, response) { edge.set(request.url, response.clone()); },
    } },
    fetch: async (rawURL, init) => {
      const url = new URL(rawURL);
      if (url.origin === "https://api.openai.com") {
        const body = JSON.parse(init.body);
        const system = String(body.messages?.[0]?.content || "");
        if (system.startsWith("You are a chef")) {
          calls.push({ kind: "chef", body });
          const reply = chef[Math.min(chefAttempt, chef.length - 1)];
          chefAttempt += 1;
          return Response.json({ choices: [{ message: { content: JSON.stringify(reply) } }] });
        }
        const query = body.messages?.[1]?.content;
        calls.push({ kind: "translate", query });
        return Response.json({ choices: [{ message: { content: translations[query] || query } }] });
      }
      assert.equal(url.origin, "https://api.spoonacular.com");
      calls.push({ kind: "catalog", url });
      if (url.pathname === "/recipes/findByIngredients") return Response.json(pantry);
      const id = Number(url.pathname.match(/\/recipes\/(\d+)\/information/)?.[1]);
      return details[id] ? Response.json(details[id]) : new Response("not found", { status: 404 });
    },
  });
  vm.runInContext(source + `
    globalThis.worker = worker;
    localizeSpoonacularPayload = async (_env, _path, data) => data;
  `, context);
  return {
    calls,
    bucket,
    edge,
    async create(body, path = "/v1/recipes/create", override = null) {
      const payload = override ?? { locale: "uk_UA", ...body };
      const response = await context.worker.fetch(new Request(`https://assistant.test${path}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
      }), runtimeEnv, { waitUntil() {} });
      return { status: response.status, body: await response.json() };
    },
  };
}

test("a catalog recipe that needs only the user's products is returned as is", async () => {
  const app = runtime({
    pantry: [{ id: 11, missedIngredientCount: 0 }, { id: 12, missedIngredientCount: 2 }],
    details: { 11: information(11) },
  });
  const result = await app.create({ ingredients: ["Яйця", "Шпинат"], type: "breakfast" });
  assert.equal(result.status, 200);
  assert.equal(result.body.source, "catalog");
  assert.equal(result.body.recipe.id, 11);
  const search = app.calls.find((call) => call.kind === "catalog" && call.url.pathname === "/recipes/findByIngredients").url;
  assert.equal(search.searchParams.get("ingredients"), "eggs,spinach");
  assert.equal(search.searchParams.get("ranking"), "2");
  assert.equal(search.searchParams.get("ignorePantry"), "true");
  // The recipe with missing products is never even opened.
  assert.ok(!app.calls.some((call) => call.kind === "catalog" && call.url.pathname.includes("/recipes/12/")));
});

test("a catalog recipe with a product the user lacks falls through to the AI", async () => {
  const app = runtime({
    pantry: [{ id: 21, missedIngredientCount: 0 }],
    details: {
      21: information(21, {
        extendedIngredients: [
          { id: 1, nameClean: "egg", name: "eggs" },
          { id: 4, nameClean: "butter", name: "butter" },
        ],
      }),
    },
  });
  const result = await app.create({ ingredients: ["Яйця", "Шпинат"] });
  assert.equal(result.body.source, "ai");
});

test("catalog recipes outside the picked calories, time, meal or diet are skipped", async () => {
  const cases = [
    [{ nutrition: { nutrients: [
      { name: "Calories", amount: 900, unit: "kcal" },
      { name: "Protein", amount: 14, unit: "g" },
      { name: "Carbohydrates", amount: 4, unit: "g" },
      { name: "Fat", amount: 15, unit: "g" },
    ] } }, { maxCalories: 400 }],
    [{ readyInMinutes: 90 }, { maxReadyTime: 30 }],
    [{ dishTypes: ["dessert"] }, { type: "breakfast" }],
    [{ vegetarian: false }, { diet: "vegetarian" }],
  ];
  for (const [override, filters] of cases) {
    const app = runtime({ pantry: [{ id: 31, missedIngredientCount: 0 }], details: { 31: information(31, override) } });
    const result = await app.create({ ingredients: ["Яйця", "Шпинат"], ...filters });
    assert.equal(result.body.source, "ai", JSON.stringify(filters));
  }
});

test("the AI recipe comes back complete, in the user's language, with a photo", async () => {
  const app = runtime({ pantry: [] });
  const result = await app.create({ ingredients: ["Яйця", "Шпинат"], type: "breakfast", maxCalories: 300 });
  assert.equal(result.status, 200);
  const recipe = result.body.recipe;
  assert.equal(result.body.source, "ai");
  assert.equal(recipe.id, 0);
  assert.equal(recipe.title, "Омлет зі шпинатом");
  assert.equal(recipe.sourceName, "Bity AI");
  assert.match(recipe.image, /^https:\/\/assistant\.test\/v1\/food\/image\?name=/);
  assert.deepEqual(recipe.nutrition.nutrients.map((item) => item.name), ["Calories", "Protein", "Carbohydrates", "Fat"]);
  assert.deepEqual(recipe.analyzedInstructions[0].steps.map((step) => step.number), [1, 2]);
  assert.deepEqual(recipe.extendedIngredients.map((item) => item.name), ["Яйця", "Шпинат", "Сіль"]);
  // Counts read in the user's language; grams stay "g" for the app to convert.
  assert.deepEqual(recipe.extendedIngredients.map((item) => item.unit), ["шт", "g", "g"]);
  assert.equal(recipe.extendedIngredients[0].original, "Яйця 2 шт");
  assert.deepEqual(recipe.dishTypes, ["breakfast"]);

  const chef = app.calls.find((call) => call.kind === "chef").body;
  assert.equal(chef.response_format.type, "json_object");
  assert.match(chef.messages[0].content, /Use ONLY ingredients from the user's list/);
  assert.match(chef.messages[0].content, /in Ukrainian/);
  const request = JSON.parse(chef.messages[1].content);
  assert.deepEqual(request.ingredients, ["Яйця", "Шпинат"]);
  assert.equal(request.maxCaloriesPerServing, 300);
});

test("an AI recipe that sneaks in another product is sent back once to be rewritten", async () => {
  const withCheese = {
    ...chefRecipe,
    ingredients: [...chefRecipe.ingredients, { from: "Сир", name: "Сир", amount: 30, unit: "g" }],
  };
  const app = runtime({ pantry: [], chef: [withCheese, chefRecipe] });
  const result = await app.create({ ingredients: ["Яйця", "Шпинат"] });
  const chefCalls = app.calls.filter((call) => call.kind === "chef");
  assert.equal(chefCalls.length, 2);
  assert.match(chefCalls[1].body.messages.at(-1).content, /not in my list: Сир/);
  assert.ok(!result.body.recipe.extendedIngredients.some((item) => item.name === "Сир"));
});

test("when the AI insists on another product it is dropped rather than kept", async () => {
  const withCheese = {
    ...chefRecipe,
    ingredients: [...chefRecipe.ingredients, { from: "Сир", name: "Сир", amount: 30, unit: "g" }],
  };
  const app = runtime({ pantry: [], chef: [withCheese, withCheese] });
  const result = await app.create({ ingredients: ["Яйця", "Шпинат"] });
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.recipe.extendedIngredients.map((item) => item.name), ["Яйця", "Шпинат", "Сіль"]);
});

test("products the AI names in another form stay in the recipe instead of leaving only salt and oil", async () => {
  const salad = {
    ...chefRecipe,
    title: "Овочевий салат",
    ingredients: [
      { from: "огірок", name: "Огірок", amount: 150, unit: "g" },
      { from: "Tomatoes", name: "Помідор", amount: 150, unit: "g" },
      { from: "капусти", name: "Капуста", amount: 100, unit: "g" },
      { from: "oil", name: "Олія", amount: 1, unit: "tsp" },
      { from: "salt", name: "Сіль", amount: 1, unit: "g" },
    ],
  };
  const app = runtime({ pantry: [], chef: [salad] });
  const result = await app.create({ ingredients: ["огірки", "помідори", "капуста"] });
  assert.equal(result.status, 200);
  assert.deepEqual(
    result.body.recipe.extendedIngredients.map((item) => item.name),
    ["Огірок", "Помідор", "Капуста", "Олія", "Сіль"]
  );
  assert.equal(app.calls.filter((call) => call.kind === "chef").length, 1, "Nothing to rewrite");
});

test("a recipe of only water, salt, pepper and oil is never returned", async () => {
  const seasoning = {
    ...chefRecipe,
    ingredients: [
      { from: "Сир", name: "Сир", amount: 30, unit: "g" },
      { from: "oil", name: "Олія", amount: 1, unit: "tsp" },
      { from: "salt", name: "Сіль", amount: 1, unit: "g" },
    ],
  };
  const app = runtime({ pantry: [], chef: [seasoning, seasoning] });
  const result = await app.create({ ingredients: ["огірки", "помідори"] });
  assert.equal(result.status, 502);
  assert.equal(result.body.error, "recipe_unavailable");
});

test("the same request is served from the cache without calling anyone again", async () => {
  const app = runtime({ pantry: [{ id: 11, missedIngredientCount: 0 }], details: { 11: information(11) } });
  const first = await app.create({ ingredients: ["Шпинат", "Яйця"] });
  assert.equal(first.body.cached, false);
  const before = app.calls.length;
  const second = await app.create({ ingredients: ["яйця", "шпинат"] });
  assert.equal(second.body.cached, true);
  assert.equal(second.body.recipe.id, 11);
  assert.equal(app.calls.length, before);
});

test("a request without ingredients is rejected", async () => {
  const app = runtime();
  const result = await app.create({ ingredients: ["  "] });
  assert.equal(result.status, 400);
  assert.equal(app.calls.length, 0);
});

test("a created recipe is kept in R2 and still served once the edge cache has forgotten it", async () => {
  const app = runtime({ pantry: [] });
  const first = await app.create({ ingredients: ["Яйця", "Шпинат"], type: "breakfast" });
  assert.equal(first.body.cached, false);
  const keys = [...app.bucket.keys()].filter((key) => key.includes("recipe-create/"));
  assert.equal(keys.length, 1, "the recipe is written to durable storage");
  assert.equal(JSON.parse(app.bucket.get(keys[0])).recipe.title, "Омлет зі шпинатом");

  app.edge.clear();
  const before = app.calls.length;
  const again = await app.create({ ingredients: ["шпинат", "яйця"], type: "breakfast" });
  assert.equal(again.body.cached, true);
  assert.equal(again.body.recipe.title, "Омлет зі шпинатом");
  assert.equal(app.calls.length, before, "no catalog or AI call once the recipe is stored");
});
