import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("./worker.js", import.meta.url), "utf8")
  .replace("export default {", "const worker = {")
  .replaceAll("export class ", "class ");

// Mirrors wrangler.toml, where vision runs on the flagship model through the Responses API.
const env = {
  OPENAI_API_KEY: "test-ai",
  SPOONACULAR_API_KEY: "test-catalog",
  OPENAI_VISION_MODEL: "gpt-6-astra",
};

const translations = {
  "smoked salmon": "Копчений лосось",
  "plain yogurt": "Йогурт",
  "apple juice": "Яблучний сік",
};

function runtime({ ingredients, name = "Вміст холодильника", failFirstCall = false } = {}) {
  const requests = [];
  const cache = new Map();
  let call = 0;
  const context = vm.createContext({
    URL, URLSearchParams, Request, Response, Headers, TextEncoder, TextDecoder, AbortSignal,
    setTimeout, clearTimeout, console, crypto,
    caches: { default: {
      async match(request) { return cache.get(request.url)?.clone(); },
      async put(request, response) { cache.set(request.url, response.clone()); },
    } },
    fetch: async (rawURL, init) => {
      const url = new URL(rawURL);
      const body = JSON.parse(init.body);
      requests.push({ url: url.pathname, body });
      if (url.pathname === "/v1/chat/completions") {
        // The display translator runs on chat/completions with a JSON response format.
        const texts = JSON.parse(body.messages[1].content);
        return Response.json({
          choices: [{ message: { content: JSON.stringify({
            translations: texts.map((text) => translations[text.toLowerCase()] || text),
          }) } }],
        });
      }
      assert.equal(url.pathname, "/v1/responses");
      call += 1;
      if (failFirstCall && call === 1) {
        return Response.json({
          model: body.model,
          output: [{ type: "message", content: [{ type: "output_text", text: "У холодильнику є продукти." }] }],
        });
      }
      return Response.json({
        model: body.model,
        output: [{
          type: "function_call",
          call_id: "call_1",
          name: "propose_food_log",
          arguments: JSON.stringify({
            name,
            catalogQuery: name,
            mealType: "snacks",
            calories: 0, protein: 0, carbs: 0, fats: 0,
            confidence: 0.8,
            source: "photo",
            ingredients,
          }),
        }],
      });
    },
  });
  vm.runInContext(source + "\nglobalThis.worker = worker;", context);
  return {
    requests,
    visionRequests: () => requests.filter((item) => item.url === "/v1/responses"),
    async analyze(overrides = {}) {
      const response = await context.worker.fetch(new Request("https://assistant.test/v1/food/analyze-photo", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          imageBase64: "aGVsbG8=",
          inventoryMode: true,
          userContext: { locale: "uk_UA" },
          ...overrides,
        }),
      }), env, { waitUntil() {} });
      return { status: response.status, body: await response.json() };
    },
  };
}

test("the fridge prompt forbids duplicates, other languages, and invented amounts", async () => {
  const app = runtime({ ingredients: [{ name: "Яйця" }] });
  await app.analyze();
  const prompt = app.visionRequests()[0].body.input.at(-1).content
    .map((part) => part.text || "")
    .join(" ");
  assert.match(prompt, /One entry per real product/);
  assert.match(prompt, /MUST be written in Ukrainian/);
  assert.match(prompt, /Never express uncertainty/);
  assert.match(prompt, /Never invent a round number/);
  assert.match(prompt, /Skip everything that is not food/);
});

test("a fridge photo is analysed with more reasoning than a plated meal", async () => {
  const app = runtime({ ingredients: [{ name: "Яйця" }] });
  await app.analyze();
  assert.equal(app.visionRequests()[0].body.reasoning.effort, "medium");

  const plate = runtime({ ingredients: [{ name: "Яйця" }] });
  await plate.analyze({ inventoryMode: false });
  assert.equal(plate.visionRequests()[0].body.reasoning.effort, "low");
});

test("the retry keeps the inventory rules instead of asking for nutrition", async () => {
  const app = runtime({ ingredients: [{ name: "Яйця" }], failFirstCall: true });
  const result = await app.analyze();
  assert.equal(result.status, 200);
  const retry = app.visionRequests()[1].body.input.at(-1).content.map((part) => part.text || "").join(" ");
  assert.match(retry, /one entry per product/);
  assert.doesNotMatch(retry, /calories, protein, carbs, fats/);
});

test("duplicates of the same product collapse into one item", async () => {
  const app = runtime({ ingredients: [
    { name: "Лосось" },
    { name: "лосось?" },
    { name: "Копчений лосось", quantity: "200 г" },
    { name: "Яйця", quantity: "6 шт" },
  ] });
  const result = await app.analyze();
  assert.deepEqual(result.body.analysis.ingredients.map((item) => item.name), ["Лосось", "Яйця"]);
  assert.equal(result.body.analysis.ingredients[0].quantity, "200 г");
});

test("different products that share a word stay separate", async () => {
  const app = runtime({ ingredients: [{ name: "Молоко" }, { name: "Кокосове молоко" }] });
  const result = await app.analyze();
  assert.deepEqual(result.body.analysis.ingredients.map((item) => item.name), ["Молоко", "Кокосове молоко"]);
});

test("hedged and non-food entries are dropped", async () => {
  const app = runtime({ ingredients: [
    { name: "Можливо сир" },
    { name: "Лосось / тунець" },
    { name: "Полиця" },
    { name: "Йогурт (можливо)" },
    { name: "Незрозумілий контейнер із чимось схожим на залишки вечері" },
  ] });
  const result = await app.analyze();
  assert.deepEqual(
    result.body.analysis.ingredients.map((item) => item.name),
    ["Сир", "Лосось", "Йогурт"]
  );
});

test("names left in English are translated into the user's language", async () => {
  const app = runtime({ ingredients: [
    { name: "smoked salmon" },
    { name: "plain yogurt" },
    { name: "Яйця" },
  ] });
  const result = await app.analyze();
  assert.deepEqual(
    result.body.analysis.ingredients.map((item) => item.name),
    ["Копчений лосось", "Йогурт", "Яйця"]
  );
});

test("one identical weight on every product is treated as a default, not a measurement", async () => {
  const app = runtime({ ingredients: [
    { name: "Яйця", grams: 100 },
    { name: "Молоко", grams: 100 },
    { name: "Сир", grams: 100 },
  ] });
  const result = await app.analyze();
  assert.deepEqual(result.body.analysis.ingredients.map((item) => item.grams), [null, null, null]);

  const measured = runtime({ ingredients: [
    { name: "Яйця", grams: 100 },
    { name: "Молоко", grams: 900 },
    { name: "Сир", grams: 250 },
  ] });
  const kept = await measured.analyze();
  assert.deepEqual(kept.body.analysis.ingredients.map((item) => item.grams), [100, 900, 250]);
});

test("a visible amount reaches the client as a quantity label", async () => {
  const app = runtime({ ingredients: [{ name: "Яйця", quantity: "6 шт" }, { name: "Молоко", quantity: "1 л" }] });
  const result = await app.analyze();
  assert.deepEqual(
    result.body.analysis.ingredients.map((item) => item.quantity),
    ["6 шт", "1 л"]
  );
});
