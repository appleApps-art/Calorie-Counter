import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("./worker.js", import.meta.url), "utf8")
  .replace("export default {", "const worker = {")
  .replaceAll("export class ", "class ");

// The translator answers like the grocery-biased prompt did in production for dish queries,
// and like a dish-name prompt should for recipe queries.
function runtime() {
  const prompts = [];
  const bodies = [];
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
        const body = JSON.parse(init.body);
        bodies.push(body);
        const instructions = body.messages[0].content;
        prompts.push(instructions);
        const isRecipe = instructions.includes("recipe website");
        const content = isRecipe ? "ratatouille" : "canned ratatouille vegetable stew";
        return Response.json({ choices: [{ message: { content } }] });
      }
      assert.equal(url.origin, "https://api.spoonacular.com");
      upstream.push(url);
      if (url.pathname === "/recipes/complexSearch") {
        const results = url.searchParams.get("query") === "ratatouille"
          ? [{ id: 647687, title: "Ratatouille", image: "https://img.spoonacular.com/recipes/647687-312x231.jpg" }]
          : [];
        return Response.json({ results, offset: 0, number: 10, totalResults: results.length });
      }
      if (url.pathname === "/food/products/search") return Response.json({ products: [] });
      if (url.pathname === "/food/ingredients/search") return Response.json({ results: [] });
      throw new Error(`Unexpected upstream path: ${url.pathname}`);
    },
  });
  vm.runInContext(source + `
    globalThis.worker = worker;
    localizeSpoonacularPayload = async (_env, _path, data) => data;
    localizeSearchItemTitles = async (_env, _ctx, items) => items;
  `, context);
  return {
    prompts, bodies, upstream,
    async search(scope) {
      const response = await context.worker.fetch(new Request("https://assistant.test/v1/food/search", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ query: "Рататуй", locale: "uk_UA", scope }),
      }), env, {});
      assert.equal(response.status, 200);
      return response.json();
    },
  };
}

test("a Ukrainian dish query finds the recipe through a dish-name translation", async () => {
  const app = runtime();
  const result = await app.search("recipes");
  const recipeSearch = app.upstream.find(url => url.pathname === "/recipes/complexSearch");
  assert.equal(recipeSearch.searchParams.get("query"), "ratatouille");
  assert.deepEqual(result.items.map(item => item.externalId), ["647687"]);
  assert.equal(app.prompts.length, 1);
  assert.match(app.prompts[0], /recipe website/);
});

test("recipe and grocery translations of the same query never share a cache entry", async () => {
  const app = runtime();
  await app.search("foods");
  await app.search("recipes");
  const recipeSearch = app.upstream.find(url => url.pathname === "/recipes/complexSearch");
  const productSearch = app.upstream.find(url => url.pathname === "/food/products/search");
  assert.equal(productSearch.searchParams.get("query"), "canned ratatouille vegetable stew");
  assert.equal(recipeSearch.searchParams.get("query"), "ratatouille");
  assert.equal(app.prompts.length, 2, "Each kind must be translated with its own prompt");
  assert.ok(app.prompts.some(prompt => prompt.includes("Prefer a product or ingredient name")));

  await app.search("recipes");
  assert.equal(app.prompts.length, 2, "A cached recipe translation must be reused");
});

test("query translation uses GPT-5.6 Luna with a reasoning effort it accepts", async () => {
  const app = runtime();
  await app.search("recipes");
  assert.equal(app.bodies[0].model, "gpt-5.6-luna");
  assert.equal(app.bodies[0].reasoning_effort, "none");
  assert.equal(app.bodies[0].temperature, undefined);
});
