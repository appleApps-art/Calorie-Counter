import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("./worker.js", import.meta.url), "utf8")
  .replace("export default {", "const worker = {")
  .replaceAll("export class ", "class ");

const translations = { "Яйця": "eggs", "Пшениця": "wheat", "курка": "chicken", "Шпинат": "spinach" };

function runtime() {
  const upstream = [];
  const edge = new Map();
  const env = { OPENAI_API_KEY: "test-ai", SPOONACULAR_API_KEY: "test-catalog" };
  const context = vm.createContext({
    URL, URLSearchParams, Request, Response, Headers, TextEncoder, TextDecoder, AbortSignal,
    setTimeout, clearTimeout, console,
    caches: { default: {
      async match(request) { return edge.get(request.url)?.clone(); },
      async put(request, response) { edge.set(request.url, response.clone()); },
    } },
    fetch: async (rawURL, init) => {
      const url = new URL(rawURL);
      if (url.origin === "https://api.openai.com") {
        const query = JSON.parse(init.body).messages[1].content;
        return Response.json({ choices: [{ message: { content: translations[query] || query } }] });
      }
      assert.equal(url.origin, "https://api.spoonacular.com");
      upstream.push(url);
      if (url.pathname === "/recipes/findByIngredients") {
        return Response.json([
          { id: 5, title: "Spinach Salad", image: "https://img.spoonacular.com/recipes/5-312x231.jpg", missedIngredientCount: 0, usedIngredientCount: 2 },
          { id: 6, title: "Eggs Benedict", image: "https://img.spoonacular.com/recipes/6-312x231.jpg", missedIngredientCount: 1, usedIngredientCount: 2 },
        ]);
      }
      if (url.pathname === "/recipes/complexSearch") {
        const offset = Number(url.searchParams.get("offset") || 0);
        const total = 23;
        const count = Math.max(0, Math.min(Number(url.searchParams.get("number")), total - offset));
        return Response.json({
          totalResults: total,
          offset,
          results: Array.from({ length: count }, (_, index) => ({
            id: offset + index + 1,
            title: `Veggie Tacos ${offset + index + 1}`,
            image: `https://img.spoonacular.com/recipes/${offset + index + 1}-312x231.jpg`,
          })),
        });
      }
      return Response.json({ products: [], results: [] });
    },
  });
  vm.runInContext(source + `
    globalThis.worker = worker;
    localizeSpoonacularPayload = async (_env, _path, data) => data;
    localizeSearchItemTitles = async (_env, _ctx, items) => items;
  `, context);
  return {
    upstream,
    worker: context.worker,
    async search(body) {
      const response = await context.worker.fetch(new Request("https://assistant.test/v1/food/search", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ locale: "uk_UA", scope: "recipes", ...body }),
      }), env, {});
      return { status: response.status, body: await response.json() };
    },
  };
}

test("recipe filters reach Spoonacular as structured parameters", async () => {
  const app = runtime();
  const result = await app.search({
    query: "курка",
    filters: {
      type: "breakfast,main course",
      cuisine: "italian",
      diet: "vegetarian",
      maxReadyTime: "30",
      maxCalories: "400",
      excludeIngredients: "Яйця, Пшениця",
    },
  });
  assert.equal(result.status, 200);
  const search = app.upstream.find(url => url.pathname === "/recipes/complexSearch");
  assert.equal(search.searchParams.get("query"), "chicken");
  assert.equal(search.searchParams.get("type"), "breakfast,main course");
  assert.equal(search.searchParams.get("cuisine"), "italian");
  assert.equal(search.searchParams.get("diet"), "vegetarian");
  assert.equal(search.searchParams.get("maxReadyTime"), "30");
  assert.equal(search.searchParams.get("maxCalories"), "400");
  assert.equal(search.searchParams.get("excludeIngredients"), "eggs,wheat");
  assert.equal(search.searchParams.get("instructionsRequired"), "true");
  assert.equal(result.body.items[0].externalId, "1");
});

test("filters alone search recipes without a text query", async () => {
  const app = runtime();
  const result = await app.search({ query: "", filters: { diet: "vegan" } });
  assert.equal(result.status, 200);
  const search = app.upstream.find(url => url.pathname === "/recipes/complexSearch");
  assert.equal(search.searchParams.get("diet"), "vegan");
  assert.equal(search.searchParams.get("query"), null);
  assert.equal(result.body.items.length, 10);
});

test("a request without query and filters is rejected", async () => {
  const app = runtime();
  const result = await app.search({ query: "", filters: { diet: "  " } });
  assert.equal(result.status, 400);
  assert.equal(app.upstream.length, 0);
});

test("recipe search pages through Spoonacular results", async () => {
  const app = runtime();
  const first = await app.search({ query: "", filters: { diet: "vegan" } });
  assert.equal(first.body.items.length, 10);
  assert.equal(first.body.nextOffset, 10);
  assert.equal(first.body.hasMore, true);
  assert.equal(app.upstream.at(-1).searchParams.get("offset"), null);

  const second = await app.search({ query: "", filters: { diet: "vegan" }, offset: 10 });
  assert.equal(app.upstream.at(-1).searchParams.get("offset"), "10");
  assert.deepEqual(second.body.items.map(item => item.externalId).slice(0, 2), ["11", "12"]);
  assert.equal(second.body.nextOffset, 20);
  assert.equal(second.body.hasMore, true);

  const last = await app.search({ query: "", filters: { diet: "vegan" }, offset: 20 });
  assert.equal(last.body.items.length, 3);
  assert.equal(last.body.nextOffset, 23);
  assert.equal(last.body.hasMore, false);
});

test("pantry ingredients are translated one by one for includeIngredients", async () => {
  const app = runtime();
  const env = { OPENAI_API_KEY: "test-ai", SPOONACULAR_API_KEY: "test-catalog" };
  const url = "https://assistant.test/v1/spoonacular/recipes/search?includeIngredients=%D0%AF%D0%B9%D1%86%D1%8F,%20%D0%A8%D0%BF%D0%B8%D0%BD%D0%B0%D1%82&type=breakfast&maxCalories=500&number=5&locale=uk_UA";
  const response = await app.worker.fetch(new Request(url), env, {});
  assert.equal(response.status, 200);
  const search = app.upstream.find(item => item.pathname === "/recipes/complexSearch");
  assert.equal(search.searchParams.get("includeIngredients"), "eggs,spinach");
  assert.equal(search.searchParams.get("type"), "breakfast");
  assert.equal(search.searchParams.get("maxCalories"), "500");
});

test("a meal plan search keeps its ranking and its calorie window", async () => {
  const app = runtime();
  const env = { OPENAI_API_KEY: "test-ai", SPOONACULAR_API_KEY: "test-catalog" };
  const url = "https://assistant.test/v1/spoonacular/recipes/search?type=main%20course&minCalories=400&maxCalories=900&sort=popularity&number=20&locale=uk_UA";
  const response = await app.worker.fetch(new Request(url), env, {});
  assert.equal(response.status, 200);
  const search = app.upstream.find(item => item.pathname === "/recipes/complexSearch");
  assert.equal(search.searchParams.get("sort"), "popularity");
  assert.equal(search.searchParams.get("type"), "main course");
  assert.equal(search.searchParams.get("minCalories"), "400");
  assert.equal(search.searchParams.get("maxCalories"), "900");
  assert.equal(search.searchParams.get("instructionsRequired"), "true");
});

test("pantry search asks Spoonacular for recipes that minimise missing ingredients", async () => {
  const app = runtime();
  const env = { OPENAI_API_KEY: "test-ai", SPOONACULAR_API_KEY: "test-catalog" };
  const response = await app.worker.fetch(new Request(
    "https://assistant.test/v1/spoonacular/pantry/search?ingredients=%D0%A8%D0%BF%D0%B8%D0%BD%D0%B0%D1%82,%20%D0%AF%D0%B9%D1%86%D1%8F&number=30&locale=uk_UA"
  ), env, {});
  assert.equal(response.status, 200);
  const body = await response.json();
  const search = app.upstream.find(item => item.pathname === "/recipes/findByIngredients");
  assert.equal(search.searchParams.get("ingredients"), "spinach,eggs");
  assert.equal(search.searchParams.get("ranking"), "2");
  assert.equal(search.searchParams.get("ignorePantry"), "true");
  assert.deepEqual(body.results.map(item => [item.id, item.missedIngredientCount]), [[5, 0], [6, 1]]);

  const empty = await app.worker.fetch(new Request("https://assistant.test/v1/spoonacular/pantry/search?ingredients="), env, {});
  assert.equal(empty.status, 400);
});
