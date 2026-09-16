import assert from "node:assert/strict";
import test from "node:test";
import {
  applySearchTitleMap,
  isAsciiFoodQuery,
  isCompleteSearchRecipe,
  polishSearchRecipeTitle,
  shouldTranslateFoodQuery,
  spoonacularRecipeImageURL,
} from "./recipe-search-helpers.js";

test("Cyrillic queries are translated; ASCII catalog words are not", () => {
  assert.equal(shouldTranslateFoodQuery("паста"), true);
  assert.equal(shouldTranslateFoodQuery("рататуй"), true);
  assert.equal(shouldTranslateFoodQuery("pasta"), false);
  assert.equal(shouldTranslateFoodQuery("ratatouille"), false);
  assert.equal(isAsciiFoodQuery("Chicken Parmesan"), true);
});

test("applySearchTitleMap never blanks titles that are not in the map", () => {
  const pending = [
    { item: { title: "Pasta Primavera", name: "Pasta Primavera" }, title: "Pasta Primavera" },
    { item: { title: "Ratatouille", name: "Ratatouille" }, title: "Ratatouille" },
  ];
  applySearchTitleMap(pending, { "Pasta Primavera": "Паста Прімавера" });
  assert.equal(pending[0].item.title, "Паста Прімавера");
  assert.equal(pending[1].item.title, "Ratatouille");
});

test("applySearchTitleMap ignores empty GPT rewrites", () => {
  const pending = [{ item: { title: "Borscht", name: "Borscht" }, title: "Borscht" }];
  applySearchTitleMap(pending, { Borscht: "   " });
  assert.equal(pending[0].item.title, "Borscht");
});

test("headline titles become a dish name without dropping the card", () => {
  assert.equal(polishSearchRecipeTitle("How to Make Ratatouille | BBC Good Food"), "Ratatouille");
  assert.equal(polishSearchRecipeTitle("Pasta recipes"), "Pasta");
  assert.equal(polishSearchRecipeTitle("Chicken Parmesan"), "Chicken Parmesan");
  assert.equal(polishSearchRecipeTitle(""), "");
});

test("Spoonacular ids always get a CDN photo when the API omits one", () => {
  assert.equal(
    spoonacularRecipeImageURL("715538", ""),
    "https://img.spoonacular.com/recipes/715538-636x393.jpg"
  );
  assert.equal(
    spoonacularRecipeImageURL("715538", "https://img.spoonacular.com/recipes/715538-312x231.jpg"),
    "https://img.spoonacular.com/recipes/715538-312x231.jpg"
  );
  assert.equal(
    spoonacularRecipeImageURL("715538", "https://example.com/placeholder.png"),
    "https://img.spoonacular.com/recipes/715538-636x393.jpg"
  );
});

test("search results without a title or photo are incomplete", () => {
  assert.equal(isCompleteSearchRecipe({ title: "Pasta", imageURL: "https://img.spoonacular.com/recipes/1-636x393.jpg" }), true);
  assert.equal(isCompleteSearchRecipe({ title: "Pasta", imageURL: "" }), false);
  assert.equal(isCompleteSearchRecipe({ title: "", imageURL: "https://img.spoonacular.com/recipes/1-636x393.jpg" }), false);
});
