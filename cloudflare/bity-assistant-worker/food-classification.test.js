import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { webcrypto } from 'node:crypto';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(new URL('./worker.js', import.meta.url), 'utf8')
  .replace('export default {', 'const worker = {').replaceAll('export class ', 'class ');

function runtime(edge = new Map()) {
  const state = { calls: [], types: [], status: 200, override: null };
  const context = vm.createContext({
    URL, URLSearchParams, Request, Response, Headers, TextEncoder, TextDecoder, AbortSignal, setTimeout, clearTimeout,
    crypto: webcrypto, state,
    caches: { default: {
      async match(request) { return edge.get(request.url)?.clone(); },
      async put(request, response) { edge.set(request.url, response.clone()); },
    } },
    async fetch(url, options) {
      assert.equal(url, 'https://api.openai.com/v1/chat/completions');
      const request = JSON.parse(options.body);
      state.calls.push(request);
      const inputs = JSON.parse(request.messages.at(-1).content).items;
      const output = state.override || { items: inputs.map((item, index) => ({
        index: item.index, foodType: state.types[index] || 'unknown',
      })) };
      return Response.json({ choices: [{ message: { content: JSON.stringify(output) } }] }, { status: state.status });
    },
  });
  vm.runInContext(source + `
    globalThis.api = { worker, classifyFoodItems, classifiedFoodResponse, spoonacularCacheKey };
    globalThis.stubCatalog = (payload) => {
      foodSearchCatalogResponse = async () => json(payload);
      foodSearchCatalogSectionResponse = async () => json(payload);
      searchDishAllSources = async () => payload;
    };
  `, context);
  const env = { OPENAI_API_KEY: 'test', SPOONACULAR_API_KEY: 'test' };
  return { ...context.api, edge, state, env, stubCatalog: context.stubCatalog,
    async post(items, extra = {}) {
      return context.api.worker.fetch(new Request('https://bity.test/v1/food/classify', {
        method: 'POST', body: JSON.stringify({ items, locale: 'uk-UA', ...extra }),
      }), env, null);
    },
    async get(path) { return context.api.worker.fetch(new Request(`https://bity.test${path}`), env, null); },
    async matchRecipe(title, candidates) {
      return context.api.worker.fetch(new Request('https://bity.test/v1/food/match-recipe', {
        method: 'POST', body: JSON.stringify({ title, candidates, locale: 'uk-UA' }),
      }), env, null);
    },
  };
}

const food = (title, id = title) => ({ source: 'spoonacular', kind: 'ingredient', externalId: id, title });

test('semantic classification covers arbitrary prepared dishes and basic ingredients without changing provider identity', async () => {
  const app = runtime();
  const inputs = [food('Грибне різото', '100'), food('Shakshuka', '101'), food('Palak paneer', '102'),
    food('вареники з картоплею', '103'), food('помідор', '104'), food('cottage cheese', '105')];
  app.state.types = ['dish', 'dish', 'dish', 'dish', 'product', 'product'];
  const response = await app.post(inputs);
  assert.equal(response.status, 200);
  const { items } = await response.json();
  assert.deepEqual(items, inputs.map((item, index) => ({ ...item, foodType: app.state.types[index] })));
  assert.equal(app.state.calls.length, 1);
  assert.equal(app.state.calls[0].response_format.type, 'json_schema');
  assert.equal(app.state.calls[0].response_format.json_schema.strict, true);
  const evidence = JSON.parse(app.state.calls[0].messages.at(-1).content).items;
  assert.deepEqual(evidence.map(item => item.title), inputs.map(item => item.title));
});

test('recipe identity and retail metadata are authoritative, including packaged versions of dishes', async () => {
  const app = runtime();
  app.env.OPENAI_API_KEY = '';
  const inputs = [
    { source: 'spoonacular', kind: 'recipe', externalId: '1', title: 'Risotto', ingredients: ['rice'], steps: ['cook'], calories: 300 },
    { source: 'spoonacular', kind: 'product', externalId: '2', title: 'Canned tomato soup', brand: 'Retail Brand', nutrition: { calories: 75 } },
    { source: 'openfoodfacts', kind: 'product', externalId: '12345', title: 'Frozen lasagne', imageURL: 'https://example.test/image.jpg' },
    { source: 'catalog', kind: 'product', externalId: '4', title: 'Baked beans', brand: 'Store Brand' },
  ];
  const response = await app.post(inputs);
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).items, inputs.map((item, index) => ({ ...item, foodType: index === 0 ? 'dish' : 'product' })));
  assert.equal(app.state.calls.length, 0);
});

test('failed and unknown classifications return retryable 503 and never poison subsequent retries', async () => {
  const app = runtime();
  const inputs = [food('Святкова запіканка', 'retry')];
  app.state.status = 503;
  let response = await app.post(inputs);
  assert.equal(response.status, 503);
  assert.equal(response.headers.get('retry-after'), '2');
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal((await response.json()).retryable, true);
  assert.equal(app.edge.size, 0);
  app.state.status = 200;
  response = await app.post(inputs);
  assert.equal(response.status, 503);
  assert.equal((await response.json()).code, 'food_classification_unavailable');
  assert.equal(app.edge.size, 0);
  app.state.types = ['dish'];
  response = await app.post(inputs);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).items[0].foodType, 'dish');
  assert.equal(app.state.calls.length, 3);
});

test('missing or duplicate result indexes reject the entire batch instead of assigning another food type', async () => {
  for (const override of [
    { items: [{ index: 0, foodType: 'dish' }] },
    { items: [{ index: 0, foodType: 'dish' }, { index: 0, foodType: 'product' }] },
    { items: [{ index: 0, foodType: 'dish' }, { index: 7, foodType: 'product' }] },
    { items: [{ index: 0, foodType: 'dish' }, { index: 1, foodType: 'unknown' }] },
  ]) {
    const app = runtime();
    app.state.override = override;
    assert.equal((await app.post([food('Stuffed peppers'), food('pepper')])).status, 503);
    assert.equal(app.edge.size, 0);
  }
});

test('stable identities share valid cached decisions across cold workers and reordered requests', async () => {
  const app = runtime();
  const inputs = [food('Polenta with mushrooms', 'a'), food('cornmeal', 'b')];
  app.state.types = ['dish', 'product'];
  assert.equal((await app.post(inputs)).status, 200);
  const cold = runtime(app.edge);
  const response = await cold.post([...inputs].reverse());
  assert.deepEqual((await response.json()).items.map(item => item.foodType), ['product', 'dish']);
  assert.equal(cold.state.calls.length, 0);
  const translated = { ...inputs[0], title: 'Полента з грибами', sourceTitle: inputs[0].title };
  assert.equal((await (await cold.post([translated])).json()).items[0].foodType, 'dish');
  assert.equal(cold.state.calls.length, 0);
  // A recycled external ID with a different food name must not inherit the old decision.
  cold.state.types = ['product'];
  const changed = await cold.post([{ ...inputs[0], title: 'raw corn' }]);
  assert.equal((await changed.json()).items[0].foodType, 'product');
  assert.equal(cold.state.calls.length, 1);
});

test('duplicate catalog rows batch once and preserve independently localized titles and all metadata', async () => {
  const app = runtime();
  app.state.types = ['dish'];
  const a = { ...food('Mushroom risotto', 'dup'), sourceTitle: 'Mushroom risotto', amount: 100, unit: 'g', calories: 130 };
  const b = { ...a, title: 'Грибне різото', localizedLanguage: 'uk', imageURL: 'https://example.test/risotto.jpg' };
  const response = await app.post([a, b]);
  assert.deepEqual((await response.json()).items, [a, b].map(item => ({ ...item, foodType: 'dish' })));
  assert.equal(JSON.parse(app.state.calls[0].messages.at(-1).content).items.length, 1);
});

test('public Spoonacular ingredient search and information classify old cached payloads on read', async () => {
  const app = runtime();
  app.state.types = ['dish'];
  const searchPath = '/v1/spoonacular/ingredients/search?query=risotto&locale=en';
  const detailPath = '/v1/spoonacular/ingredients/100?amount=100&unit=grams&locale=en';
  const cachedSearch = { results: [{ id: 100, name: 'Mushroom risotto', image: 'risotto.jpg' }], totalResults: 1 };
  const cachedDetail = { id: 100, name: 'Mushroom risotto', nutrition: { nutrients: [{ name: 'Calories', amount: 130 }] } };
  app.edge.set(app.spoonacularCacheKey(new URL(`https://bity.test${searchPath}`), false).url, Response.json(cachedSearch));
  app.edge.set(app.spoonacularCacheKey(new URL(`https://bity.test${detailPath}`), false).url, Response.json(cachedDetail));
  const search = await app.get(searchPath);
  assert.equal(search.status, 200, await search.clone().text());
  assert.deepEqual(await search.json(), { ...cachedSearch, results: [{ ...cachedSearch.results[0], foodType: 'dish' }] });
  const detail = await app.get(detailPath);
  assert.equal(detail.status, 200);
  assert.deepEqual(await detail.json(), { ...cachedDetail, foodType: 'dish' });
  assert.equal(app.state.calls.length, 1);
});

test('all public catalog forms and unified search classify legacy payloads despite stale client-facing foodType', async () => {
  const app = runtime();
  app.state.types = ['dish'];
  const item = { ...food('Gratin dauphinois', 'legacy'), foodType: 'product', amount: 100, unit: 'g' };
  const payload = { version: 3, items: [item], sections: [{ id: 'products', items: [item] }], hasMore: true };
  app.stubCatalog(payload);
  for (const path of ['/v1/food/search/catalog?locale=en', '/v1/food/search/catalog.json', '/v1/food/search/catalog/products?locale=en']) {
    const response = await app.get(path);
    assert.equal(response.status, 200);
    const value = await response.json();
    assert.equal(value.items[0].foodType, 'dish');
    assert.equal(value.sections[0].items[0].foodType, 'dish');
    assert.equal(value.items[0].kind, 'ingredient');
    assert.equal(value.items[0].externalId, 'legacy');
    assert.equal(value.hasMore, true);
  }
  const response = await app.worker.fetch(new Request('https://bity.test/v1/food/search', {
    method: 'POST', body: JSON.stringify({ query: 'gratin', locale: 'en' }),
  }), app.env, null);
  assert.equal((await response.json()).items[0].foodType, 'dish');
  assert.equal(app.state.calls.length, 1);
});

test('large catalogs use bounded batches and unordered model outputs preserve input identity', async () => {
  const app = runtime();
  app.state.types = Array(24).fill('dish');
  const inputs = Array.from({ length: 50 }, (_, index) => food(`Prepared dish ${index}`, `${index}`));
  const response = await app.post(inputs);
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).items, inputs.map(item => ({ ...item, foodType: 'dish' })));
  assert.deepEqual(app.state.calls.map(call => JSON.parse(call.messages.at(-1).content).items.length), [24, 24, 2]);
  const other = runtime();
  other.state.override = { items: [{ index: 1, foodType: 'product' }, { index: 0, foodType: 'dish' }] };
  const result = await other.post([food('Moussaka'), food('eggplant')]);
  assert.deepEqual((await result.json()).items.map(item => item.foodType), ['dish', 'product']);
});

test('unavailable classifier never silently defaults unknown products and validates request bounds', async () => {
  const app = runtime();
  app.env.OPENAI_API_KEY = '';
  assert.equal((await app.post([food('Mystery food')])).status, 503);
  assert.equal(app.state.calls.length, 0);
  for (const inputs of [[], Array(51).fill(food('food')), [{ title: '' }], [{ title: 'a'.repeat(501) }]]) {
    assert.equal((await app.post(inputs)).status, 400);
  }
});

const recipeCandidates = [
  { externalId: '23', title: 'Chicken baked in tomato sauce', ingredients: ['Chicken', 'Tomatoes'], steps: ['Bake the chicken in sauce.'] },
  { externalId: '45', title: 'Cream of tomato soup', ingredients: ['Tomatoes', 'Vegetable stock', 'Cream'], steps: ['Cook tomatoes in stock and blend with cream.'] },
];

test('recipe matching supplies full composition and returns only a verified candidate identity', async () => {
  const app = runtime();
  app.state.override = { index: 1 };
  const response = await app.matchRecipe('Помідорний суп', recipeCandidates);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { externalId: '45' });
  const prompt = app.state.calls[0];
  assert.equal(prompt.response_format.json_schema.name, 'food_recipe_match');
  const evidence = JSON.parse(prompt.messages.at(-1).content);
  assert.equal(evidence.title, 'Помідорний суп');
  assert.deepEqual(evidence.candidates, recipeCandidates.map((item, index) => ({ index, ...item })));
  const repeated = await app.matchRecipe('Помідорний суп', recipeCandidates);
  assert.equal(repeated.status, 200);
  assert.equal(app.state.calls.length, 1);
});

test('recipe matching supports explicit no-match and never treats service failure as verified equivalence', async () => {
  const app = runtime();
  app.state.override = { index: null };
  let response = await app.matchRecipe('Ratatouille', recipeCandidates);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { externalId: null });
  app.state.status = 503;
  response = await app.matchRecipe('Bean casserole', recipeCandidates);
  assert.equal(response.status, 503);
  assert.equal((await response.json()).code, 'food_recipe_match_unavailable');
  app.state.status = 200;
  app.state.override = { index: 0 };
  response = await app.matchRecipe('Bean casserole', recipeCandidates);
  assert.equal(response.status, 200);
  assert.equal(app.state.calls.length, 3);
});

test('malformed recipe matches and candidates without full composition cannot open an unverified recipe', async () => {
  for (const override of [{ index: 2 }, { index: -1 }, { externalId: 'invented' }, { index: '0' }]) {
    const app = runtime();
    app.state.override = override;
    const response = await app.matchRecipe('Soup', recipeCandidates);
    assert.equal(response.status, 503);
    assert.equal(app.edge.size, 0);
  }
  const app = runtime();
  for (const candidates of [[{ ...recipeCandidates[0], ingredients: [] }],
    [{ ...recipeCandidates[0], steps: [] }], [recipeCandidates[0], recipeCandidates[0]]]) {
    assert.equal((await app.matchRecipe('Soup', candidates)).status, 400);
  }
  assert.equal(app.state.calls.length, 0);
  assert.deepEqual(await (await app.matchRecipe('Soup', [])).json(), { externalId: null });
});
