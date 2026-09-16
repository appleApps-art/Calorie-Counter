# Recipe review — 2026-09-16

Implemented shared fixes (no recipe-specific conditions):

- SpoonacularService caches successful recipe detail responses for 24 hours in memory, by locale, recipe ID and localization revision. Concurrent requests share a task; failures are retried on a later opening. Up to 100 entries retained.
- Worker persists complete localized recipe payloads through the existing R2/KV recipe cache for 30 days. Expired or incompletely translated payloads are rejected. Production wrangler configuration already binds BITY_BUCKET. Deployment is required; no deployment performed.
- Recipe diary sheet uses the light mint / dark elevated background, primary cards, smaller shadows, a filled circular close button, an intrinsically sized calendar and a shorter footer fade. Scrolling clears the save button.
- Browse and category cards use a single truncated title and separate time/calorie metadata below the photo. Browse previews show two cards; More opens the full category. Dark backgrounds are black with elevated cards.
- Share image uses a phone-width single column, full ingredients, numbered instructions, legible contrast, fixed 3x export, and a compact header when no photo exists.
- Tab backdrop is mint in light Home/Progress/Recipes and neutral white in Rewards; dark backdrop is black. Existing navigation visibility rules suppress it when the tab bar is hidden.

Validation:
- iOS build passed.
- 23 initial targeted iOS tests passed (image loading, caching, tab backdrop).
- 7 follow-up tests passed (share export, responsive cards, segmented controls, tab backdrop).
- Calendar regression passed in both explicitly asserted themes: native calendar retains its height and scrolls completely above the save button.
- Full worker suite: 119 passed, 0 failed. Includes cold edge reuse and expired durable cache.
- Git status/diff reviewed. Global diff --check still reports nine pre-existing whitespace-only XIB lines outside these edits.

Screenshots use QA seed data; solid color recipe thumbnails and English fixture titles are intentional fixtures, not production catalog output. Rewards screenshots capture the automatic earned-badge celebration, rather than the root grid. macOS locked during the final interactive pass; remaining calendar verification uses XCTest.
