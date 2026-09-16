# Meals scope uses Recipes / All sections

The Meals scope in Add food now places recent recipes above the nine active Recipes / All categories, in the same order and with the same localization keys. It uses the existing food-search section cards with two recipe rows per category. More opens the corresponding paginated food-search category and preserves recipe navigation and the selected logging meal/date.

Data comes from the shared `FetchRecipeBrowseSectionsUseCase` and existing recipe-section endpoints. If Recipes / All is already in memory, its first two entries are reused. Otherwise the Meals scope requests offset 0, limit 2 for each category, in batches of at most three. Successful pages and simultaneous requests are shared; a temporary failure gets one automatic retry. Individual failed sections can be retried without reloading the others. More requests 20 recipes per page. The All scope retains prepared-meal/product previews; Products retains its seven grocery categories.

## Verification

- A clean iOS simulator build passed **136 tests, zero failures**: 72 FoodSearchTests, 57 DomainLogicTests and 7 RecipesChromeTests. Result: `/tmp/bity-meals-recipe-sections-clean.xcresult`. The first incremental run used an older test bundle, so it was superseded by the clean run.
- Added coverage verifies all nine categories after recents, identical titles/IDs to the shared source, two-item requests, bounded concurrency, reuse of Recipes / All data, pagination, selected meal/date, retry isolation and shared page requests.
- Existing screen coverage now checks all nine section headers and two rows each in both themes. Visually inspected `light.png` and `dark.png`: the recent section stays first, long category headings fit beside More, and established card/row styling remains consistent. These are 1206 × 2622 UIKit layer captures at a 402 × 874 point viewport. The fixture uses placeholder photos and synthetic recipe titles; native glass/status-bar compositing is not captured.
- Live Ukrainian requests to all nine existing `/v1/recipes/sections/:id` endpoints with `offset=0&limit=2` returned HTTP 200, two records, photo URLs and Cyrillic titles. Observed response times ranged from 0.49 to 2.40 seconds; these were not verified cold-cache measurements.

No worker changes were required for this follow-up. Install a new iOS build to apply it.
