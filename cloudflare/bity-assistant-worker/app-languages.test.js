import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(new URL('./worker.js', import.meta.url), 'utf8')
  .replace('export default {', 'const worker = {').replaceAll('export class ', 'class ');

function load() {
  const context = vm.createContext({ URL, Request, Response, Headers, TextEncoder, TextDecoder, AbortSignal, setTimeout, clearTimeout });
  vm.runInContext(source + `
    globalThis.api = { localeLanguage, foodSearchCatalogLanguage, defaultRecipeServing, localizedRecipeUnit, recipeWebQuery, displayLanguageName };
  `, context);
  return context.api;
}

// Every language the iOS app ships, as iOS reports it in `locale`.
const APP_LOCALES = {
  'en-US': 'en', 'uk-UA': 'uk', 'fr-FR': 'fr', 'de-DE': 'de', 'it-IT': 'it', 'es-ES': 'es',
  'pt-BR': 'pt-br', 'tr-TR': 'tr', 'ja-JP': 'ja', 'ko-KR': 'ko', 'zh-Hans-CN': 'zh',
  'zh-Hant-TW': 'zh-hant', 'vi-VN': 'vi', 'ar-SA': 'ar',
};

test('the food catalog keeps Traditional Chinese and Brazilian Portuguese apart', () => {
  const api = load();
  for (const [locale, language] of Object.entries(APP_LOCALES)) {
    assert.equal(api.foodSearchCatalogLanguage(locale), language, locale);
    assert.equal(api.localeLanguage(locale), language, locale);
  }
  assert.equal(api.foodSearchCatalogLanguage('zh_Hant'), 'zh-hant');
  assert.equal(api.foodSearchCatalogLanguage('pt_BR'), 'pt-br');
  assert.equal(api.foodSearchCatalogLanguage('pt-PT'), 'pt');
  assert.equal(api.foodSearchCatalogLanguage(''), 'en');
});

test('every app language has a translation target name', () => {
  const api = load();
  for (const language of Object.values(APP_LOCALES)) {
    if (language === 'en') continue;
    assert.notEqual(api.displayLanguageName(language), language, language);
  }
  assert.equal(api.displayLanguageName('zh-hant'), 'Traditional Chinese');
});

test('generated recipes use the app language for servings and units', () => {
  const api = load();
  for (const locale of Object.keys(APP_LOCALES)) {
    const serving = api.defaultRecipeServing(locale);
    assert.ok(serving, locale);
    if (!locale.startsWith('en')) assert.notEqual(serving, '1 serving', locale);
  }
  assert.equal(api.defaultRecipeServing('ja-JP'), '1人分');
  assert.equal(api.localizedRecipeUnit('tbsp', 'de-DE'), 'EL');
  assert.equal(api.localizedRecipeUnit('tsp', 'zh-Hant-TW'), '茶匙');
  assert.equal(api.localizedRecipeUnit('g', 'fr-FR'), 'g');
});

test('recipe web searches add the recipe word in the same language', () => {
  const api = load();
  assert.equal(api.recipeWebQuery('poulet rôti', 'fr-FR'), 'poulet rôti recette');
  assert.equal(api.recipeWebQuery('Hähnchen', 'de-DE'), 'Hähnchen Rezept');
  assert.equal(api.recipeWebQuery('борщ', 'uk-UA'), 'рецепт борщ');
  assert.equal(api.recipeWebQuery('chicken', 'en-US'), 'chicken recipe');
  assert.equal(api.recipeWebQuery('receta de paella', 'es-ES'), 'receta de paella');
});
