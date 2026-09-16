# Prepared meals failure and retry inset — revision 118

Production diagnosis, 2026-09-10:

- `/health` confirmed worker revision 117 was already published.
- `GET /v1/food/search/catalog/preparedMeals?locale=en&offset=0&limit=2` returned 200.
- The same request with `locale=uk` returned 503 in about 2.7 seconds.
- The hard-coded R2 source `recipe-sections/v10/en-US.json` returned 404; `recipe-sections/v10/uk-UA.json` existed with translated recipes.

The corrected worker uses the shared recipe locale normalization and native stored titles, with source-ID matching across languages. Only the prepared-meal cache namespace changes, so the old fallback list cannot prevent the corrected lookup. If individual translations remain unavailable, ready items are returned with a cursor based on inspected source entries; a fully unavailable page remains retryable.

A local replay used the actual Ukrainian R2 JSON and disabled all outgoing requests: preview returned 200 with two recipes and no AI request; the first and second More pages returned 200 with 19 ready titles each, cursors 20 and 40. The missing title on each larger page could not be translated under the deliberately disabled network. This replay does not measure live server latency.

The client retry card uses its existing XIB-backed inset controls: bottom 16 adaptive points, top 24. Compared the supplied screenshot `/Users/dreamstore/Downloads/Знімок екрана 2026-09-10 о 17.32.25.png` and `dark.png` / `light.png` together. The button is separated from the bottom edge in both themes; existing fonts, artwork, card styling and action remain. All images are 1206 × 2622 pixels. Test viewport is 402 × 874 points at 3×. UIKit layer captures omit native glass compositing and status-bar chrome; product photos in the test are placeholders.

Validation: 56 iOS food-search tests passed (`/tmp/bity-catalog-118.xcresult`); 47 worker tests passed (`/tmp/bity-catalog-118-tests.log`). A UI regression test measures the bottom inset and taps Retry, then checks that recipes recover while the product section stays loaded.

Local fixes verified. Worker revision 118 has not been published in this task. Publish `cloudflare/bity-assistant-worker/worker.js` and install the updated iOS build to apply both changes.
