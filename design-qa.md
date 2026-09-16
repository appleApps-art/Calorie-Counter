# Shared food search — local design QA

Date: 2026-09-10. Scope: implement the selected first option inside the native app using its existing components, as explicitly requested by the user. This is a structure and component integration review, not a claim of pixel-for-pixel reproduction of the generated image.

## Visual evidence and normalization

Evidence directory: `/Users/dreamstore/Desktop/iOS.Apps/Calorie Counter/docs/qa/shared-food-search-117/`.

- Source visual truth: `selected-option.png`, copied from `/Users/dreamstore/.codex/generated_images/01a08a68-8a50-7dc1-ac89-22acd55d8a09/exec-bd580115-d397-4b11-8a27-a69aa44b360c.png`.
- Before fixes: `light-before.png`, `dark-before.png`.
- Final implementation: `light-after.png`, `dark-after.png`.
- Same-width comparison: `selected-option-1x.png`, `light-after-1x.png`, `dark-after-1x.png`, opened together in one comparison input. The original-resolution images were also opened together, where the captions and controls are readable without additional focused crops.
- Native viewport: 402 × 874 points, iPhone 17 Pro / iOS 26.5 Simulator. Implementation images are 1206 × 2622 pixels at 3×. Source is 850 × 1850 pixels with no declared device scale; normalized to 402 × 875 pixels. Implementation copies are normalized to 402 × 874 pixels. CSS size is not applicable to UIKit.
- State: Ukrainian, All selected, empty query, two recent entries, two meals, two products, keyboard closed; light and dark. Source supplies a light theme only. Dark uses existing app theme tokens.

## Comparison history

1. Initial comparison found [P2] the search placeholder too dark in dark mode and [P2] unlocalized `g` in catalog captions. Evidence: before images. Result at that stage: blocked.
2. Changed the placeholder from the footer color to existing `AppColor.labelsSecondary`. Localized gram/milliliter unit labels while retaining numeric source amounts. Rebuilt and captured the same viewport and fixture state.
3. Final combined comparison: placeholder now readable; Ukrainian unit captions render correctly. No remaining actionable P0/P1/P2 discrepancy within the requested layout/component scope.

## Required fidelity surfaces

| Surface | Result |
| --- | --- |
| Fonts and typography | Existing app system fonts remain: semibold row/section titles, secondary captions, and the existing recipe segment's type scale. Cyrillic labels fit. Smaller segment and row dimensions than the generated proposal are intentional reuse of the app's components. |
| Spacing and layout | Existing XIB margins, rounded cards, row separators, shadows and navigation geometry retained. All three sections contain two rows and remain visible at this viewport. The existing separate clear button remains. Source has different safe-area and generated control proportions; these are accepted under the user's reuse requirement. |
| Colors and tokens | Existing background asset and light/dark semantic colors retained. Teal selection and More actions remain distinct. Dark placeholder contrast was corrected. |
| Images and assets | Existing `appBackground`, SF Symbols and `RemoteImageLoader` are reused. Snapshot fixtures deliberately use unavailable photo URLs or no image, so these captures show the existing fallback. Generated proposal food photography was not copied or replaced with new drawn assets. Actual remote-photo sharpness, subject matching, and CDN availability are not validated by these deterministic snapshots. Worker tests validate photo URLs, recipe/product kinds, and storage-first selection. |
| Copy and content | Add food, unified placeholder, All / Products / Meals, Recent / Prepared meals / Products are localized. Kind prefixes distinguish recent and mixed search rows. Fixture names, portions, nutrition and order differ from illustrative proposal data. No fabricated proposal nutrition was added to production. |

UIKit layer captures omit live glass compositing and system status-bar rendering. Those differences are capture limitations, not evidence that native glass was removed. A physical-device/live-data visual pass remains a release validation gap.

## Behavior and validation

- All requests only two visible catalog previews; Products loads the existing seven grocery categories when selected. Returning to a scope reuses loaded data.
- Search scopes retain the query and filter both result kinds, including scope changes during a request.
- Recent entries are deduplicated by name and kind; selecting one preserves its image and uses the current meal and date.
- More uses the existing category screen, 20-item pagination and retry while retaining loaded rows.
- Existing recipe segment behavior and its callbacks remain functional; VoiceOver adjustment works for the reused control.
- Pantry remains product-only. Existing edit-meal interaction regression checks passed.
- Empty search, retry, stored translation reuse, locale separation, source offsets and exhaustion are covered by automated checks; empty/error states were not separately screenshot-reviewed.

Clean native run: `/tmp/bity-shared-search-117-final.xcresult`, **64 passed, 0 failed**. Backend: `/tmp/bity-shared-search-worker-tests.log`, **42 passed, 0 failed**. XIB XML and localization key uniqueness checked.

## Implementation checklist

- [x] Implement the selected information structure with existing UIKit components.
- [x] Fix findings, capture again, and compare source and implementation together.
- [x] Validate filters, recents, paginated More, cache and localization behavior.
- [ ] Publish worker revision 117 and install the new iOS build; deployment was not performed in this task.
- [ ] Validate native glass and real food-photo loading on a device against the published backend.

final result: passed

## Follow-up: retry state and unavailable prepared meals (revision 118)

The user's later screenshot exposed a retry state that the original screenshot pass had not covered: the action touched the card bottom, and the Ukrainian prepared-meal endpoint returned 503. Both were corrected and independently verified. The updated state captures, production diagnosis, real-R2 replay and regression coverage are recorded in `docs/qa/food-catalog-118/README.md`. The new error-state visual check passed in light and dark. Revision 118 publication and a new iOS build remain required.

## Follow-up: first-opening recovery (revision 119)

Production revision 118 was confirmed live and returned the Ukrainian preview successfully during the follow-up. The reported first failure was not reproduced. The client now recovers from temporary request failures automatically and reuses validated successful pages; the worker distinguishes failed R2 reads from missing catalogs. The existing layout is unchanged. Verification: 63 iOS food-search tests and 49 worker tests passed. Evidence and limits are recorded in `docs/qa/food-catalog-119/README.md`. Revision 119 publication and a new iOS build remain required.

## Follow-up: recipe details from shared food search

Both shared-search navigation callbacks previously opened `ProductDetailsViewController` unconditionally, including when the selected draft retained `catalogKind == .recipe`. The coordinator now uses the existing `RecipeDetailViewController` for those selections on the main search screen and More page. Products and ingredients retain their existing details destination.

The recipe screen receives the search logging context so adding food retains the selected meal/date, multiple dates, local photo and volume when applicable. Adding while recipe details are already loading awaits that request before preparing the diary draft. No new screen or layout was introduced.

Verification: `/tmp/bity-search-recipe-navigation.xcresult`, **142 passed, zero failures** across FoodSearchTests, AssistantImageLoadingTests and DomainLogicTests on iPhone 17 Pro / iOS 26.5. Four added tests exercise the coordinator callbacks, More row selection, the existing recipe view's three tabs, broth volume/local photo, and adding after recipe enrichment with the original meal/date. This was navigation and data-flow verification, not a new visual comparison against Figma. Applying this fix requires a new iOS build; there are no additional worker changes for this follow-up.

## Follow-up: Meals scope category structure

Meals now shows recent recipes followed by the nine active Recipes / All sections, with shared localization keys/data, two-row previews and More pagination. Existing food-search components are reused. A clean build passed 136 tests; all nine live Ukrainian preview routes returned two recipes successfully. The updated light/dark captures and validation limits are recorded in `docs/qa/meals-recipe-sections/README.md`. A new iOS build is required; the worker is unchanged in this follow-up.
