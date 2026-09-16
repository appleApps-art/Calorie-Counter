import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { webcrypto } from "node:crypto";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("./worker.js", import.meta.url), "utf8")
  .replace("export default {", "const worker = {")
  .replaceAll("export class ", "class ");

function runtime() {
  const cache = new Map();
  const context = vm.createContext({
    URL, Request, Response, Headers, TextEncoder, TextDecoder, AbortSignal,
    crypto: webcrypto, setTimeout, clearTimeout,
    fetch: async () => { throw new Error("Unexpected external request"); },
    caches: { default: {
      async match(request) { return cache.get(request.url)?.clone(); },
      async put(request, response) { cache.set(request.url, response.clone()); },
    } },
  });
  vm.runInContext(source + `
    globalThis.api = { worker, RecipeImageStore, enrichAssistantImages, prepareAssistantFoodImage,
      findAndDownloadAssistantFoodImage, isDisplayableRecipeImage, resolveAssistantFoodImage,
      isPreparedBroth, assistantFoodImageID, rankedFoodImageURLs, lookupFoodImageURLs, storedFoodImageURLs };
    lookupFoodImageURL = async () => '';
  `, context);
  return context;
}

function namespace(context) {
  const stores = new Map();
  const env = {
    RECIPE_IMAGES: {
      idFromName: (id) => id,
      get(id) {
        if (!stores.has(id)) {
          const values = new Map();
          const storage = {
            alarmAt: null,
            async get(key) {
              if (Array.isArray(key)) return new Map(key.map((k) => [k, structuredClone(values.get(k))]));
              return structuredClone(values.get(key));
            },
            async put(key, value) {
              for (const [k, v] of typeof key === "string" ? [[key, value]] : Object.entries(key)) {
                assert.ok(!v?.byteLength || v.byteLength < 128 * 1024, "Durable Object value exceeds storage limit");
                values.set(k, structuredClone(v));
              }
            },
            async delete(key) { values.delete(key); },
            async setAlarm(time) { this.alarmAt = time; },
            async transaction(callback) { return callback(this); },
          };
          const object = new context.api.RecipeImageStore({ storage }, env);
          stores.set(id, { object, storage, fetch: (url, init) => object.fetch(new Request(url, init)) });
        }
        return stores.get(id);
      },
    },
  };
  return { env, stores };
}

const origin = "https://assistant.example.test";
const food = (name = "Плов") => ({ name: "propose_food_log", arguments: { name, source: "text" } });

test("chat returns a persistent image URL before image search completes", async () => {
  const context = runtime();
  const { env, stores } = namespace(context);
  vm.runInContext("findFallbackDishImageURL = async () => { throw new Error('Inline search must not run'); };", context);
  const calls = [food()];
  const result = await context.api.enrichAssistantImages(env, null, origin, calls, { locale: "uk" });
  const url = new URL(result[0].arguments.imageURL);
  assert.equal(url.origin, origin);
  assert.match(url.pathname, /^\/v1\/generated-images\/[0-9a-f-]{36}$/);
  assert.equal(calls[0].arguments.imageURL, undefined);
  const store = [...stores.values()][0];
  assert.equal((await store.storage.get("job")).name, "Плов");
  assert.ok(store.storage.alarmAt);
  assert.equal((await store.fetch("https://recipe-images/store")).status, 202);
});

function bucket() {
  const values = new Map();
  return {
    values,
    async get(key) {
      if (!values.has(key)) return null;
      const value = values.get(key);
      return {
        async json() { return JSON.parse(value); },
        async arrayBuffer() { return new Uint8Array(value).buffer; },
      };
    },
    async put(key, value) { values.set(key, typeof value === "string" ? value : new Uint8Array(value)); },
  };
}

test("R2 images are returned without requiring Durable Objects or any search", async () => {
  const context = runtime();
  const storage = bucket();
  const id = await context.api.assistantFoodImageID("Плов");
  await storage.put(`food-images/v1/${id}`, [255, 216, 255]);
  const response = await context.api.worker.fetch(new Request(`${origin}/v1/food/image?name=${encodeURIComponent("Плов")}`),
    { BITY_BUCKET: storage }, {});
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("x-image-source"), "storage");
  assert.deepEqual([...new Uint8Array(await response.arrayBuffer())], [255, 216, 255]);
});

test("missing Durable Object binding resolves through Spoonacular and persists to R2", async () => {
  const context = runtime();
  const storage = bucket();
  context.calls = [];
  vm.runInContext(`
    lookupFoodImageURLs = async (env, ctx, query) => { calls.push(query); return ['https://example.com/pilaf.jpg']; };
    downloadRecipeImageBytes = async () => ({ bytes: new Uint8Array([255,216,255]), type: 'image/jpeg' });
    searchTavilyFoodImageURLs = async () => { throw new Error('Spoonacular already supplied an image'); };
  `, context);
  const env = { BITY_BUCKET: storage };
  const calls = await context.api.enrichAssistantImages(env, {}, origin, [food()], {});
  assert.match(calls[0].arguments.imageURL, /\/v1\/food\/image\?name=/);
  const response = await context.api.worker.fetch(new Request(calls[0].arguments.imageURL), env, {});
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("x-image-source"), "spoonacular");
  assert.deepEqual(context.calls, ["pilaf"]);
  assert.equal(storage.values.size, 1);
  const repeated = await context.api.worker.fetch(new Request(calls[0].arguments.imageURL), env, {});
  assert.equal(repeated.status, 200);
  assert.equal(context.calls.length, 1);
});

test("concurrent rows share one image resolution", async () => {
  const context = runtime();
  context.lookups = 0;
  vm.runInContext(`findAndDownloadAssistantFoodImage = async () => {
    lookups += 1;
    await new Promise(resolve => setTimeout(resolve, 5));
    return { bytes: new Uint8Array([255,216,255]), type: 'image/jpeg' };
  };`, context);
  const results = await Promise.all(Array.from({ length: 10 }, () => context.api.resolveAssistantFoodImage({}, "Плов")));
  assert.equal(context.lookups, 1);
  assert.ok(results.every((image) => image.type === "image/jpeg"));
});

test("stored recipes precede Spoonacular and broken stored photos fall through", async () => {
  const context = runtime();
  context.order = [];
  vm.runInContext(`
    storedFoodImageURLs = async () => { order.push('storage'); return ['https://example.com/broken.jpg']; };
    lookupFoodImageURLs = async () => { order.push('spoonacular'); return ['https://example.com/good.jpg']; };
    downloadRecipeImageBytes = async url => url.includes('broken') ? null : ({bytes: new Uint8Array([255,216,255]), type: 'image/jpeg'});
  `, context);
  const image = await context.api.findAndDownloadAssistantFoodImage({}, "Плов");
  assert.equal(image.source, "spoonacular");
  assert.deepEqual(context.order, ["storage", "spoonacular"]);
});

test("cached recipe metadata is reused and irrelevant recipes are rejected", async () => {
  const context = runtime();
  const storage = bucket();
  await storage.put("ai-recipe-cache/v6/q:v5:pilaf", JSON.stringify({ v: 7, recipes: [
    { title: "Rice Pilaf", imageURL: "https://example.com/pilaf.jpg" },
    { title: "Chocolate Cake", imageURL: "https://example.com/cake.jpg" },
  ] }));
  const urls = await context.api.storedFoodImageURLs({ BITY_BUCKET: storage }, "Плов", "pilaf");
  assert.deepEqual([...urls], ["https://example.com/pilaf.jpg"]);
  const vegan = context.api.rankedFoodImageURLs("vegan pilaf", [
    { title: "Pilaf", image: "https://example.com/generic.jpg" },
    { title: "Chicken Pilaf", image: "https://example.com/chicken.jpg" },
    { title: "Vegan Pilaf", image: "https://example.com/vegan.jpg" },
  ]);
  assert.deepEqual([...vegan], ["https://example.com/vegan.jpg"]);
});

test("exhausted lookup returns a terminal failure and a short cooldown prevents repeated searches", async () => {
  const context = runtime();
  context.lookups = 0;
  vm.runInContext("findAndDownloadAssistantFoodImage = async () => { lookups += 1; return null; };", context);
  const request = new Request(`${origin}/v1/food/image?name=Unknown`);
  for (let index = 0; index < 3; index++) {
    const response = await context.api.worker.fetch(request, {}, {});
    assert.equal(response.status, 404);
    assert.equal(response.headers.get("x-image-status"), "failed");
  }
  assert.equal(context.lookups, 1);
});

test("a failed R2 write does not discard a successfully resolved image", async () => {
  const context = runtime();
  vm.runInContext("findAndDownloadAssistantFoodImage = async () => ({ bytes: new Uint8Array([255,216,255]), type: 'image/jpeg' });", context);
  const image = await context.api.resolveAssistantFoodImage({ BITY_BUCKET: {
    async get() { throw new Error('storage unavailable'); },
    async put() { throw new Error('storage unavailable'); },
  } }, "Плов");
  assert.equal(image.type, "image/jpeg");
});

test("old generated URLs fail immediately without their binding so clients can recover by name", async () => {
  const context = runtime();
  const response = await context.api.worker.fetch(new Request(`${origin}/v1/generated-images/12345678-1234-4234-a234-123456789012`), {}, {});
  assert.equal(response.status, 404);
  assert.equal(response.headers.get("x-image-status"), "failed");
});

test("stalled Durable Object jobs eventually report failure instead of permanent pending", async () => {
  const context = runtime();
  const { env, stores } = namespace(context);
  await context.api.prepareAssistantFoodImage(env, origin, "Плов");
  const store = [...stores.values()][0];
  const job = await store.storage.get("job");
  job.createdAt = Date.now() - 120001;
  await store.storage.put("job", job);
  const response = await store.fetch("https://recipe-images/store");
  assert.equal(response.status, 404);
  assert.equal(response.headers.get("x-image-status"), "failed");
});

test("all editable food proposal variants receive photo jobs; uploaded and existing photos are preserved", async () => {
  const context = runtime();
  const { env } = namespace(context);
  const existingURL = "https://example.com/pilaf.jpg";
  const calls = [
    food(),
    { name: "propose_food_replace", arguments: { newItem: { name: "Борщ" } } },
    { name: "propose_food_swap", arguments: { original: { name: "Рис" }, alternative: { name: "Гречка" } } },
    { name: "propose_meal_suggestions", arguments: { options: [{ title: "Суп" }] } },
    { name: "propose_food_log", arguments: { name: "Photo", source: "photo" } },
    { name: "propose_food_log", arguments: { name: "Pilaf", imageURL: existingURL } },
  ];
  const result = await context.api.enrichAssistantImages(env, null, origin, calls, {});
  for (const item of [result[0].arguments, result[1].arguments.newItem,
    result[2].arguments.original, result[2].arguments.alternative, result[3].arguments.options[0]]) {
    assert.ok(context.api.isDisplayableRecipeImage(item.imageURL));
  }
  assert.equal(result[4].arguments.imageURL, undefined);
  assert.equal(result[5].arguments.imageURL, existingURL);
});

test("an empty first search retries and publishes bytes at the original URL", async () => {
  const context = runtime();
  const { env, stores } = namespace(context);
  const imageURL = await context.api.prepareAssistantFoodImage(env, origin, "Плов");
  const store = [...stores.values()][0];
  vm.runInContext("findAndDownloadAssistantFoodImage = async () => null;", context);
  await store.object.alarm();
  assert.equal((await store.storage.get("job")).attempts, 1);
  assert.ok(store.storage.alarmAt > Date.now());
  const pending = await store.fetch("https://recipe-images/store");
  assert.equal(pending.status, 202);
  assert.equal(pending.headers.get("cache-control"), "no-store");
  vm.runInContext("findAndDownloadAssistantFoodImage = async () => ({bytes: new Uint8Array([255,216,255]), type: 'image/jpeg'});", context);
  await store.object.alarm();
  assert.equal(await context.api.prepareAssistantFoodImage(env, origin, "  плов  "), imageURL);
  const image = await store.fetch("https://recipe-images/store");
  assert.equal(image.status, 200);
  assert.equal(image.headers.get("content-type"), "image/jpeg");
  assert.deepEqual([...new Uint8Array(await image.arrayBuffer())], [255, 216, 255]);
  assert.equal(await store.storage.get("job"), undefined);
});

test("exhausted jobs stop polling, deduplicate requests, and can recover after cooldown", async () => {
  const context = runtime();
  const { env, stores } = namespace(context);
  vm.runInContext("findAndDownloadAssistantFoodImage = async () => null;", context);
  const url = await context.api.prepareAssistantFoodImage(env, origin, "Плов");
  const store = [...stores.values()][0];
  for (let i = 0; i < 3; i++) await store.object.alarm();
  const failed = await store.fetch("https://recipe-images/store");
  assert.equal(failed.status, 404);
  assert.equal(failed.headers.get("x-image-status"), "failed");
  await context.api.prepareAssistantFoodImage(env, origin, "Плов");
  assert.equal((await store.storage.get("job")).attempts, 3);
  const job = await store.storage.get("job");
  job.failedAt = Date.now() - 300001;
  await store.storage.put("job", job);
  assert.equal(await context.api.prepareAssistantFoodImage(env, origin, "Плов"), url);
  assert.equal((await store.storage.get("job")).attempts, 0);
  assert.equal(stores.size, 1);
});

test("legacy entries resolve by name and enforce authorization", async () => {
  const context = runtime();
  const { env, stores } = namespace(context);
  const url = new URL("/v1/food/image", origin);
  url.searchParams.set("name", "Плов");
  const pending = await context.api.worker.fetch(new Request(url), env, {});
  assert.equal(pending.status, 202);
  assert.equal(stores.size, 1);
  const invalid = await context.api.worker.fetch(new Request(`${origin}/v1/food/image`), env, {});
  assert.equal(invalid.status, 400);
  const unauthorized = await context.api.worker.fetch(new Request(url), { ...env, APP_API_KEY: "test" }, {});
  assert.equal(unauthorized.status, 401);
});

test("a broken web image does not prevent trying another source", async () => {
  const context = runtime();
  vm.runInContext(`
    searchTavilyFoodImageURLs = async () => ['https://example.com/broken.jpg'];
    searchWebFoodImageURLs = async () => ['https://example.com/good.jpg'];
    downloadRecipeImageBytes = async url => {
      if (url.includes('broken')) throw new Error('404');
      return { bytes: new Uint8Array([255,216,255]), type: 'image/jpeg' };
    };
  `, context);
  const image = await context.api.findAndDownloadAssistantFoodImage({}, "Плов");
  assert.equal(image.type, "image/jpeg");
});

test("photos larger than the KV value limit are stored and reassembled without a migration", async () => {
  const context = runtime();
  const { env, stores } = namespace(context);
  await context.api.prepareAssistantFoodImage(env, origin, "Плов");
  const store = [...stores.values()][0];
  const bytes = new Uint8Array(250000).fill(127);
  await store.fetch("https://recipe-images/store", {
    method: "PUT", headers: { "content-type": "image/jpeg" }, body: bytes,
  });
  assert.equal(await store.storage.get("imageChunkCount"), 4);
  const response = await store.fetch("https://recipe-images/store");
  assert.equal(response.status, 200);
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), bytes);
});


test("prepared broth is distinct from explicitly requested concentrate", () => {
  const { api } = runtime();
  for (const name of ["Курячий бульйон", "chicken broth", "beef stock", "куриный бульон"]) assert.equal(api.isPreparedBroth(name), true, name);
  for (const name of ["бульйонний кубик", "chicken stock cubes", "broth powder", "сухий бульйон", "stockfish"]) assert.equal(api.isPreparedBroth(name), false, name);
});

test("broth recipe search never falls back to an ingredient cube", async () => {
  const context = runtime();
  context.paths = [];
  vm.runInContext(`englishFoodSearchQuery = async () => 'chicken broth';
    firstSpoonacularImage = async (env, ctx, input) => {
      paths.push(input.path);
      return input.path.includes('/ingredients/') ? ['https://example.com/stock-cube.jpg'] : [];
    };`, context);
  assert.equal((await context.api.lookupFoodImageURLs({ SPOONACULAR_API_KEY: 'test' }, null, 'Курячий бульйон', 'uk')).length, 0);
  assert.deepEqual(context.paths, ['/v1/spoonacular/recipes/search']);
});

test("stored ingredient photos cannot masquerade as prepared broth", () => {
  const { api } = runtime();
  const urls = api.rankedFoodImageURLs('chicken broth', [
    { name: 'chicken broth', kind: 'ingredient', image: 'https://example.com/stock.jpg' },
    { name: 'chicken broth', image: 'https://img.spoonacular.com/ingredients_100x100/stock-cube.jpg' },
    { name: 'chicken broth', kind: 'recipe', image: 'https://example.com/bowl.jpg' },
  ]);
  assert.deepEqual(Array.from(urls), ['https://example.com/bowl.jpg']);
});

test("broth proposals become recipes and replace legacy cube image URLs", async () => {
  const context = runtime();
  const result = await context.api.enrichAssistantImages({}, {}, origin, [{ name: 'propose_food_log', arguments: {
    name: 'Курячий бульйон', kind: 'product', imageURL: 'https://example.com/stock-cube.jpg', portionMilliliters: 250,
  } }], {});
  assert.equal(result[0].arguments.kind, 'recipe');
  assert.equal(new URL(result[0].arguments.imageURL).searchParams.get('v'), 'broth-2');
  const legacyHash = Buffer.from(await webcrypto.subtle.digest('SHA-256', new TextEncoder().encode('assistant-food-photo-v1:курячий бульйон'))).toString('hex');
  const id = await context.api.assistantFoodImageID('Курячий бульйон');
  assert.notEqual(id.slice(0, 8), legacyHash.slice(0, 8));
});
