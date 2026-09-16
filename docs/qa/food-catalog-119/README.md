# Catalog first-load recovery — revision 119

Follow-up to the reported first-opening failure, 2026-09-10.

## Observations

- Production `/health` reported revision 118.
- The Ukrainian prepared-meal preview (`locale=uk-UA&offset=0&limit=2`) returned HTTP 200 in 0.205 seconds with translated names.
- A different page-cache key (`limit=3`) returned HTTP 200 in 0.381 seconds. This does not establish that the worker or storage was cold.
- The user's exact first failure was not reproduced. Code inspection confirmed that the iOS catalog request had no automatic retry or explicit reuse of its last successful response; a temporary error immediately became a failed section.
- The worker converted thrown R2 reads into missing objects, allowing a transient storage problem to enter the fallback catalog path.

## Changes and verification

The catalog service automatically retries temporary HTTP/network failures within a finite budget, validates response shape, and caches successful pages by the complete URL. Fresh pages can be reused on reopening; a bounded stale response can cover a temporary refresh failure. Permanent HTTP errors and cancellation do not trigger retries. The worker retries failed R2 reads once and propagates persistent failures without caching an absent catalog.

`/tmp/bity-catalog-119.xcresult`: **63 iOS food-search tests passed, zero failures**, iPhone 17 Pro simulator, iOS 26.5. Seven added cases exercise the real catalog service through URLProtocol: first request 503 then success without publishing a failed view-model section; network loss then 520 then success; cache reuse across service instances and isolation by page offset; stale recovery; permanent errors; bounded retries without caching errors; malformed success payloads; cancellation. Some cases cover multiple related transitions.

`/tmp/bity-catalog-119-tests.log`: **49 worker tests passed, zero failures**. Added cold-storage scenarios verify a transient R2 read recovers during the first endpoint request without Spoonacular/AI, and a repeated R2 failure returns uncached 503 followed by successful recovery on the next request.

No layout was changed in this follow-up; revision 118's retry-card inset remains covered by the iOS suite. Revision 119 was not published by this task. Both the updated worker and a new iOS build are required.
