# Product insights — 2026-09-15

Figma: product 204:56432 / 204:54820; ingredient recipe card 204:56469.

ProductDetails now always presents a wellness insight. Without a supplied alternative, it calculates the selected portion's calories and protein against the selected date's diary and goals, locally. It updates on screen appearance and catalog enrichment. Missing diary/nutrition has explicit localized copy; no calorie or protein budget is invented. Alternative actions remain available only when an actual alternative exists.

The ingredient recipe card searches Spoonacular using includeIngredients, then falls back to the existing AI recipe search. Search results are now only candidates: catalog recipes are hydrated through recipeDetails and both catalog/AI candidates must contain the requested ingredient in their ingredient list. Titles, summaries and steps are not proof. Empty or unverified details are rejected; an empty verified catalog triggers the AI fallback, which is checked in the same way. Matching uses complete words, all requested qualifiers, and conservative English/Ukrainian inflections. Brand or language variants that cannot be confirmed are omitted rather than guessed. It prefers a verified recipe serving within the remaining calorie budget. It has a native loading indicator and a retry state. Opening the recipe preserves the selected date/meal and logging callback; it never logs automatically. Product composition stays hidden on product screens.

Validation: 8 targeted XCTest tests passed (ProductDetailsChromeTests and direct food-detail routing). Simulator checked both themes and the related recipe transition. Screenshot photos are orange QA fixtures, not production catalog images. Production images come from the corresponding product/recipe URLs. Card thumbnail is 44 × 44 with 12pt corners.

Screenshots: dark.png, light.png.
