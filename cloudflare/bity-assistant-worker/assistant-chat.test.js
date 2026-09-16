import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("./worker.js", import.meta.url), "utf8")
  .replace("export default {", "const worker = {")
  .replaceAll("export class ", "class ");

function runtime(...responses) {
  const requests = [];
  const env = { OPENAI_API_KEY: "test-only-key", OPENAI_MODEL: "gpt-5.6-luna" };
  const context = vm.createContext({
    URL, Request, Response, Headers, TextEncoder, TextDecoder, AbortSignal,
    setTimeout, clearTimeout,
    fetch: async (url, init) => {
      assert.equal(String(url), "https://api.openai.com/v1/responses");
      assert.equal(init.method, "POST");
      requests.push(JSON.parse(init.body));
      assert.ok(responses.length, "Unexpected extra OpenAI request");
      return Response.json(responses.shift());
    },
  });
  vm.runInContext(source + `
    globalThis.worker = worker;
    searchDishAllSources = async () => {
      throw new Error("Chat must not search the literal conversation in the food catalog");
    };
    // Image persistence has its own integration tests; do not let photo lookup
    // hide a missing chat function call or add external requests in these tests.
    enrichAssistantImages = async (env, ctx, origin, calls) => calls;
  `, context);
  return {
    requests,
    useEmptyRecipeSearch() {
      vm.runInContext("executeSearchRecipes = async () => ({ recipes: [], empty: true });", context);
    },
    async health() {
      const response = await context.worker.fetch(new Request("https://assistant.example.test/health"), env, {});
      return { status: response.status, body: await response.json() };
    },
    async chat(body) {
      const response = await context.worker.fetch(new Request("https://assistant.example.test/v1/chat", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      }), env, {});
      return { status: response.status, body: await response.json() };
    },
  };
}

function completion(...output) {
  return { status: "completed", model: "gpt-6-astra", output };
}

function action(name, args, id = "call-card") {
  return {
    type: "function_call", id: "fc-card", call_id: id, name,
    arguments: JSON.stringify(args), status: "completed",
  };
}

function textMessage(text) {
  return { type: "message", role: "assistant", content: [{ type: "output_text", text }] };
}

const meal = {
  mealType: "dinner",
  options: [{
    title: "Гречка з грибами", summary: "Проста вечеря з овочами.",
    calories: 410, protein: 16, carbs: 62, fats: 12, cookTimeMinutes: 20,
    ingredients: ["Гречка — 70 г", "Гриби — 150 г"],
    steps: ["Відваріть гречку та додайте обсмажені гриби."],
  }],
};

const swap = {
  original: { name: "Майонез", calories: 136, portionLabel: "20 г" },
  alternative: { name: "Грецький йогурт", calories: 15, portionLabel: "20 г" },
  savingsKcal: 121,
};

const log = {
  name: "Борщ", mealType: "lunch", calories: 210, protein: 12, carbs: 24, fats: 8,
  confidence: 0.8, source: "text", kind: "recipe", portionGrams: 300,
  ingredients: [{ name: "Буряк", grams: 60 }], steps: ["Зваріть овочі в бульйоні."],
};

test("health reports Astra as the chat default independently of the existing Luna model setting", async () => {
  const app = runtime();
  const result = await app.health();
  assert.equal(result.status, 200);
  assert.equal(result.body.model, "gpt-5.6-luna");
  assert.equal(result.body.chatModel, "gpt-6-astra");
  assert.equal(app.requests.length, 0);
});

test("the Ukrainian meal-ideas category reaches AI and returns a meal card without catalog search", async () => {
  const app = runtime(completion(action("propose_meal_suggestions", meal)));
  const result = await app.chat({ message: "Ідеї страв", intent: "mealSuggestions" });
  assert.equal(result.status, 200);
  assert.equal(app.requests.length, 1);
  assert.equal(app.requests[0].model, "gpt-6-astra");
  assert.equal(result.body.hasActions, true);
  assert.equal(result.body.message.toolCalls.length, 1);
  const card = result.body.message.toolCalls[0];
  assert.equal(card.id, "call-card");
  assert.equal(card.name, "propose_meal_suggestions");
  assert.equal(card.arguments.mealType, "dinner");
  assert.equal(card.arguments.options.length, 1);
  assert.equal(card.arguments.options[0].title, meal.options[0].title);
  assert.equal(card.arguments.options[0].calories, 410);
  assert.deepEqual(card.arguments.options[0].steps, meal.options[0].steps);
});

for (const [name, message, args] of [
  ["propose_food_swap", "Чим замінити майонез?", swap],
  ["propose_food_log", "Я з’їла 300 г борщу", log],
]) {
  test(`${name} survives the Responses adapter when the model returns no text`, async () => {
    const app = runtime(completion(action(name, args)));
    const result = await app.chat({ message });
    assert.equal(result.status, 200);
    assert.equal(app.requests.length, 1);
    assert.equal(result.body.hasActions, true);
    assert.equal(result.body.message.content, "");
    assert.deepEqual(result.body.message.toolCalls, [{ id: "call-card", name, arguments: args }]);
  });
}

for (const [message, intent, question] of [
  ["Додай це", undefined, "Яку страву та порцію додати?"],
  ["Заміна продуктів", "foodSwap", "Для якого продукту знайти заміну?"],
]) {
  test(`ambiguous request “${message}” permits a clarification instead of forcing a card`, async () => {
    const app = runtime(completion(textMessage(question)));
    const result = await app.chat({ message, intent });
    assert.equal(result.status, 200);
    assert.equal(app.requests.length, 1);
    assert.equal(app.requests[0].tool_choice, "auto");
    assert.equal(result.body.hasActions, false);
    assert.equal(result.body.message.content, question);
    assert.deepEqual(result.body.message.toolCalls, []);
  });
}

test("category, conversation history, and dietary context reach the semantic model together", async () => {
  const app = runtime(completion(action("propose_food_swap", swap)));
  const history = [
    { role: "user", content: "Я часто додаю майонез." },
    { role: "assistant", content: "Хочете знайти для нього заміну?" },
  ];
  const userContext = {
    locale: "uk_UA", preferences: { allergies: ["горіхи"], diet: "vegetarian" },
    today: { remainingCalories: 520 },
  };
  const result = await app.chat({ message: "Так", intent: "foodSwap", history, userContext });
  assert.equal(result.status, 200);
  const request = app.requests[0];
  assert.match(request.instructions, /Selected chat category: foodSwap/);
  assert.deepEqual(request.input.slice(0, 2), history);
  assert.equal(request.input[2].role, "user");
  assert.deepEqual(request.input[2].content, [
    { type: "input_text", text: `USER_CONTEXT_JSON:\n${JSON.stringify(userContext)}` },
    { type: "input_text", text: "Так" },
  ]);
});

test("recipe-search continuation replays encrypted reasoning and its function call once before the tool result", async () => {
  const reasoning = {
    type: "reasoning", id: "rs-search", summary: [], encrypted_content: "opaque-test-state",
  };
  const search = action("search_recipes", { query: "buckwheat mushrooms", number: 1 }, "call-search");
  const app = runtime(
    completion(reasoning, search),
    completion(action("propose_meal_suggestions", meal)),
  );
  app.useEmptyRecipeSearch();
  const result = await app.chat({ message: "Знайди рецепт гречки з грибами", intent: "mealSuggestions" });
  assert.equal(result.status, 200);
  assert.equal(app.requests.length, 2);
  assert.deepEqual(app.requests[1].input.slice(1), [
    reasoning,
    search,
    { type: "function_call_output", call_id: "call-search", output: JSON.stringify({ recipes: [], empty: true }) },
  ]);
  assert.equal(app.requests[1].input.filter((item) => item.type === "function_call").length, 1);
  assert.deepEqual(app.requests[1].tool_choice, { type: "function", name: "propose_meal_suggestions" });
  assert.equal(result.body.message.toolCalls[0].name, "propose_meal_suggestions");
  assert.equal(result.body.message.toolCalls[0].arguments.options[0].title, meal.options[0].title);
});

test("unknown category values cannot become model instructions", async () => {
  const app = runtime(completion(textMessage("Що вас цікавить?")));
  const result = await app.chat({ message: "Привіт", intent: "unrecognized-intent-sentinel" });
  assert.equal(result.status, 200);
  assert.doesNotMatch(app.requests[0].instructions, /unrecognized-intent-sentinel|Selected chat category:/);
});

test("Responses tool schemas retain optional card fields and permit text clarification", async () => {
  const app = runtime(completion(textMessage("Для якого продукту знайти заміну?")));
  assert.equal((await app.chat({ message: "Заміна продуктів", intent: "foodSwap" })).status, 200);
  const request = app.requests[0];
  assert.equal(request.tool_choice, "auto");
  assert.ok(request.tools.length > 0);
  assert.ok(request.tools.every((tool) => tool.type === "function" && tool.strict === false));
  const recipe = request.tools.find((tool) => tool.name === "propose_meal_suggestions");
  const option = recipe.parameters.properties.options.items;
  assert.ok(!option.required.includes("imageURL"));
  assert.ok(!option.required.includes("externalRecipeId"));
});

for (const [label, response] of [
  ["empty completed output", completion()],
  ["reasoning without an answer", completion({ type: "reasoning", summary: [] })],
  ["incomplete output with a partial card", {
    status: "incomplete", incomplete_details: { reason: "max_output_tokens" },
    output: [action("propose_food_log", log)],
  }],
]) {
  test(`${label} returns a retryable error instead of an empty successful chat message`, async () => {
    const app = runtime(response);
    const result = await app.chat({ message: "Ідеї страв", intent: "mealSuggestions" });
    assert.ok(result.status >= 500);
    assert.equal(app.requests.length, 1);
    assert.equal(typeof result.body.error, "string");
    assert.ok(result.body.error.trim());
    assert.equal(result.body.message, undefined);
  });
}

test("a Responses refusal is preserved as visible assistant text", async () => {
  const refusal = "Не можу допомогти з цим запитом.";
  const app = runtime(completion({
    type: "message", role: "assistant", content: [{ type: "refusal", refusal }],
  }));
  const result = await app.chat({ message: "Питання про харчування" });
  assert.equal(result.status, 200);
  assert.equal(result.body.message.content, refusal);
  assert.equal(result.body.hasActions, false);
});

const allMealTypes = ["breakfast", "lunch", "snacks", "dinner"];
const fullDayRequest = "Додай мені на сьогодні страви для сніданку, обіду, перекусів, вечері";
const eveningContext = {
  locale: "uk_UA", timezone: "Europe/Uzhgorod",
  today: { localHour: 21, remainingCalories: 700, meals: [{ mealType: "breakfast", name: "Каша" }] },
};

function plan(types) {
  return {
    mealType: types[0],
    options: types.map((mealType, index) => ({
      ...meal.options[0], mealType, title: `${mealType} — страва ${index + 1}`,
    })),
  };
}

function returnedPlan(result) {
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.hasActions, true);
  assert.equal(result.body.message.toolCalls.length, 1);
  assert.equal(result.body.message.toolCalls[0].name, "propose_meal_suggestions");
  return result.body.message.toolCalls[0].arguments.options;
}

test("an explicit four-meal day keeps all requested meals in canonical order even after breakfast and late at night", async () => {
  const app = runtime(completion(action("propose_meal_suggestions", plan(["dinner", "snacks", "lunch", "breakfast"]))));
  const result = await app.chat({ message: fullDayRequest, intent: "mealSuggestions", userContext: eveningContext });
  assert.deepEqual(returnedPlan(result).map((option) => option.mealType), allMealTypes);
  assert.equal(app.requests.length, 1);
  assert.equal(app.requests[0].tool_choice, "auto");
  assert.match(app.requests[0].instructions, /exactly 4 options/);
  assert.match(app.requests[0].instructions, /breakfast, lunch, snacks, dinner/);
});

test("an explicit lunch-and-dinner subset returns exactly the requested two meals", async () => {
  const app = runtime(completion(action("propose_meal_suggestions", plan(["dinner", "lunch"]))));
  const result = await app.chat({
    message: "Заплануй мені страви для обіду та вечері", intent: "mealSuggestions", userContext: eveningContext,
  });
  assert.deepEqual(returnedPlan(result).map((option) => option.mealType), ["lunch", "dinner"]);
  assert.equal(app.requests.length, 1);
  assert.match(app.requests[0].instructions, /exactly 2 options/);
});

test("multiple generic meal ideas returned by AI are not silently truncated to one", async () => {
  const suggestions = plan(["dinner", "dinner", "dinner"]);
  const app = runtime(completion(action("propose_meal_suggestions", suggestions)));
  const result = await app.chat({ message: "Запропонуй декілька ідей страв", intent: "mealSuggestions" });
  assert.deepEqual(returnedPlan(result).map((option) => option.title), suggestions.options.map((option) => option.title));
  assert.equal(app.requests.length, 1);
});

for (const [label, incompleteTypes] of [
  ["missing meals", ["breakfast"]],
  ["duplicate meal types despite four cards", ["breakfast", "lunch", "lunch", "dinner"]],
]) {
  test(`an explicit day with ${label} gets one corrective request and returns only the completed plan`, async () => {
    const initial = action("propose_meal_suggestions", plan(incompleteTypes), "call-incomplete-plan");
    const app = runtime(completion(initial), completion(action("propose_meal_suggestions", plan(allMealTypes), "call-full-plan")));
    const result = await app.chat({ message: fullDayRequest, intent: "mealSuggestions", userContext: eveningContext });
    assert.deepEqual(returnedPlan(result).map((option) => option.mealType), allMealTypes);
    assert.equal(result.body.message.toolCalls[0].id, "call-full-plan");
    assert.equal(app.requests.length, 2);
    assert.equal(app.requests[0].tool_choice, "auto");
    assert.deepEqual(app.requests[1].tool_choice, { type: "function", name: "propose_meal_suggestions" });
    const toolResults = app.requests[1].input.filter((item) => item.type === "function_call_output");
    assert.equal(toolResults.length, 1);
    assert.equal(toolResults[0].call_id, initial.call_id);
  });
}

test("a missing option mealType is repaired instead of being silently supplied by the top-level default", async () => {
  const incomplete = plan(allMealTypes);
  delete incomplete.options[0].mealType;
  const app = runtime(
    completion(action("propose_meal_suggestions", incomplete, "call-missing-type")),
    completion(action("propose_meal_suggestions", plan(allMealTypes), "call-repaired-type")),
  );
  const result = await app.chat({ message: fullDayRequest, intent: "mealSuggestions", userContext: eveningContext });
  assert.deepEqual(returnedPlan(result).map((option) => option.mealType), allMealTypes);
  assert.equal(app.requests.length, 2);
  assert.equal(result.body.message.toolCalls[0].id, "call-repaired-type");
  assert.deepEqual(app.requests[1].tool_choice, { type: "function", name: "propose_meal_suggestions" });
});

test("two incomplete day plans return an error without publishing partial cards or making a third request", async () => {
  const app = runtime(
    completion(action("propose_meal_suggestions", plan(["breakfast"]), "call-first-incomplete")),
    completion(action("propose_meal_suggestions", plan(["breakfast", "lunch", "lunch", "dinner"]), "call-second-incomplete")),
  );
  const result = await app.chat({ message: fullDayRequest, intent: "mealSuggestions", userContext: eveningContext });
  assert.ok(result.status >= 500, JSON.stringify(result.body));
  assert.equal(app.requests.length, 2);
  assert.equal(typeof result.body.error, "string");
  assert.ok(result.body.error.trim());
  assert.equal(result.body.message, undefined);
});

test("a day-planning clarification remains a question instead of forcing an incomplete plan", async () => {
  const question = "Які продукти у вас є для цих прийомів їжі?";
  const app = runtime(completion(textMessage(question)));
  const result = await app.chat({ message: fullDayRequest, intent: "mealSuggestions" });
  assert.equal(result.status, 200);
  assert.equal(result.body.message.content, question);
  assert.deepEqual(result.body.message.toolCalls, []);
  assert.equal(app.requests[0].tool_choice, "auto");
  assert.equal(app.requests.length, 1);
});

for (const message of [
  "Я сьогодні з’їв яйця на сніданок і борщ на обід",
  "Я з’їв страви на сніданок і обід",
]) {
  test(`past report “${message}” is not misclassified as a two-meal plan`, async () => {
    const breakfast = { ...log, name: "Яйця", mealType: "breakfast", portionGrams: 100 };
    const app = runtime(completion(
      action("propose_food_log", breakfast, "call-breakfast-log"),
      action("propose_food_log", log, "call-lunch-log"),
    ));
    const result = await app.chat({ message, intent: "nutrition", userContext: eveningContext });
    assert.equal(result.status, 200, JSON.stringify(result.body));
    assert.equal(app.requests.length, 1);
    assert.deepEqual(result.body.message.toolCalls.map((call) => call.name), ["propose_food_log", "propose_food_log"]);
    assert.deepEqual(result.body.message.toolCalls.map((call) => call.arguments.mealType), ["breakfast", "lunch"]);
    assert.doesNotMatch(app.requests[0].instructions, /exactly 2 options/);
  });
}

test("plain fruit logging preserves user specificity instead of inventing skin qualifiers", async () => {
  const app = runtime(completion(action("propose_food_log", {
    name: "Яблуко", mealType: "snacks", calories: 95, protein: 0.5, carbs: 25, fats: 0.3,
    source: "text", kind: "product", portionGrams: 182,
  })));
  const result = await app.chat({ message: "Яблуко", userContext: { locale: "uk" } });
  assert.equal(result.status, 200);
  assert.match(app.requests[0].instructions, /keep that exact plain name/);
  assert.match(app.requests[0].instructions, /Preserve qualifiers when the user explicitly requests them/);
  assert.match(app.requests[0].instructions, /prefer an exact name match first/);
});

test("catalog scoring ranks an exact apple before qualified variants", () => {
  const context = vm.createContext({ URL, setTimeout, clearTimeout });
  vm.runInContext(source + '\nglobalThis.score = catalogFoodMatchScore;', context);
  for (const [query, exact, variant] of [
    ["apple", "Apple", "Apple with skin"],
    ["Яблуко", "Яблуко", "Яблуко зі шкіркою"],
    ["apple with skin", "Apple with skin", "Apple"],
  ]) {
    assert.ok(context.score(query, { name: exact }) > context.score(query, { name: variant }));
  }
});
