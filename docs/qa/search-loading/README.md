# Search loading — 2026-09-15

An exact cached result remains visible and tappable while additional search sources are pending. The result card shows three trailing shimmer rows after partial results, or six rows while no source has returned. Loading completes only after catalog and unified search both finish. Clearing, changing or leaving a search cancels it and rejects late responses. Numeric enrichment and image loading retain their existing row behavior.

Reuses the shared ShimmerView; its dark sheen now brightens the placeholder instead of sweeping black over a black card. Existing result rows stay intact when the loading state toggles, and skeletons are noninteractive and excluded from accessibility navigation.

Verification: 98 search tests passed; after the dark-contrast adjustment, all 7 focused UI/loading tests passed again. Covered delayed completion, failure, source completion order, canceled/new searches, initial/partial/AI-only states, row identity, and both themes. Screenshots are captured from UIKit tests with a synthetic orange photo; native glass compositing is not fully represented by layer-render captures.

- [Light](partial-light.png)
- [Dark](partial-dark.png)

Delivery: update the iOS build. This change does not modify the worker.
