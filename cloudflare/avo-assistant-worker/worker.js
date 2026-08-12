/**
 * Avo AI — Cloudflare Worker (Variant A)
 * Chat Completions + tools + system instructions
 *
 * Secrets:
 * - OPENAI_API_KEY   (secret)
 * - APP_API_KEY      (secret, optional)
 *
 * Vars (optional):
 * - OPENAI_MODEL     default: gpt-5.6-luna
 *
 * Endpoints:
 * - GET  /health
 * - POST /v1/chat
 *
 * Body example:
 * {
 *   "message": "Suggest dinner within my remaining calories",
 *   "history": [{ "role": "user", "content": "Hi" }, { "role": "assistant", "content": "Hello!" }],
 *   "userContext": { "today": { "remainingCalories": 520 } },
 *   "imageBase64": null,
 *   "imageMimeType": "image/jpeg"
 * }
 */

const OPENAI_BASE = "https://api.openai.com/v1";
const DEFAULT_MODEL = "gpt-5.6-luna";
const DEFAULT_TRANSCRIBE_MODEL = "gpt-4o-mini-transcribe";

const SYSTEM_INSTRUCTIONS = `You are Avo AI Nutrition Advisor inside the Avo iOS calorie tracker.

============================================================
ROLE
============================================================
- Help users with nutrition Q&A, meal suggestions within remaining calories, food swaps, recipe ideas, food photo analysis, and food-logging proposals.
- Be concise, practical, and friendly.
- You are NOT a doctor or medical professional. Do not diagnose disease or prescribe treatment.
- If asked for medical advice, give general nutrition information and recommend consulting a professional.

============================================================
LANGUAGE
============================================================
- Always reply in the user's language.
- If locale is provided in USER_CONTEXT_JSON, prefer that language.
- Units: prefer grams (g), milliliters (ml), kcal.

============================================================
CONTEXT
============================================================
Every user turn may include a block:
USER_CONTEXT_JSON: { ... }

Use it as source of truth for:
- goals (calorie/macro/water targets)
- today's diary (meals, consumed/remaining calories, macros, water)
- preferences (allergies, dislikes, diet, lose/maintain/gain)
- profile (sex, age, height, weight) when present

Rules:
- Never invent diary entries that are not in context.
- Prefer remaining calories/macros from context over guessing.
- Respect allergies/dislikes strictly in suggestions and swaps.
- If context is missing, ask one short clarifying question OR give a safe general answer.

============================================================
CRITICAL WRITE RULES
============================================================
The mobile app owns all permanent writes to the diary.

You MUST NOT claim that food/water/weight/recipe was saved unless the app already confirmed it.

For actions that change user data, you only PROPOSE structured payloads via tools:
- propose_food_log
- propose_food_replace
- propose_food_swap
- propose_meal_suggestions
- propose_recipe_save
- propose_recipe_ingredient_swap
- propose_water_log
- propose_preference_save

After calling a propose_* tool, also send a short natural-language message that matches the card the UI will show.

Do NOT call propose_* for pure Q&A text answers.

============================================================
CAPABILITIES / INTENTS
============================================================

1) Nutrition Q&A
- Answer food/nutrition questions using context when relevant.
- No tool required unless user asks to log/swap/replace.

2) Log food or drink (text)
- Foods AND caloric drinks/beverages (coffee, latte, juice, soda, beer, wine, milk, tea, smoothies, flavored water with calories, etc.).
- Extract name, portion (g or ml), mealType, estimate nutrition.
- Call propose_food_log (same tool for food and caloric drinks).
- Ask to Confirm & Log / Edit Details in the app.

2b) Log plain water
- Plain water / sparkling water without calories ("випив 250 мл води", "log 2 glasses of water"):
  - Call propose_water_log with amountMilliliters.
  - Do NOT use propose_food_log for plain water.
  - Do NOT claim water is already saved.

3) Log food/drink (photo)
- Identify likely food(s)/drink(s), estimate nutrition, call propose_food_log with confidence.
- If uncertain, lower confidence and suggest Edit Details.

4) Edit / change product
- Call propose_food_replace with target entry id if known from context.

5) Food/drink swaps (STRICT)
- Applies to foods AND drinks (cola→sparkling water, whole milk→skim, juice→infused water, mayo→yogurt, etc.).
- Triggers (always use propose_food_swap, not text-only and not propose_food_log):
  - "alternative to X", "healthier alternative to X", "swap X", "instead of X"
  - Ukrainian: "альтернатива X", "замість X", "здоровіша альтернатива", "чим замінити X"
- Call propose_food_swap once with:
  - original = the food/drink being replaced
  - alternative = best single healthier substitute (comparable portion; use ml for drinks)
  - savingsKcal / macros delta
- Do NOT call propose_food_log for swap requests.
- Do NOT answer swap requests with only a bullet list and no tool.
- Do NOT use propose_food_swap for abstract Q&A ("what is a food swap", "alternative to calories/kJ", "healthier lifestyle", grammar, sleep, etc.) — text only.

6) Meal suggestions within remaining calories
- Call propose_meal_suggestions with 1–3 options that fit remaining budget.
- Options may include drinks when relevant.

7) Recipes
- When user wants to keep a recipe, call propose_recipe_save.
- When USER_CONTEXT_JSON includes a recipe and the user asks to replace/swap an ingredient in that recipe:
  - Call propose_recipe_ingredient_swap (NOT propose_food_replace, NOT propose_food_log).
  - Keep amount/unit comparable; estimate replacement macros and updatedRecipeCalories when possible.

8) Preferences / memory facts
- Call propose_preference_save for durable preferences.

9) Progress / remaining summary
- Use remaining kcal/macros/water from context. Do not fabricate percentages.

INTENT ROUTING (priority)
1) Recipe ingredient replace (recipe present in context) -> propose_recipe_ingredient_swap
2) Plain water intake -> propose_water_log
3) User ate/drank caloric food/drink -> propose_food_log
4) Change existing diary item -> propose_food_replace
5) Ask for alternative/swap of a food OR drink -> propose_food_swap
6) Ask what to eat/drink within remaining calories -> propose_meal_suggestions
7) Save recipe -> propose_recipe_save
8) Durable preference/allergy -> propose_preference_save
9) Otherwise plain Q&A text only

============================================================
MEAL TYPES
============================================================
Use exactly one of: breakfast | lunch | dinner | snacks
If unclear, default to snacks and mention it can be edited.

============================================================
ESTIMATION QUALITY
============================================================
- Be realistic with calories/macros.
- Include confidence 0..1 for photo/uncertain text estimates.
- Never recommend foods that conflict with allergies.

============================================================
OUTPUT STYLE
============================================================
- Short messages.
- Do not mention internal tool names to the user.
- When proposing cards, keep text aligned with UI confirmations.

============================================================
TOOL USAGE POLICY
============================================================
- Use tools whenever the app needs structured data to render cards or prepare writes.
- For plain conversation/Q&A, respond with text only.
- If both explanation and card are needed: call tool(s) + short text.`;

const TOOLS = [
  {
    type: "function",
    function: {
      name: "propose_food_log",
      description: "Propose a food OR drink/beverage diary log for the app confirmation card. Use portionGrams for solids and portionMilliliters for drinks when known. Does not save by itself.",
      parameters: {
        type: "object",
        properties: {
          name: { type: "string" },
          mealType: { type: "string", enum: ["breakfast", "lunch", "dinner", "snacks"] },
          calories: { type: "number" },
          protein: { type: "number" },
          carbs: { type: "number" },
          fats: { type: "number" },
          fiber: { type: "number" },
          sugar: { type: "number" },
          sodium: { type: "number" },
          portionGrams: { type: "number" },
          portionMilliliters: { type: "number" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          notes: { type: "string" },
          source: { type: "string", enum: ["text", "photo", "voice", "suggestion", "swap"] },
        },
        required: ["name", "mealType", "calories", "protein", "carbs", "fats", "confidence", "source"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "propose_food_replace",
      description: "Propose replacing an existing diary food entry. Does not save by itself.",
      parameters: {
        type: "object",
        properties: {
          targetEntryId: { type: "string" },
          targetName: { type: "string" },
          targetMealType: { type: "string", enum: ["breakfast", "lunch", "dinner", "snacks"] },
          newItem: {
            type: "object",
            properties: {
              name: { type: "string" },
              mealType: { type: "string", enum: ["breakfast", "lunch", "dinner", "snacks"] },
              calories: { type: "number" },
              protein: { type: "number" },
              carbs: { type: "number" },
              fats: { type: "number" },
              portionGrams: { type: "number" },
            },
            required: ["name", "mealType", "calories", "protein", "carbs", "fats"],
          },
          reason: { type: "string" },
        },
        required: ["newItem"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "propose_food_swap",
      description: "Required whenever the user asks for a healthier alternative/swap for a food OR drink (e.g. mayo, cola, juice). Returns an original vs alternative card. Do not use for abstract definitions or non-food topics. Do not use propose_food_log for this intent.",
      parameters: {
        type: "object",
        properties: {
          original: {
            type: "object",
            properties: {
              name: { type: "string" },
              calories: { type: "number" },
              protein: { type: "number" },
              carbs: { type: "number" },
              fats: { type: "number" },
              portionLabel: { type: "string" },
            },
            required: ["name", "calories"],
          },
          alternative: {
            type: "object",
            properties: {
              name: { type: "string" },
              calories: { type: "number" },
              protein: { type: "number" },
              carbs: { type: "number" },
              fats: { type: "number" },
              portionLabel: { type: "string" },
            },
            required: ["name", "calories"],
          },
          savingsKcal: { type: "number" },
          savingsNote: { type: "string" },
          applyToEntryId: { type: "string" },
        },
        required: ["original", "alternative", "savingsKcal"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "propose_meal_suggestions",
      description: "Propose 1-3 meal/recipe suggestion cards within remaining budget.",
      parameters: {
        type: "object",
        properties: {
          mealType: { type: "string", enum: ["breakfast", "lunch", "dinner", "snacks"] },
          remainingCaloriesTarget: { type: "number" },
          options: {
            type: "array",
            minItems: 1,
            maxItems: 3,
            items: {
              type: "object",
              properties: {
                title: { type: "string" },
                summary: { type: "string" },
                calories: { type: "number" },
                protein: { type: "number" },
                carbs: { type: "number" },
                fats: { type: "number" },
                cookTimeMinutes: { type: "number" },
                externalRecipeId: { type: "string" },
                ingredients: { type: "array", items: { type: "string" } },
              },
              required: ["title", "summary", "calories", "protein", "carbs", "fats"],
            },
          },
        },
        required: ["mealType", "options"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "propose_recipe_save",
      description: "Propose saving a recipe locally in the app.",
      parameters: {
        type: "object",
        properties: {
          title: { type: "string" },
          summary: { type: "string" },
          calories: { type: "number" },
          protein: { type: "number" },
          carbs: { type: "number" },
          fats: { type: "number" },
          cookTimeMinutes: { type: "number" },
          externalRecipeId: { type: "string" },
          ingredients: { type: "array", items: { type: "string" } },
          steps: { type: "array", items: { type: "string" } },
        },
        required: ["title", "calories", "protein", "carbs", "fats"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "propose_recipe_ingredient_swap",
      description:
        "Propose replacing one ingredient inside the recipe from USER_CONTEXT_JSON.recipe. Use for recipe editing only, not diary food replace.",
      parameters: {
        type: "object",
        properties: {
          recipeExternalId: { type: "string" },
          originalIngredient: {
            type: "object",
            properties: {
              name: { type: "string" },
              amount: { type: "number" },
              unit: { type: "string" },
            },
            required: ["name"],
          },
          replacement: {
            type: "object",
            properties: {
              name: { type: "string" },
              amount: { type: "number" },
              unit: { type: "string" },
              calories: { type: "number" },
              protein: { type: "number" },
              carbs: { type: "number" },
              fats: { type: "number" },
            },
            required: ["name"],
          },
          updatedRecipeCalories: { type: "number" },
          updatedRecipeProtein: { type: "number" },
          updatedRecipeCarbs: { type: "number" },
          updatedRecipeFats: { type: "number" },
          reason: { type: "string" },
        },
        required: ["originalIngredient", "replacement"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "propose_water_log",
      description:
        "Propose logging plain water intake in milliliters. Use for water/sparkling water without calories. Do not use for coffee/juice/soda/milk or other caloric drinks.",
      parameters: {
        type: "object",
        properties: {
          amountMilliliters: { type: "number" },
          note: { type: "string" },
        },
        required: ["amountMilliliters"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "propose_preference_save",
      description: "Propose saving a durable user preference/memory fact.",
      parameters: {
        type: "object",
        properties: {
          kind: {
            type: "string",
            enum: ["allergy", "dislike", "like", "diet", "goal_type", "other"],
          },
          value: { type: "string" },
          note: { type: "string" },
        },
        required: ["kind", "value"],
      },
    },
  },
];

const SPOONACULAR_BASE = "https://api.spoonacular.com";

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return cors(new Response(null, { status: 204 }));
    }

    try {
      if (!isAuthorized(request, env)) {
        return cors(json({ error: "Unauthorized" }, 401));
      }

      const url = new URL(request.url);
      const model = env.OPENAI_MODEL || DEFAULT_MODEL;

      if (request.method === "GET" && url.pathname === "/health") {
        return cors(
          json({
            ok: true,
            mode: "completions",
            model,
            workerRev: 9,
            spoonacular: Boolean(env.SPOONACULAR_API_KEY),
          })
        );
      }

      if (request.method === "GET" && url.pathname.startsWith("/v1/spoonacular/")) {
        if (!env.SPOONACULAR_API_KEY) {
          return cors(json({ error: "Missing SPOONACULAR_API_KEY" }, 500));
        }
        const result = await handleSpoonacularProxy(url, env.SPOONACULAR_API_KEY);
        return cors(result);
      }

      if (request.method === "POST" && url.pathname === "/v1/chat") {
        if (!env.OPENAI_API_KEY) {
          return cors(json({ error: "Missing OPENAI_API_KEY" }, 500));
        }
        const body = await request.json();
        if (!body?.message || typeof body.message !== "string") {
          return cors(json({ error: "message is required" }, 400));
        }

        const result = await runChatCompletions({
          apiKey: env.OPENAI_API_KEY,
          model,
          message: body.message,
          history: Array.isArray(body.history) ? body.history : [],
          userContext: body.userContext || null,
          imageBase64: normalizeImageBase64(body.imageBase64),
          imageMimeType: body.imageMimeType || "image/jpeg",
        });

        return cors(json(result));
      }

      if (request.method === "POST" && url.pathname === "/v1/food/analyze-photo") {
        if (!env.OPENAI_API_KEY) {
          return cors(json({ error: "Missing OPENAI_API_KEY" }, 500));
        }
        const body = await request.json();
        const imageBase64 = normalizeImageBase64(body?.imageBase64);
        if (!imageBase64) {
          return cors(json({ error: "imageBase64 is required" }, 400));
        }
        if (imageBase64.length > 5_500_000) {
          return cors(json({ error: "image too large; compress before upload" }, 413));
        }

        const mealType = ["breakfast", "lunch", "dinner", "snacks"].includes(body?.mealType)
          ? body.mealType
          : "snacks";
        const note = typeof body?.note === "string" && body.note.trim() ? body.note.trim() : "";
        const message = note
          ? `Analyze this food photo and propose a diary log as ${mealType}. User note: ${note}`
          : `Analyze this food photo and propose a diary log as ${mealType}.`;

        const result = await analyzeFoodPhoto({
          apiKey: env.OPENAI_API_KEY,
          model,
          message,
          userContext: body.userContext || null,
          imageBase64,
          imageMimeType: body.imageMimeType || "image/jpeg",
          mealType,
        });

        return cors(json(result));
      }

      if (request.method === "POST" && url.pathname === "/v1/food/analyze-text") {
        if (!env.OPENAI_API_KEY) {
          return cors(json({ error: "Missing OPENAI_API_KEY" }, 500));
        }
        const body = await request.json();
        const text = typeof body?.text === "string" ? body.text.trim() : "";
        if (!text) {
          return cors(json({ error: "text is required" }, 400));
        }
        if (text.length > 4000) {
          return cors(json({ error: "text too long" }, 413));
        }

        const mealType = ["breakfast", "lunch", "dinner", "snacks"].includes(body?.mealType)
          ? body.mealType
          : "snacks";

        const result = await analyzeFoodText({
          apiKey: env.OPENAI_API_KEY,
          model,
          text,
          userContext: body.userContext || null,
          mealType,
        });

        return cors(json(result));
      }

      if (request.method === "POST" && url.pathname === "/v1/food/transcribe") {
        if (!env.OPENAI_API_KEY) {
          return cors(json({ error: "Missing OPENAI_API_KEY" }, 500));
        }
        const body = await request.json();
        const audioBase64 = normalizeImageBase64(body?.audioBase64);
        if (!audioBase64) {
          return cors(json({ error: "audioBase64 is required" }, 400));
        }
        if (audioBase64.length > 8_000_000) {
          return cors(json({ error: "audio too large; keep clip under ~30s" }, 413));
        }

        const transcription = await transcribeAudio({
          apiKey: env.OPENAI_API_KEY,
          model: env.OPENAI_TRANSCRIBE_MODEL || DEFAULT_TRANSCRIBE_MODEL,
          audioBase64,
          audioMimeType: body.audioMimeType || "audio/m4a",
        });

        return cors(
          json({
            mode: "transcription",
            model: env.OPENAI_TRANSCRIBE_MODEL || DEFAULT_TRANSCRIBE_MODEL,
            text: transcription.text,
            language: transcription.language || null,
          })
        );
      }

      if (request.method === "POST" && url.pathname === "/v1/food/analyze-voice") {
        if (!env.OPENAI_API_KEY) {
          return cors(json({ error: "Missing OPENAI_API_KEY" }, 500));
        }
        const body = await request.json();
        const audioBase64 = normalizeImageBase64(body?.audioBase64);
        if (!audioBase64) {
          return cors(json({ error: "audioBase64 is required" }, 400));
        }
        if (audioBase64.length > 8_000_000) {
          return cors(json({ error: "audio too large; keep clip under ~30s" }, 413));
        }

        const mealType = ["breakfast", "lunch", "dinner", "snacks"].includes(body?.mealType)
          ? body.mealType
          : "snacks";

        const result = await analyzeFoodVoice({
          apiKey: env.OPENAI_API_KEY,
          model,
          transcribeModel: env.OPENAI_TRANSCRIBE_MODEL || DEFAULT_TRANSCRIBE_MODEL,
          audioBase64,
          audioMimeType: body.audioMimeType || "audio/m4a",
          userContext: body.userContext || null,
          mealType,
        });

        return cors(json(result));
      }

      return cors(json({ error: "Not found" }, 404));
    } catch (error) {
      return cors(json({ error: error?.message || "Unknown error" }, 500));
    }
  },
};

async function handleSpoonacularProxy(url, apiKey) {
  const path = url.pathname;
  const params = url.searchParams;

  let upstreamPath = null;
  const upstream = new URLSearchParams();
  upstream.set("apiKey", apiKey);

  if (path === "/v1/spoonacular/recipes/search") {
    upstreamPath = "/recipes/complexSearch";
    copyParam(params, upstream, "query");
    copyParam(params, upstream, "number", "12");
    copyParam(params, upstream, "maxCalories");
    copyParam(params, upstream, "diet");
    copyParam(params, upstream, "intolerances");
    upstream.set("addRecipeNutrition", "true");
    upstream.set("addRecipeInformation", "true");
  } else if (path.startsWith("/v1/spoonacular/recipes/") && path !== "/v1/spoonacular/recipes/search") {
    const id = path.slice("/v1/spoonacular/recipes/".length).replace(/\/$/, "");
    if (!/^\d+$/.test(id)) {
      return json({ error: "Invalid recipe id" }, 400);
    }
    upstreamPath = `/recipes/${id}/information`;
    upstream.set("includeNutrition", "true");
  } else if (path === "/v1/spoonacular/ingredients/search") {
    upstreamPath = "/food/ingredients/search";
    copyParam(params, upstream, "query");
    copyParam(params, upstream, "number", "12");
    copyParam(params, upstream, "metaInformation", "true");
  } else if (path.startsWith("/v1/spoonacular/ingredients/") && path !== "/v1/spoonacular/ingredients/search") {
    const id = path.slice("/v1/spoonacular/ingredients/".length).replace(/\/$/, "");
    if (!/^\d+$/.test(id)) {
      return json({ error: "Invalid ingredient id" }, 400);
    }
    upstreamPath = `/food/ingredients/${id}/information`;
    copyParam(params, upstream, "amount", "100");
    copyParam(params, upstream, "unit", "grams");
  } else if (path === "/v1/spoonacular/products/search") {
    upstreamPath = "/food/products/search";
    copyParam(params, upstream, "query");
    copyParam(params, upstream, "number", "12");
  } else if (path.startsWith("/v1/spoonacular/products/upc/")) {
    const upc = path.slice("/v1/spoonacular/products/upc/".length).replace(/\/$/, "");
    if (!/^\d{8,14}$/.test(upc)) {
      return json({ error: "Invalid UPC/EAN barcode" }, 400);
    }
    upstreamPath = `/food/products/upc/${upc}`;
  } else {
    return json({ error: "Not found" }, 404);
  }

  if (!params.get("query") && upstreamPath.includes("search") && !upstream.get("query")) {
    return json({ error: "query is required" }, 400);
  }

  const upstreamURL = `${SPOONACULAR_BASE}${upstreamPath}?${upstream.toString()}`;
  const response = await fetch(upstreamURL, {
    method: "GET",
    headers: { Accept: "application/json" },
  });
  const raw = await response.text();
  let data = null;
  try {
    data = raw ? JSON.parse(raw) : null;
  } catch {
    return json({ error: "Invalid Spoonacular response" }, 502);
  }

  if (!response.ok) {
    const message = data?.message || data?.status || `Spoonacular error ${response.status}`;
    return json({ error: message }, response.status === 401 || response.status === 402 ? 502 : response.status);
  }

  return json(data);
}

function copyParam(from, to, key, fallback) {
  const value = from.get(key);
  if (value != null && value !== "") {
    to.set(key, value);
  } else if (fallback !== undefined) {
    to.set(key, fallback);
  }
}

const CONSUMABLE_HINTS = [
  // drinks
  "cola", "колу", "кола", "coca", "пепсі", "pepsi", "soda", "газован",
  "juice", "сік", "соку", "smoothie", "смузі", "shake", "коктейл",
  "coffee", "кава", "каву", "кави", "latte", "лате", "cappuccino", "капучино",
  "tea", "чай", "чаю", "matcha", "матча",
  "milk", "молоко", "молока", "кефір", "kefir", "yogurt drink",
  "beer", "пиво", "пива", "wine", "вино", "вина", "alcohol", "алкогол",
  "water", "вода", "воду", "води", "sparkling",
  "energy drink", "енергетик", "kvass", "квас",
  // foods (common swap targets)
  "mayo", "майонез", "mayonnaise", "bread", "хліб", "рис", "rice",
  "potato", "картопл", "fries", "фрі", "pasta", "паста", "макарон",
  "sugar", "цукор", "butter", "масло", "cheese", "сир", "yogurt", "йогурт",
  "chicken", "курк", "beef", "яловиц", "pork", "свинин", "fish", "риб",
  "pizza", "піц", "burger", "бургер", "chips", "чіпс", "cookie", "печив",
  "candy", "цукерк", "chocolate", "шоколад", "ice cream", "морозив",
  "sauce", "соус", "oil", "олія", "cream", "вершк", "tortilla", "лаваш",
];

function normalizeMessage(message) {
  return String(message || "")
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/\s+/g, " ")
    .trim();
}

function isAbstractOrMetaQuestion(text) {
  const metaPatterns = [
    /що таке/,
    /what is\b/,
    /what does\b/,
    /означає/,
    /поясни концепт/,
    /in english grammar/,
    /grammar/,
    /загалом/,
    /lifestyle/,
    /як жити/,
    /alternative to (calories|калорі|кдж|kj|energy)\b/,
    /альтернатива (калорі|кдж|енерг)/,
    /замість сну/,
    /instead of sleep/,
  ];
  return metaPatterns.some((re) => re.test(text));
}

function hasConsumableHint(text) {
  if (CONSUMABLE_HINTS.some((hint) => text.includes(hint))) return true;
  // "alternative to X" / "замість X" / "чим замінити X" where X looks like a short token
  if (/(?:alternative to|instead of|замість|чим замінити|альтернатива)\s+[\p{L}]{3,}/u.test(text)) {
    const blocked = /(calories|калорі|кдж|kj|sleep|сну|lifestyle|grammar|концепт|слово)/u;
    const m = text.match(/(?:alternative to|instead of|замість|чим замінити|альтернатива)\s+([\p{L}]{3,})/u);
    if (m && !blocked.test(m[1])) return true;
  }
  return false;
}

function looksLikeFoodOrDrinkSwap(text) {
  if (isAbstractOrMetaQuestion(text)) return false;
  if (!hasConsumableHint(text)) return false;

  const swapPatterns = [
    /здоровіш[\p{L}]*\s+альтернатив/u,
    /альтернатив[\p{L}]*\s+.+/u,
    /чим замінити/u,
    /замість\s+[\p{L}]{3,}/u,
    /healthier\s+alternative/i,
    /alternative\s+to\s+[\p{L}]{3,}/iu,
    /instead\s+of\s+[\p{L}]{3,}/iu,
    /\bswap\s+[\p{L}]{3,}/iu,
    /замінити\s+[\p{L}]{3,}/u,
  ];
  return swapPatterns.some((re) => re.test(text));
}

function looksLikeWaterLog(text) {
  if (isAbstractOrMetaQuestion(text)) return false;
  if (/(скільки вод|how much water|скільки.*пити|should i drink|how much.*to drink)/.test(text)) {
    return false;
  }
  if (!/(вод[аиуеюі]?|water|\bh2o\b)/u.test(text)) return false;
  if (/(кав|лат|сік|кол|пив|вин|молок|smoothie|coffee|latte|juice|cola|soda|beer|wine|milk|tea\b)/.test(text)) {
    return false;
  }
  const logCues = /(випив|випила|запиши|додай|залоговуй|\blog\b|\bdrank\b|\badd\b)/;
  const amountCue = /\d+\s*(мл|ml|л|l|склян|glass|cups?)/;
  return logCues.test(text) || amountCue.test(text);
}

function looksLikeFoodOrDrinkLog(text) {
  if (isAbstractOrMetaQuestion(text)) return false;
  if (looksLikeWaterLog(text)) return false;
  const logPatterns = [
    /з['’]?їв/,
    /зїла/,
    /з'їла/,
    /зʼїв/,
    /зʼїла/,
    /випив/,
    /випила/,
    /\bate\b/,
    /\bdrank\b/,
    /\bdrunk\b/,
    /залоговуй/,
    /\blog\b.+\b(food|drink|meal|coffee|cola|juice)/,
    /запиши\s+.+(кав|лат|сік|кол|чай|пив|вин|молоч)/,
  ];
  return logPatterns.some((re) => re.test(text));
}

function looksLikeRecipeIngredientSwap(text, userContext) {
  if (!userContext || !userContext.recipe) return false;
  const patterns = [
    /заміни/,
    /замінити/,
    /замість/,
    /replace/,
    /swap/,
    /instead of/,
  ];
  return patterns.some((re) => re.test(text));
}

function detectForcedToolName(message, userContext, hasImage) {
  const text = normalizeMessage(message);
  if (looksLikeRecipeIngredientSwap(text, userContext)) {
    return "propose_recipe_ingredient_swap";
  }
  if (looksLikeWaterLog(text)) return "propose_water_log";
  if (looksLikeFoodOrDrinkSwap(text)) return "propose_food_swap";
  if (hasImage || looksLikeFoodOrDrinkLog(text)) return "propose_food_log";
  return null;
}

async function runChatCompletions(input) {
  const hasImage = Boolean(input.imageBase64);
  let forcedToolName =
    input.forceToolName || detectForcedToolName(input.message, input.userContext, hasImage);
  const messages = [{ role: "system", content: SYSTEM_INSTRUCTIONS }];

  if (forcedToolName === "propose_recipe_ingredient_swap") {
    messages.push({
      role: "system",
      content:
        "FORCE_TOOL: Recipe context is present and the user wants an ingredient replaced. You MUST call propose_recipe_ingredient_swap exactly once. Do not call propose_food_replace or propose_food_log.",
    });
  } else if (forcedToolName === "propose_water_log") {
    messages.push({
      role: "system",
      content:
        "FORCE_TOOL: This user message is a plain water log request. You MUST call propose_water_log exactly once with amountMilliliters. Do not call propose_food_log. Do not claim it is already saved.",
    });
  } else if (forcedToolName === "propose_food_swap") {
    messages.push({
      role: "system",
      content:
        "FORCE_TOOL: This user message is a food/drink swap request. You MUST call propose_food_swap exactly once with original vs one best alternative (food or beverage). Use comparable portion (g or ml). Do not answer with text-only lists. Do not call propose_food_log.",
    });
  } else if (forcedToolName === "propose_food_log") {
    messages.push({
      role: "system",
      content: hasImage
        ? "FORCE_TOOL: A food photo is attached. Identify the food, estimate portion and nutrition, and MUST call propose_food_log exactly once with source=\"photo\" and a realistic confidence. Do not claim it is already saved."
        : "FORCE_TOOL: This user message is a food/drink log request. You MUST call propose_food_log exactly once. Drinks are valid diary items (prefer ml). Do not claim it is already saved.",
    });
  }

  for (const item of input.history) {
    if (!item || (item.role !== "user" && item.role !== "assistant")) continue;
    if (typeof item.content !== "string" || !item.content.trim()) continue;
    messages.push({ role: item.role, content: item.content });
  }

  const userContent = [];
  if (input.userContext) {
    userContent.push({
      type: "text",
      text: `USER_CONTEXT_JSON:\n${JSON.stringify(input.userContext)}`,
    });
  }
  userContent.push({ type: "text", text: input.message });

  if (input.imageBase64) {
    userContent.push({
      type: "image_url",
      image_url: {
        url: `data:${input.imageMimeType};base64,${input.imageBase64}`,
      },
    });
  }

  messages.push({
    role: "user",
    content: userContent.length === 1 ? input.message : userContent,
  });

  const toolChoice = forcedToolName
    ? { type: "function", function: { name: forcedToolName } }
    : "auto";

  const response = await fetch(`${OPENAI_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${input.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: input.model,
      messages,
      tools: TOOLS,
      tool_choice: toolChoice,
      temperature: 0.4,
      reasoning_effort: "none",
    }),
  });

  const raw = await response.text();
  let data = null;
  try {
    data = raw ? JSON.parse(raw) : null;
  } catch {
    throw new Error(`Invalid OpenAI response: ${raw?.slice(0, 200) || "empty"}`);
  }

  if (!response.ok) {
    throw new Error(data?.error?.message || `OpenAI error ${response.status}`);
  }

  const choice = data?.choices?.[0]?.message || {};
  const toolCalls = Array.isArray(choice.tool_calls)
    ? choice.tool_calls.map((call) => {
        let args = {};
        try {
          args = JSON.parse(call.function?.arguments || "{}");
        } catch {
          args = { rawArguments: call.function?.arguments || "" };
        }
        return {
          id: call.id,
          name: call.function?.name || "",
          arguments: args,
        };
      })
    : [];

  return {
    mode: "completions",
    model: data.model || input.model,
    message: {
      role: "assistant",
      content: choice.content || "",
      toolCalls,
    },
    usage: data.usage || null,
    hasActions: toolCalls.length > 0,
  };
}

function normalizeImageBase64(value) {
  if (typeof value !== "string" || !value.trim()) return null;
  const trimmed = value.trim();
  const marker = "base64,";
  const idx = trimmed.indexOf(marker);
  if (trimmed.startsWith("data:") && idx !== -1) {
    return trimmed.slice(idx + marker.length);
  }
  return trimmed.replace(/\s/g, "");
}

function asNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function extractFoodLogAnalysis(toolCalls, mealTypeFallback, source = "photo") {
  const call = (toolCalls || []).find((item) => item.name === "propose_food_log");
  if (!call || !call.arguments || call.arguments.rawArguments) return null;
  const args = call.arguments;
  const name = typeof args.name === "string" ? args.name.trim() : "";
  if (!name) return null;
  const mealType = ["breakfast", "lunch", "dinner", "snacks"].includes(args.mealType)
    ? args.mealType
    : mealTypeFallback || "snacks";
  return {
    name,
    mealType,
    calories: Math.max(0, asNumber(args.calories)),
    protein: Math.max(0, asNumber(args.protein)),
    carbs: Math.max(0, asNumber(args.carbs)),
    fats: Math.max(0, asNumber(args.fats)),
    fiber: Math.max(0, asNumber(args.fiber)),
    sugar: Math.max(0, asNumber(args.sugar)),
    sodium: Math.max(0, asNumber(args.sodium)),
    portionGrams: args.portionGrams == null ? null : Math.max(0, asNumber(args.portionGrams)),
    portionMilliliters:
      args.portionMilliliters == null ? null : Math.max(0, asNumber(args.portionMilliliters)),
    confidence: Math.min(1, Math.max(0, asNumber(args.confidence, 0.5))),
    notes: typeof args.notes === "string" ? args.notes : "",
    source,
  };
}

async function analyzeForcedFoodLog(input) {
  const source = input.source || "photo";
  const first = await runChatCompletions({
    apiKey: input.apiKey,
    model: input.model,
    message: input.message,
    history: [],
    userContext: input.userContext,
    imageBase64: input.imageBase64 || null,
    imageMimeType: input.imageMimeType || "image/jpeg",
    forceToolName: "propose_food_log",
  });

  let analysis = extractFoodLogAnalysis(first.message?.toolCalls, input.mealType, source);
  let used = first;

  if (!analysis) {
    const retry = await runChatCompletions({
      apiKey: input.apiKey,
      model: input.model,
      message:
        input.message +
        ` Return propose_food_log now with name, mealType, calories, protein, carbs, fats, confidence, source=${source}.`,
      history: [],
      userContext: input.userContext,
      imageBase64: input.imageBase64 || null,
      imageMimeType: input.imageMimeType || "image/jpeg",
      forceToolName: "propose_food_log",
    });
    analysis = extractFoodLogAnalysis(retry.message?.toolCalls, input.mealType, source);
    used = retry;
  }

  if (!analysis) {
    throw new Error(
      source === "text"
        ? "Food text analysis failed: no structured food estimate"
        : "Food photo analysis failed: no structured food estimate"
    );
  }

  return {
    mode: source === "text" ? "text_analysis" : "photo_analysis",
    model: used.model,
    analysis,
    message: used.message?.content || "",
    usage: used.usage || null,
    hasActions: true,
  };
}

async function analyzeFoodPhoto(input) {
  return analyzeForcedFoodLog({
    ...input,
    source: "photo",
  });
}

async function analyzeFoodText(input) {
  const message =
    `Parse this free-text food description into one diary food log as ${input.mealType}. ` +
    `Extract dish/product name, portion size, meal cues, and estimate calories/macros. ` +
    `If the user mentions multiple items, combine into one sensible log entry with notes. ` +
    `User text: ${input.text}`;

  return analyzeForcedFoodLog({
    apiKey: input.apiKey,
    model: input.model,
    message,
    userContext: input.userContext,
    mealType: input.mealType,
    source: "text",
  });
}

async function transcribeAudio(input) {
  const audioBase64 = normalizeImageBase64(input.audioBase64);
  if (!audioBase64) {
    throw new Error("audioBase64 is required");
  }

  let bytes;
  try {
    const binary = atob(audioBase64);
    bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
  } catch {
    throw new Error("Invalid audioBase64");
  }

  if (bytes.length < 64) {
    throw new Error("Audio clip is empty");
  }

  const mime = typeof input.audioMimeType === "string" && input.audioMimeType.trim()
    ? input.audioMimeType.trim()
    : "audio/m4a";
  const ext = mime.includes("wav")
    ? "wav"
    : mime.includes("mp3") || mime.includes("mpeg")
      ? "mp3"
      : mime.includes("webm")
        ? "webm"
        : "m4a";

  const form = new FormData();
  form.append("file", new Blob([bytes], { type: mime }), `voice.${ext}`);
  form.append("model", input.model || DEFAULT_TRANSCRIBE_MODEL);
  form.append("response_format", "json");

  const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${input.apiKey}`,
    },
    body: form,
  });

  const raw = await response.text();
  let data = null;
  try {
    data = raw ? JSON.parse(raw) : null;
  } catch {
    throw new Error("Invalid transcription response");
  }

  if (!response.ok) {
    throw new Error(data?.error?.message || `Transcription failed (${response.status})`);
  }

  const text = typeof data?.text === "string" ? data.text.trim() : "";
  if (!text) {
    throw new Error("Transcription returned empty text");
  }

  return {
    text,
    language: typeof data?.language === "string" ? data.language : null,
  };
}

async function analyzeFoodVoice(input) {
  const transcription = await transcribeAudio({
    apiKey: input.apiKey,
    model: input.transcribeModel,
    audioBase64: input.audioBase64,
    audioMimeType: input.audioMimeType,
  });

  const analysisResult = await analyzeForcedFoodLog({
    apiKey: input.apiKey,
    model: input.model,
    message:
      `Parse this voice transcription of a food description into one diary food log as ${input.mealType}. ` +
      `Extract dish/product name, portion size, meal cues, and estimate calories/macros. ` +
      `If the user mentions multiple items, combine into one sensible log entry with notes. ` +
      `User transcription: ${transcription.text}`,
    userContext: input.userContext,
    mealType: input.mealType,
    source: "voice",
  });

  return {
    ...analysisResult,
    mode: "voice_analysis",
    transcription: transcription.text,
    transcriptionLanguage: transcription.language,
    transcribeModel: input.transcribeModel || DEFAULT_TRANSCRIBE_MODEL,
  };
}

function isAuthorized(request, env) {
  if (!env.APP_API_KEY) return true;
  const auth = request.headers.get("authorization") || "";
  const bearer = auth.toLowerCase().startsWith("bearer ") ? auth.slice(7).trim() : "";
  const apiKey = request.headers.get("x-api-key") || "";
  return bearer === env.APP_API_KEY || apiKey === env.APP_API_KEY;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function cors(response) {
  const headers = new Headers(response.headers);
  headers.set("access-control-allow-origin", "*");
  headers.set("access-control-allow-methods", "GET,POST,OPTIONS");
  headers.set("access-control-allow-headers", "content-type,authorization,x-api-key");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
