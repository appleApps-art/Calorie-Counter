# Product vs recipe details — 2026-09-15

Figma product: 204:56432 / 204:54820. Recipe states: 262:27773, 262:28167, 262:28226, 262:28285 and 262:25670, 262:25983, 262:26043, 262:26103.

ProductDetails keeps nutrition, score, tags, suggestions and diary action; it does not expose recipe ingredients or cooking instructions. Catalog composition remains available in the draft for logging. RecipeDetail provides nutrition, ingredients and instructions tabs. Logging callbacks and meal context are retained, including the pantry action's title. The recipe save button clears its legacy English XIB title.

Earlier visual checks (before revision 124): product dark/light, recipe nutrition/ingredients/instructions and saved confirmation in dark/light on iPhone 17 Pro iOS 26.5. QA uses synthetic solid-color photos and English recipe fixture text; those are not production search responses. Product screenshots attached. Clean build was required after stale incremental output. Five focused tests passed for product sections, routing, three tabs, save state and callback context.

## General food classification and complete recipe details — revision 124

This replaces the previous soup/name-word workaround and ingredient-only routing. Provider `kind` and external ID describe the API namespace; optional `foodType` (`product` / `dish`) describes what the item is. Unknown items use `/v1/food/classify`, which evaluates the food semantically rather than matching a list of dish names. Classification is reused across browse/search results, scopes, direct details, and recent/legacy diary routes. Unknown or failed classification remains retryable and is not silently converted into a product.

`ingredient:` and `product:` recipe references preserve the original lookup namespace, including when records are saved or projected from a legacy entry. A prepared-food nutrition ID is never sent to the recipe-details endpoint just because it is numeric. Semantic type and the optional nutrition-completeness flag survive draft/entry/recipe conversions and persistence; absent macros converted for older nonoptional models are not accepted as known zeroes.

Generic dishes resolve through Spoonacular recipe search and complete detail hydration. `/v1/food/match-recipe` checks the candidate's title, ingredients and instructions against the selected dish; substring ranking does not establish equivalence. Only a supplied, verified recipe can be adopted. When no catalog recipe is confirmed, a separately identified AI recipe may be generated for the selected dish. It has its own source, identity and visible AI label. The original record's photo, nutrients and portion are not grafted onto that recipe; logging date, meal and callback context carry over.

Every recipe origin must provide finite calories and protein/carbohydrate/fat values, ingredients and cooking steps. Numeric Spoonacular recipe previews are hydrated from their authoritative details endpoint before use. Incomplete records show loading or an error with a persistent Retry action, and cannot be logged, saved or shared as complete recipes. Missing micronutrients are omitted from recipe nutrition rows instead of displayed as fabricated zeroes.

Regression cases cover dishes without the old keywords across product and ingredient namespaces, semantic product exclusions, cached classification, unknown-classification retry, legacy diary namespace/date preservation, names that do not share a substring, rejection of unrelated near-name recipes, and incomplete details from all origins blocking save/log until retry succeeds. Final test results are recorded below.

### Delivery and verification boundary

Worker revision **124** introduces semantic classification and recipe-candidate verification. Delivery requires the user's worker deployment **and a new iOS build**. Revision 124 has not been verified against the live deployed service or on the user's phone. The earlier revision-123 check below validates only the previous server implementation, not this general fix.

### Historical live verification — revision 123

The user deployed revision 123. `/health` confirmed revision 123. The live Ukrainian tomato-soup search now returned catalog results, and `/v1/food/details` returned a complete AI recipe: calories/protein/carbs/fats present, 8 ingredients and 4 instructions. This confirms server responses; it is not a claim that the new iOS binary has been installed on the user's device.

## Final verification

- Worker: **113 passed, 0 failed** (`npm test --prefix cloudflare/bity-assistant-worker`).
- Final iOS run: **166 passed, 0 failed**, covering `FoodSearchTests`, `FoodTypeDataTests`, `ProductDetailsChromeTests`, and `DomainLogicTests` on iPhone 17 Pro / iOS 26.5. Includes semantic classification, namespace preservation, complete recipe hydration, failure/retry, Core Data V3→V4 migration, and logging/save guards.
- The earlier full iOS run had **424 passed, 8 failed**. One failure was the superseded source-only AI recipe classification assertion; its updated contract passes in the final run. Seven failures remain outside this food-classification change: two Dynamic Type assertions in `AdaptiveLayoutTests`, recipe-create sheet layout, two main-screen layout assertions, onboarding label layout, and the quick-log sheet safe-area assertion. The full suite is not claimed green.
- The bundled grocery catalog now carries explicit product metadata; unknown external/legacy foods still use semantic classification. Classification loading follows the originating screen, and canceled/dismissed navigation cannot push a late result.
- Final results: `/tmp/general-food-types-final-results.json`; prior full-suite results: `/tmp/general-food-types-all-results.json`.
- No revision-124 worker deployment was performed. The user previously chose to deploy the worker themselves. Live model accuracy/latency and the new binary on the user's phone remain unverified.
