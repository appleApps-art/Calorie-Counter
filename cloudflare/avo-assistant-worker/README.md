# Avo AI Worker — Variant A (Chat Completions + Spoonacular proxy)

Production endpoint: `https://assistant.chatte.workers.dev`

Copy-paste file: `worker.js`

## Secrets / vars in Cloudflare
- `OPENAI_API_KEY` (secret) — required for `POST /v1/chat`
- `SPOONACULAR_API_KEY` (secret) — required for `/v1/spoonacular/*`
- `APP_API_KEY` (secret) — optional
- `OPENAI_MODEL` (var) — optional, default `gpt-5.6-luna`
- `OPENAI_TRANSCRIBE_MODEL` (var) — optional, default `gpt-4o-mini-transcribe`

## Endpoints
- `GET /health`
- `POST /v1/chat` — OpenAI chat + `propose_*` tools
- `POST /v1/food/analyze-photo` — food photo → structured nutrition estimate (`propose_food_log`)
- `POST /v1/food/analyze-text` — free-text food description → structured nutrition estimate (`propose_food_log`)
- `POST /v1/food/transcribe` — voice audio → text (auto language)
- `POST /v1/food/analyze-voice` — voice audio → transcription + structured nutrition estimate
- `GET /v1/spoonacular/recipes/search?query=`
- `GET /v1/spoonacular/recipes/:id`
- `GET /v1/spoonacular/ingredients/search?query=`
- `GET /v1/spoonacular/ingredients/:id?amount=&unit=`
- `GET /v1/spoonacular/products/search?query=`
- `GET /v1/spoonacular/products/upc/:barcode`

## Chat flow
1. iOS → `POST /v1/chat` (message + userContext + history + optional photo)
2. Worker → OpenAI `/v1/chat/completions` (system instructions + tools)
3. Якщо є `toolCalls` (`propose_*`) → апка показує картки і пише дані лише після Confirm
4. Якщо лише text → звичайна відповідь в чат

Tools include `propose_water_log` for plain water (ml). Caloric drinks still use `propose_food_log`.

## Spoonacular flow
1. iOS → `GET /v1/spoonacular/...` (без Spoonacular key в апці)
2. Worker додає `SPOONACULAR_API_KEY` і проксує allowlisted upstream

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
