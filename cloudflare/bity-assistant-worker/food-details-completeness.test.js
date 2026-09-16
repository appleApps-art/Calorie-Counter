import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source = readFileSync(new URL('./worker.js', import.meta.url), 'utf8')
  .replace('export default {', 'const worker = {').replaceAll('export class ', 'class ');
const complete = { title: 'Помідорний суп', calories: 280, protein: 8, carbs: 35, fats: 12,
  ingredients: ['Помідори 200 г', 'Вода 100 мл'], steps: ['Зваріть овочі.', 'Подрібніть блендером.'] };
function runtime(cached = null, estimate = null) {
  const state = { cached, estimate, writes: [], estimates: 0 };
  const context = vm.createContext({ URL, Request, Response, Headers, TextEncoder, TextDecoder,
    AbortSignal, setTimeout, clearTimeout, state });
  vm.runInContext(source + `
    recipeCacheGetJSON = async () => state.cached;
    recipeCachePutJSON = async (_env, key, value) => state.writes.push({ key, value });
    estimateDishDetails = async () => { state.estimates++; return state.estimate; };
    lookupFoodImageURL = async () => '';
    stableWebRecipeId = async () => 'openai-complete-soup';
    globalThis.api = { enrichFoodDetails, hasCompleteFoodDetails };
  `, context);
  return { ...context.api, state };
}
const request = { title: 'Помідорний суп', locale: 'uk-UA', kind: 'recipe', source: 'openai', env: {}, ctx: {} };
test('failed estimation is an explicit retryable error, never an empty successful item', async () => {
  const app = runtime();
  const result = await app.enrichFoodDetails(request);
  assert.equal(result.code, 'food_details_unavailable');
  assert.equal(result.retryable, true);
  assert.equal(result.item, undefined);
  assert.equal(app.state.writes.length, 0);
});
test('cached recipe missing instructions is refreshed with complete data', async () => {
  const app = runtime({ item: { ...complete, steps: [] } }, complete);
  const result = await app.enrichFoodDetails(request);
  assert.equal(result.item.calories, 280);
  assert.equal(result.item.ingredients.length, 2);
  assert.equal(result.item.steps.length, 2);
  assert.equal(app.state.estimates, 1);
  assert.equal(app.state.writes.length, 1);
});
test('missing macros or instructions do not become successful zero-valued recipes', async () => {
  for (const estimate of [{ ...complete, protein: null }, { ...complete, steps: [] }, { ...complete, ingredients: [] }]) {
    const app = runtime(null, estimate);
    const result = await app.enrichFoodDetails(request);
    assert.equal(result.item, undefined);
    assert.equal(app.state.writes.length, 0);
  }
});
test('complete cached recipe returns all sections without another generation', async () => {
  const app = runtime({ item: complete });
  const result = await app.enrichFoodDetails(request);
  assert.equal(result.item.steps.length, 2);
  assert.equal(app.state.estimates, 0);
});
