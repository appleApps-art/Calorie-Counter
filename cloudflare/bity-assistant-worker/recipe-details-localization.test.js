import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source = readFileSync(new URL('./worker.js', import.meta.url), 'utf8')
  .replace('export default {', 'const worker = {').replaceAll('export class ', 'class ');
function runtime(mode) {
  const calls = [];
  const context = vm.createContext({ URL, Request, Response, Headers, TextEncoder, TextDecoder,
    AbortSignal, setTimeout, clearTimeout,
    title: async () => 'Курячі крильця',
    translate: async (_env, _language, values) => {
      calls.push(Object.keys(values));
      if (mode === 'failed') return {};
      return Object.fromEntries(Object.entries(values).filter(([key]) =>
        mode !== 'partial' || calls.length > 1 || key !== 's1'
      ).map(([key]) => [key, key.endsWith('u') ? 'ч. л.' : 'Переклад українською']));
    },
  });
  vm.runInContext(source + `
    cachedRecipeCardTitle = title;
    translateKeyedObject = translate;
    globalThis.api = {localizeSpoonacularPayload, recipeCookingCopyLooksLocalized, spoonacularCacheKey};
  `, context);
  return { api: context.api, calls };
}
const recipe = () => ({ id: 123, title: 'Wings', servings: 4,
  extendedIngredients: [{ name: 'brown sugar', original: '1 tsp brown sugar', amount: 1, unit: 'tsp' }],
  analyzedInstructions: [{ steps: [{ number: 1, step: 'Mix ingredients' }, { number: 2, step: 'Cook until ready' }] }],
  nutrition: { nutrients: [{ name: 'Calories', amount: 384 }] },
});
const path = '/v1/spoonacular/recipes/123/information';
test('recipe details translate every ingredient, unit and instruction without changing quantities', async () => {
  const app = runtime('complete'); const original = recipe();
  const result = await app.api.localizeSpoonacularPayload({ OPENAI_API_KEY: 'test' }, path, original, 'uk-UA', false);
  assert.equal(result.extendedIngredients[0].name, 'Переклад українською');
  assert.equal(result.extendedIngredients[0].unit, 'ч. л.');
  assert.equal(result.extendedIngredients[0].amount, 1);
  assert.equal(result.analyzedInstructions[0].steps[1].step, 'Переклад українською');
  assert.equal(result.nutrition.nutrients[0].amount, 384);
  assert.equal(original.extendedIngredients[0].name, 'brown sugar');
});
test('partial translation retries only missing fields', async () => {
  const app = runtime('partial');
  await app.api.localizeSpoonacularPayload({ OPENAI_API_KEY: 'test' }, path, recipe(), 'uk-UA', false);
  assert.equal(app.calls.length, 2);
  assert.deepEqual(app.calls[1], ['s1']);
});
test('failed or unconfigured translation never returns English details as a localized success', async () => {
  const app = runtime('failed');
  await assert.rejects(app.api.localizeSpoonacularPayload({ OPENAI_API_KEY: 'test' }, path, recipe(), 'uk-UA', false), /translation unavailable/);
  await assert.rejects(app.api.localizeSpoonacularPayload({}, path, recipe(), 'uk-UA', false), /translation unavailable/);
});
test('mostly translated recipe with one English step cannot pass cache validation', () => {
  const app = runtime('complete'); const data = recipe();
  data.extendedIngredients[0] = { name: 'Цукор', original: 'Цукор 1 ч. л.', unit: 'ч. л.' };
  data.analyzedInstructions[0].steps[0].step = 'Змішайте інгредієнти';
  assert.equal(app.api.recipeCookingCopyLooksLocalized(data, 'uk'), false);
  assert.equal(app.api.recipeCookingCopyLooksLocalized(data, 'en'), true);
});

function cacheRuntime() {
  const edge = new Map();
  const durable = new Map();
  let translations = 0;
  let upstreamCalls = 0;
  const context = vm.createContext({ URL, URLSearchParams, Request, Response, Headers, TextEncoder, TextDecoder,
    AbortSignal, setTimeout, clearTimeout,
    caches: { default: {
      match: async key => edge.get(key.url)?.clone(),
      put: async (key, value) => { edge.set(key.url, value.clone()); },
    } },
    upstream: async () => { upstreamCalls++; return Response.json(recipe()); },
    localize: async () => {
      translations++;
      const data = recipe();
      data.extendedIngredients = [{ name: 'Цукор', original: 'Цукор', unit: 'г', amount: 1 }];
      data.analyzedInstructions = [{ steps: [{ step: 'Змішайте та приготуйте' }] }];
      return data;
    },
  });
  vm.runInContext(source + `
    fetchSpoonacularLimited = upstream;
    localizeSpoonacularPayload = localize;
    globalThis.api = { handleSpoonacularProxy };
  `, context);
  return {
    edge, durable, counts: () => ({ translations, upstreamCalls }),
    request: locale => context.api.handleSpoonacularProxy(new URL('https://example.com/v1/spoonacular/recipes/123?locale=' + locale), {
      SPOONACULAR_API_KEY: 'test',
      RECIPE_CACHE: {
        get: async key => durable.has(key) ? JSON.parse(durable.get(key)) : null,
        put: async (key, value) => { durable.set(key, value); },
      },
    }),
  };
}
test('localized recipe survives a cold regional edge without translating or fetching again', async () => {
  const app = cacheRuntime();
  const first = await (await app.request('uk-UA')).json();
  app.edge.clear();
  const second = await (await app.request('uk-UA')).json();
  assert.deepEqual(second, first);
  assert.deepEqual(app.counts(), { translations: 1, upstreamCalls: 1 });
});
test('expired durable recipe must be refreshed', async () => {
  const app = cacheRuntime();
  await app.request('uk-UA');
  for (const [key, value] of app.durable) {
    const data = JSON.parse(value); data.expiresAt = 1; app.durable.set(key, JSON.stringify(data));
  }
  app.edge.clear();
  await app.request('uk-UA');
  assert.deepEqual(app.counts(), { translations: 2, upstreamCalls: 2 });
});
