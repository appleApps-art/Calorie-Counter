# Bity AI Worker — Variant A (Chat Completions + Spoonacular proxy)

Production endpoint: `https://assistant.chatte.workers.dev`

Copy-paste file: `worker.js`

## Secrets / vars in Cloudflare
- `OPENAI_API_KEY` (secret) — required for chat / 5 AI recipes
- `SPOONACULAR_API_KEY` (secret) — required for `/v1/spoonacular/*`
- `OPENAI_IMAGE_SEARCH_MODEL` (var) — optional, default `gpt-5.6` (web photos for AI recipes)
- `APP_API_KEY` (secret) — optional
- `OPENAI_MODEL` (var) — optional, default `gpt-5.6-luna` (non-chat workloads)
- `OPENAI_CHAT_MODEL` (var) — optional, default `gpt-6-astra` (`/v1/chat`, Responses API, reasoning `low`)
- `OPENAI_VISION_MODEL` (var) — optional, default `gpt-6-astra` (photo analysis + chat with image; luna cannot read images)
- `OPENAI_TRANSLATE_MODEL` (var) — optional, default `gpt-4o-mini` (search query → English; result names → user language)
- `OPENAI_TRANSCRIBE_MODEL` (var) — optional, default `gpt-4o-mini-transcribe`

Recipe photos: reuse stored image bytes and cached recipe metadata, then search Spoonacular, then use Tavily / AI web search as fallbacks. Photos are validated and persisted in R2 at `food-images/v1/<stable-id>`.

## Endpoints
- `GET /health`
- `POST /v1/chat` — OpenAI chat + `propose_*` tools
- `GET /v1/generated-images/:id` — stored food photo; `202` while the photo job is pending
- `GET /v1/food/image?name=` — recover a missing or broken diary photo by dish name
- `POST /v1/food/analyze-photo` — food photo → structured nutrition estimate (`propose_food_log`)
- `POST /v1/food/analyze-text` — free-text food description → structured nutrition estimate (`propose_food_log`)
- `POST /v1/food/transcribe` — voice audio → text (auto language)
- `POST /v1/food/analyze-voice` — voice audio → transcription + structured nutrition estimate
- `GET /v1/spoonacular/recipes/search?query=&locale=`
- `GET /v1/spoonacular/recipes/:id?locale=`
- `GET /v1/spoonacular/ingredients/search?query=&locale=`
- `GET /v1/spoonacular/ingredients/:id?amount=&unit=&locale=`
- `GET /v1/spoonacular/products/search?query=&locale=`
- `GET /v1/spoonacular/products/upc/:barcode?locale=`

## Chat flow
1. iOS → `POST /v1/chat` (message + userContext + history + optional photo)
2. Worker → OpenAI `/v1/responses` for Astra (system instructions + history + optional category intent + tools)
3. Якщо є `toolCalls` (`propose_*`) → апка показує картки і пише дані лише після Confirm
4. Якщо лише text → звичайна відповідь в чат

Tools include `propose_water_log` for plain water (ml). Caloric drinks still use `propose_food_log`.

## Spoonacular flow (Cook plan: 5 req/s, 5 concurrent, 1500 points/day)
1. iOS → `GET /v1/spoonacular/...` (без Spoonacular key в апці)
2. Worker кешує відповідь, ставить запити в чергу (5/s і 5 concurrent) і проксує allowlisted upstream
3. Пошук інгредієнтів / продуктів / рецептів: якщо запит не англійською, воркер коротко перекладає його на English food name (кеш), потім б’є в Spoonacular. `locale` з апки на Spoonacular не йде.
4. Якщо `locale` не English, воркер перекладає видимі назви (title/name, summary, інгредієнти, кроки) на мову користувача одним батчем + кеш фрази. Англійську відповідь Spoonacular кешує окремо. Запити `lite=1` (лише фото) не локалізуються.
5. Після `propose_food_log` / replace / swap / recipe / meal suggestions воркер одразу додає стабільне посилання на фото. Якщо підключений `RECIPE_IMAGES`, використовується завдання Durable Object. Без нього працює `/v1/food/image?name=...` із наявним `BITY_BUCKET`; відсутність Durable Object не спричиняє `503`.
6. Порядок пошуку: кеш готових байтів → R2 → фото зі збережених рецептів і каталогів → Spoonacular → Tavily → AI web search. Spoonacular повертає до 5 кандидатів; назви перевіряються на відповідність, зламані посилання пропускаються. Для «плов» використовується запит `pilaf` без додаткового перекладу. Одночасні запити одного фото в одному екземплярі воркера об'єднуються; з Durable Object завдання також спільне між екземплярами. Пошук фото обмежений 25 секундами. Тимчасова невдача без Durable Object кешується на 60 секунд; завдання Durable Object має до трьох спроб і припиняє повертати pending через 2 хвилини. Нову спробу після його остаточної невдачі можна запустити через 5 хвилин.
7. Пошук рецептів без nutrition (1 point). Ккал підвантажуються на екрані деталей.

Durable Object binding `SPOONACULAR_GATE` потрібен для глобальної черги між усіма юзерами. Деплой: `npx wrangler deploy` з цього каталогу.

`BITY_BUCKET` зберігає готові фото незалежно від `RECIPE_IMAGES`. Готові фото повертають `200` і кешуються 30 днів; очікування Durable Object — `202`, `Retry-After: 2`, `Cache-Control: no-store`; остаточна невдача — `404`, `X-Image-Status: failed`. Заголовок `X-Image-Source` показує джерело фото (`cache`, `storage`, `recipe-cache`, `spoonacular`, `web`, `ai-search`). Існуючі завантажені фото користувача не замінюються. Міграція сховища для цього виправлення не потрібна.

Клієнт зберігає готові зображення в пам'яті та URLCache на диску, об'єднує одночасні завантаження і обмежує очікування 30 секундами. `404` одразу переходить до відновлення за назвою; `503` та мережеві помилки мають максимум 3 спроби; `202` — максимум 12 запитів із урахуванням `Retry-After`. Невдача завершує індикатор і показує іконку страви; повторне відкриття протягом 20 секунд не запускає той самий невдалий запит знову.

Публікація: оновити `worker.js` у наявному воркері `assistant` зі збереженням поточних секретів і прив'язки `BITY_BUCKET` → `bity`, або виконати `npx wrangler deploy --keep-vars` після `npx wrangler login`. `/health` має показувати `workerRev: 119` та `imageStorage.r2: true`. Для перевірки фото: `GET /v1/food/image?name=Плов`; повторний запит повинен повертати готове зображення з кешу або сховища. Клієнтські зміни потребують нової збірки iOS.

Локальні перевірки: `npm test`.

## Food-search catalog (revision 116)

The search landing screen follows the seven Figma food categories. `GET /v1/food/search/catalog?locale=uk_UA` returns two localized items per category. There is no separate prepared-meals browse category; entered searches still include dishes and products.

`GET /v1/food/search/catalog/:sectionId?locale=uk_UA&offset=0&limit=20` returns one localized page with `nextOffset` and `hasMore`. The iOS screen requests the first page when “See more” opens, then requests subsequent pages on scrolling. It preserves loaded rows on failure and offers retry.

Memory cache and R2 are checked before upstream requests. Raw category results are appended using Spoonacular offsets and persisted with their cursor; opening a category no longer fetches all category queries. Only the visible home items or requested page are translated. The home translations are reused in the first page, and complete localized pages are persisted separately per language and offset. There is no background translation of the rest of the catalog. Failed translations return retryable `503` and are not stored as localized results. The cache namespace is `food-search-catalog/spoonacular/v4/`; prior cache objects do not need to be deleted.

Deploy `worker.js` revision 119 and rebuild iOS for the current catalog changes. Local coverage includes preview translation counts, real source offsets, stable ordering, R2 reuse after a cold start, locale isolation, concurrent requests, retry, and catalog exhaustion.

## Example chat

```bash
curl -X POST "https://YOUR_WORKER.workers.dev/v1/chat" \
  -H "content-type: application/json" \
  -H "x-api-key: YOUR_APP_API_KEY" \
  -d '{
    "message": "Suggest dinner within my remaining calories",
    "history": [],
    "userContext": {
      "locale": "uk",
      "today": { "remainingCalories": 520, "consumedCalories": 1480 },
      "goals": { "calorieTarget": 2000 }
    }
  }'
```

## Example recipes search

```bash
curl "https://YOUR_WORKER.workers.dev/v1/spoonacular/recipes/search?query=chicken&number=5" \
  -H "x-api-key: YOUR_APP_API_KEY"
```

Готовий бульйон класифікується як рецепт, зокрема порції в мл. Пошук його фото не переходить до інгредієнтів чи продуктів Spoonacular; кубики, порошки та концентрати відсіюються. Явні запити на кубик/порошок залишаються продуктами. Для бульйону використовується окремий ключ фото `broth-v2` і URL-параметр `v=broth-2`, щоб не повторно використовувати старе фото концентрату.


## Shared food search (revision 117)

The diary entry point is now “Add food” with All / Products / Meals, using the existing iOS search rows, section cards and recipe segment component. All shows up to two local recent entries, two prepared meals and two products. Products keeps the seven grocery categories; Meals shows only recent recipes and prepared meals. Search results respond to the selected scope. Re-adding a recent entry retains its photo and food kind and uses the current meal and date.

The aggregate sections use `GET /v1/food/search/catalog/preparedMeals?offset=0&limit=2` and the same route with `products` instead of `preparedMeals`. Prepared meals use stored recipe sections first, then Spoonacular recipe search; products reuse the stored grocery catalog with categories interleaved, then ingredient search. Existing food source, kind and numeric serving metadata are retained. Stored bilingual product titles are reused without AI translation when available; captions use numeric portions instead of English serving prose. These sections share the existing page cache, locale validation and pagination: opening More requests 20 items, reuses the two preview translations, and only localizes additional items in that page. No hidden category preload is started by the All screen.

Publish worker revision 117 and install the updated iOS build together. This change has only been validated locally until publication.


## Prepared meals recovery (revision 118)

Production revision 117 returned HTTP 200 for the English prepared-meal preview and HTTP 503 for Ukrainian. Its lookup only read `recipe-sections/v10/en-US.json`, which was absent, while a populated Ukrainian catalog existed at `recipe-sections/v10/uk-UA.json`.

Prepared meals now use the recipe catalog's shared locale normalization and read existing native-language titles before requesting AI translation. English storage supports both `en` and `en-US`. Titles are matched to recipes by source ID, including when another language seeded the canonical catalog first. Prepared-meal raw/page caches use the new `preparedMeals-v2` suffix so revision 117's fallback list cannot hide the corrected storage path; product caches remain intact. Original Spoonacular titles retain their full translation context.

If a title still cannot be localized, already-localized entries in that page remain usable and the pagination cursor advances by the number of source entries inspected. An entirely unavailable page remains retryable. The iOS retry card now has a 16-point adaptive bottom inset and a 24-point top inset.

Validation includes a replay using the actual Ukrainian R2 payload with all external network calls disabled: preview 200 with two ready recipes; More and the next page 200 with ready translations and correct cursors. Revision 118 requires publishing `worker.js`; the inset requires an updated iOS build.

## First-load recovery (revision 119)

The iOS catalog service now retries temporary network errors, HTTP 408/425/429 and 5xx responses automatically, keeping the existing loading state during recovery. There are at most three requests with a 45-second overall budget and at most 20 seconds per request. Cancellation stops recovery; permanent HTTP failures are not retried. Invalid success payloads are not treated as empty catalogs.

Validated successful pages are stored in URLCache under the exact request URL, including locale, section, offset and limit. Fresh responses are reused for up to ten minutes subject to the server cache directives. After temporary refresh failures, a previously successful page up to one day old can be reused unless revalidation is required. Error responses are not cached.

Food-catalog R2 reads retry one thrown storage error after 120 ms. A repeated storage failure propagates as a retryable response instead of being mistaken for an absent catalog and seeding fallback data. Actual missing objects still follow the existing fallback path immediately.

Production was running revision 118 during diagnosis and returned Ukrainian prepared-meal previews successfully; the reported first failure was not reproduced. Local coverage verifies first-request failure followed by automatic recovery, successful-page reuse, bounded failures, permanent errors, cancellation and cold R2 recovery. Results: 63 iOS food-search tests and 49 worker tests passed. Publish revision 119 and install the updated iOS build to apply this follow-up.

## Bity AI chat fix (revision 120)

Replace the entire `worker.js` in the existing Cloudflare `assistant` Worker and click Deploy. Existing secrets and bindings stay configured. Copying `worker.js` alone enables the chat default `gpt-6-astra`; `OPENAI_MODEL` continues to control other workloads. If `OPENAI_CHAT_MODEL` is already configured, set it to `gpt-6-astra` or remove that override. `/health` should show `workerRev: 120` and `chatModel: "gpt-6-astra"`.

Chat no longer treats short phrases such as «Ідеї страв» as literal catalog searches. The model receives conversation history, user context, and the optional category hint (`nutrition`, `mealSuggestions`, `foodSwap`). It returns existing structured cards for actionable requests and asks a focused question when the food or action is unclear. Food search endpoints remain separate. Empty/incomplete model output returns an error instead of a blank successful reply. Recipe photo loading remains asynchronous.

Rebuild iOS for category hints, card context in followups, the retry error for empty replies, and the check that Meal Logged only appears after a successful diary save. The server routing fix also works with older builds that omit `intent`.

Verification: `npm test` covers mocked OpenAI responses and routing. Model quality, real latency, and account access to Astra still need a live check after deployment. Try «Ідеї страв», «Чим замінити майонез?», «Я з’їла 300 г борщу», and «Додай це» in a fresh conversation; the last should ask a question, not invent a logged meal.

## Edit Meal catalog lookup (revision 122)

Concrete food-log and replacement proposals now resolve each requested food through the shared Spoonacular ingredient, product and recipe search before returning to iOS. Exact names rank first; generic requests retain their requested names. A compatible match supplies catalog nutrition scaled to the requested portion, its image, source, kind and catalogExternalId. A missing match or incompatible portion unit retains the estimate and requested portion without claiming catalog provenance. Cups and grams are not treated as milliliters.

iOS sends userContext.mealEditing with the selected mealType and entryIDs. The editor displays clarification/error messages, applies only explicit food logs and replacements, and rejects replacement targets outside this meal or ambiguous names. Meal and swap suggestions no longer automatically modify the diary.

Validation on 2026-09-14: all 89 worker tests passed, including 14 route tests for catalog lookup; 23 EditMealInteractionTests and 34 AIAssistantChatTests passed. Live production revision 121 returned a weight clarification for «Яблуко», and its Spoonacular proxy returned the exact ingredient «яблуко», ID 9003. This confirms the available catalog entry and previously hidden clarification, not the new server behavior in production.

Publish worker.js revision 122 to the existing assistant Worker with existing secrets and bindings preserved, and rebuild iOS. Publication was not performed: Wrangler is not logged in. The new model prompt and full upstream behavior still require a live check after publication.

## Multiple meal cards (revision 121)

Replace `worker.js` in Cloudflare and Deploy. `/health` should report `workerRev: 121`. Explicit requests such as «додай мені на сьогодні страви для сніданку, обіду, перекусів, вечері» now request one card for every named meal, ordered breakfast → lunch → snacks → dinner. Explicit meal lists take priority over time and previously logged meals. General multi-option responses are no longer truncated to one card.

Each plan option must provide its own `mealType`. Missing or duplicated meals trigger at most one corrective model request; a second incomplete plan returns a retry error rather than a partial success. Ambiguous requests can still return a clarifying question. Rebuild iOS for visible meal labels and meal-specific logging, including recipes with identical names in different meal slots. Cloudflare publishing is performed manually by the user.
