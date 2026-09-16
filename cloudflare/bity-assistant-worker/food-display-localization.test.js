import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source = readFileSync(new URL('./worker.js', import.meta.url), 'utf8')
  .replace('export default {', 'const worker = {').replaceAll('export class ', 'class ');
function runtime() {
  const stored = new Map();
  const calls = [];
  const state = { fails: false };
  const context = vm.createContext({ URL, Request, Response, Headers, TextEncoder, TextDecoder,
    AbortSignal, setTimeout, clearTimeout,
    translate: async (_env, texts) => {
      calls.push([...texts]);
      return texts.map((text) => state.fails ? text : `Яйця по-шотландськи ${text.length}`);
    },
    readTranslation: async (_env, _lang, text) => stored.get(text) || '',
    writeTranslation: async (_env, _lang, text, value) => stored.set(text, value),
  });
  vm.runInContext(source + `
    translateFoodDisplayBatch = translate;
    cachedFoodDisplayTranslation = readTranslation;
    storeFoodDisplayTranslation = writeTranslation;
    cachedDishDisplayTitle = readTranslation;
    storeDishDisplayTitle = writeTranslation;
    rewriteDishDisplayBatch = translate;
    globalThis.api = { localizeSpoonacularPayload, spoonacularCacheKey, localizeSearchItemTitles };
  `, context);
  return { api: context.api, stored, calls, state };
}
const input = { results: Array.from({ length: 20 }, (_, id) => ({ id, title: `Scotch Egg ${id}`,
  summary: 'A very long description which the search row never displays', calories: 651 })) };
test('recipe search translates every title without wasting the budget on summaries', async () => {
  const app = runtime();
  const result = await app.api.localizeSpoonacularPayload({ OPENAI_API_KEY: 'test' },
    '/v1/spoonacular/recipes/search', input, 'uk-UA', false);
  assert.equal(app.calls.flat().length, 20);
  assert.ok(result.results.every((r) => r.title.startsWith('Яйця')));
  assert.equal(result.results[0].calories, 651);
  assert.equal(input.results[0].title, 'Scotch Egg 0');
});
test('failed translation is not returned or cached as Ukrainian, and retry recovers', async () => {
  const app = runtime(); app.state.fails = true;
  const run = () => app.api.localizeSpoonacularPayload({ OPENAI_API_KEY: 'test' },
    '/v1/spoonacular/recipes/search', input, 'uk-UA', false);
  await assert.rejects(run(), /translation unavailable/);
  assert.equal(app.stored.size, 0);
  app.state.fails = false;
  assert.ok((await run()).results.every((r) => r.title.startsWith('Яйця')));
});
test('English search keeps original names', async () => {
  const app = runtime();
  assert.equal(await app.api.localizeSpoonacularPayload({}, '/v1/spoonacular/recipes/search', input, 'en-US', false), input);
  assert.equal(app.calls.length, 0);
});

for (const [path, field, array] of [
  ['/v1/spoonacular/ingredients/search', 'name', 'results'],
  ['/v1/spoonacular/products/search', 'title', 'products'],
]) {
  test(`${path}: ingredients and groceries reject failed translations and recover`, async () => {
    const app = runtime();
    const names = ['duck eggs', 'quail eggs', 'poached egg', 'chocolate eggs', 'hard boiled egg'];
    const payload = { [array]: names.map((name, id) => ({ id, [field]: name })) };
    app.state.fails = true;
    const run = () => app.api.localizeSpoonacularPayload({ OPENAI_API_KEY: 'test' }, path, payload, 'uk-UA', false);
    await assert.rejects(run(), /translation unavailable/);
    assert.equal(app.stored.size, 0);
    app.state.fails = false;
    const result = await run();
    assert.equal(result[array].length, 5);
    assert.ok(result[array].every((r) => r[field].startsWith('Яйця')));
  });
}
test('unified search translates beyond the first twelve items', async () => {
  const app = runtime();
  const items = Array.from({ length: 30 }, (_, id) => ({ id, title: `egg ${id}`, source: 'spoonacular' }));
  const result = await app.api.localizeSearchItemTitles({ OPENAI_API_KEY: 'test' }, null, items, 'uk-UA');
  assert.equal(result.length, 30);
  assert.equal(app.calls.flat().length, 30);
  assert.ok(result.every((r) => r.title.startsWith('Яйця')));
});

test('unified search does not publish an English tail after translation failure', async () => {
  const app = runtime(); app.state.fails = true;
  const items = [{ title: 'quail eggs', source: 'spoonacular' }];
  await assert.rejects(app.api.localizeSearchItemTitles({ OPENAI_API_KEY: 'test' }, null, items, 'uk-UA'), /translation unavailable/);
});
