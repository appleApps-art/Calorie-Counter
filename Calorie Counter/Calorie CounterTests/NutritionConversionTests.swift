import CoreData
import XCTest
@testable import Calorie_Counter

@MainActor
final class NutritionConversionTests: XCTestCase {
    func testSpoonacularBarcodeUsesActualServingGrams() throws {
        let product = try barcodeProduct(size: 30, unit: "g", calories: 150)
        XCTAssertNil(product.caloriesPer100g)
        XCTAssertEqual(product.caloriesPerServing, 150)
        XCTAssertEqual(product.servingGrams, 30)
        let draft = ProductDetailsMath.draft(from: product, imageData: nil, mealType: .snacks, date: Date())
        XCTAssertEqual(draft.portionGrams, 30)
        XCTAssertEqual(ProductDetailsMath.scaled(draft, toGrams: 30).loggedCalories, 150, accuracy: 0.001)
        XCTAssertEqual(ProductDetailsMath.scaled(draft, toGrams: 60).loggedCalories, 300, accuracy: 0.001)
        let searchProduct = product.toFoodProduct()
        XCTAssertEqual(searchProduct.amount, 30)
        XCTAssertEqual(searchProduct.unit, "g")
        XCTAssertEqual(searchProduct.calories, 150)
    }

    func testSpoonacularBarcodeUsesActualServingMilliliters() throws {
        let product = try barcodeProduct(size: 250, unit: "ml", calories: 120)
        let draft = ProductDetailsMath.draft(from: product, imageData: nil, mealType: .snacks, date: Date())
        XCTAssertNil(draft.portionGrams)
        XCTAssertEqual(draft.portionMilliliters, 250)
        XCTAssertEqual(ProductDetailsMath.scaled(draft, toMilliliters: 125).loggedCalories, 60, accuracy: 0.001)
        XCTAssertEqual(product.toFoodProduct().unit, "ml")
    }

    func testSpoonacularUnknownServingUnitDoesNotBecome100Grams() throws {
        let product = try barcodeProduct(size: 1, unit: "tbsp", calories: 30)
        XCTAssertNil(product.caloriesPer100g)
        XCTAssertNil(product.servingGrams)
        XCTAssertNil(product.servingMilliliters)
        XCTAssertEqual(product.caloriesPerServing, 30)
        XCTAssertNil(product.toFoodProduct().amount)
        XCTAssertEqual(product.toFoodProduct().servingSizeLabel, "1 tbsp")
    }

    func testSpoonacularStandardMassAndVolumeUnitsConvertWithoutChangingCalories() throws {
        let ounce = try barcodeProduct(size: 1, unit: "oz", calories: 150)
        XCTAssertEqual(try XCTUnwrap(ounce.servingGrams), 28.349523125, accuracy: 0.000001)
        XCTAssertEqual(ounce.caloriesPerServing, 150)
        let liters = try barcodeProduct(size: 0.25, unit: "l", calories: 120)
        XCTAssertEqual(liters.servingMilliliters, 250)
        XCTAssertEqual(liters.caloriesPerServing, 120)
    }

    func testSavedRecipeRetainsCookedPortionWhenIngredientMassDiffers() throws {
        let harness = TestHarness()
        let original = recipe(weightGrams: 300)
        try harness.recipes.save(original)
        let restored = try XCTUnwrap(harness.recipes.fetchSaved(externalId: original.externalId!))
        XCTAssertEqual(restored.weightGrams, 300)
        let draft = ProductDetailsMath.draft(from: restored)
        XCTAssertEqual(draft.portionGrams, 300)
        XCTAssertEqual(ProductDetailsMath.scaled(draft, toGrams: 300).loggedCalories, 400, accuracy: 0.001)
        XCTAssertEqual(ProductDetailsMath.scaled(draft, toGrams: 150).loggedCalories, 200, accuracy: 0.001)
    }

    func testLiquidRecipeRoundTripRetainsVolumeInsteadOfInferringIngredientGrams() throws {
        let harness = TestHarness()
        let original = recipe(weightGrams: nil, volumeMilliliters: 500)
        try harness.recipes.save(original)
        let restored = try XCTUnwrap(harness.recipes.fetchSaved(externalId: original.externalId!))
        let draft = ProductDetailsMath.draft(from: restored)
        XCTAssertEqual(restored.volumeMilliliters, 500)
        XCTAssertNil(draft.portionGrams)
        XCTAssertEqual(draft.portionMilliliters, 500)
        XCTAssertEqual(ProductDetailsMath.scaled(draft, toMilliliters: 250).loggedCalories, 200, accuracy: 0.001)
        XCTAssertEqual(FoodProduct(recipe: restored).unit, "ml")
        XCTAssertEqual(draft.toFoodEntry().asRecipe().volumeMilliliters, 500)
    }

    func testSaveFoodRecipeUsesOneServingNutritionAndPreservesMass() throws {
        let harness = TestHarness()
        var draft = ProductDetailsMath.draft(from: recipe(weightGrams: 300))
        draft.servings = 3
        let viewModel = FoodRecipeViewModel(recipeRepository: harness.recipes)
        viewModel.configure(draft)
        viewModel.saveTapped()
        let stored = try XCTUnwrap(harness.recipes.fetchSaved().first)
        XCTAssertEqual(stored.servings, 1)
        XCTAssertEqual(stored.calories, 400)
        XCTAssertEqual(stored.weightGrams, 300)
        let restoredDraft = ProductDetailsMath.draft(from: stored)
        XCTAssertEqual(restoredDraft.loggedCalories, 400)
        XCTAssertEqual(restoredDraft.portionGrams, 300)
    }

    func testMealPlanPersistenceAndLoggingKeepOneServingAndRecipeMetadata() throws {
        let harness = TestHarness()
        let repository = MealPlanRepository(coreDataStack: harness.stack)
        var original = recipe(weightGrams: 300)
        original.servings = 4
        original.ingredients[0].amount = 800
        let plan = MealPlan(
            id: UUID(), title: "Plan", weeks: 1, imageURL: nil,
            recipes: [original], createdAt: Date(), dayLayouts: [1], mealTypeKeys: ["dinner"]
        )
        try repository.save(plan)
        let restored = try XCTUnwrap(repository.fetchAll().first)
        XCTAssertEqual(restored.recipes.first?.weightGrams, 300)
        let viewModel = MealPlanPreviewViewModel(
            plan: restored,
            mealPlanRepository: repository,
            searchRecipesUseCase: SearchRecipesUseCase(
                spoonacularService: SpoonacularService(), aiFoodSearchService: AIFoodSearchService()
            ),
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                foodEntryRepository: harness.food, waterEntryRepository: harness.water,
                userGoalsRepository: harness.goals, workoutEntryRepository: harness.workout
            ),
            logFoodUseCase: LogFoodUseCase(foodEntryRepository: harness.food),
            // A plan opened from the list asks for days first; this is the screen right after it was made.
            isFreshlyCreated: true
        )
        viewModel.addToDiaryTapped()
        let entry = try XCTUnwrap(harness.food.fetchEntries(for: Date()).first)
        XCTAssertEqual(entry.calories, 400)
        XCTAssertEqual(entry.portionGrams, 300)
        XCTAssertEqual(entry.mealType, .dinner)
        XCTAssertEqual(entry.recipeSteps, original.steps)
        XCTAssertEqual(entry.catalogExternalId, original.externalId)
        XCTAssertEqual(entry.catalogKind, .recipe)
        XCTAssertEqual(entry.scaled(toGrams: 150).calories, 200)
        XCTAssertEqual(ProductDetailsMath.draft(from: entry).ingredients.first?.grams, 200)
    }

    func testLegacyMealPlanWithoutPortionFieldsStillDecodes() throws {
        let harness = TestHarness()
        let object = CDMealPlan(context: harness.stack.viewContext)
        object.id = UUID()
        object.title = "Legacy"
        object.createdAt = Date()
        object.weeks = 1
        let json: [String: Any] = [
            "recipes": [["id": UUID().uuidString, "title": "Soup", "ingredients": [], "steps": [], "calories": 200]]
        ]
        object.recipesJSON = String(data: try JSONSerialization.data(withJSONObject: json), encoding: .utf8)
        let restored = try XCTUnwrap(MealPlanMapper.map(object)?.recipes.first)
        XCTAssertEqual(restored.calories, 200)
        XCTAssertNil(restored.weightGrams)
        XCTAssertNil(restored.volumeMilliliters)
    }

    func testMealPlanRetainsLiquidRecipeVolume() throws {
        let harness = TestHarness()
        let repository = MealPlanRepository(coreDataStack: harness.stack)
        let plan = MealPlan(
            id: UUID(), title: "Liquid plan", weeks: 1, imageURL: nil,
            recipes: [recipe(weightGrams: nil, volumeMilliliters: 500)], createdAt: Date()
        )
        try repository.save(plan)
        let restored = try XCTUnwrap(repository.fetchAll().first?.recipes.first)
        XCTAssertEqual(restored.volumeMilliliters, 500)
        XCTAssertNil(restored.weightGrams)
        var draft = ProductDetailsMath.draft(from: restored)
        draft.servings = 1
        let entry = draft.toFoodEntry()
        XCTAssertEqual(entry.portionMilliliters, 500)
        XCTAssertEqual(entry.scaled(toMilliliters: 250).calories, 200)
    }

    func testSwapConfirmationRetainsExplicitVolumeAndReplacementMeal() throws {
        let harness = TestHarness()
        let existing = FoodEntry(
            id: UUID(), name: "Juice", mealType: .dinner, calories: 200,
            protein: 0, carbs: 50, fats: 0, fiber: 0, sugar: 40, sodium: 0,
            date: Date(), portionMilliliters: 250
        )
        try harness.food.save(existing)
        let proposal = FoodSwapProposal(
            original: FoodSwapItem(name: "Juice", calories: 200, protein: 0, carbs: 50, fats: 0, portionLabel: "250 ml"),
            alternative: FoodSwapItem(name: "Milk", calories: 120, protein: 8, carbs: 12, fats: 4, portionLabel: "1 glass (250 ml)"),
            savingsKcal: 80, savingsNote: nil, applyToEntryId: existing.id
        )
        let confirmation = ConfirmAIAssistantActionUseCase(
            logFoodUseCase: LogFoodUseCase(foodEntryRepository: harness.food),
            replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
            logWaterUseCase: harness.logWater(),
            saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
            recipeRepository: harness.recipes, foodEntryRepository: harness.food
        )
        let saved = try XCTUnwrap(confirmation.execute(.swapFood(proposal)))
        XCTAssertEqual(saved.id, existing.id)
        XCTAssertEqual(saved.mealType, .dinner)
        XCTAssertEqual(saved.portionMilliliters, 250)
        XCTAssertNil(saved.portionGrams)
        XCTAssertEqual(saved.scaled(toMilliliters: 125).calories, 60)
        XCTAssertEqual(try harness.food.fetchEntry(id: saved.id)?.portionMilliliters, 250)
    }

    func testMealSuggestionPortionSurvivesActionParsingHistoryAndLogging() throws {
        let json = #"{"id":"suggest","name":"propose_meal_suggestions","arguments":{"mealType":"lunch","options":[{"title":"Soup","calories":400,"protein":20,"carbs":50,"fats":13,"portionGrams":300}]}}"#
        let call = try JSONDecoder().decode(AIAssistantToolCall.self, from: Data(json.utf8))
        guard case .mealSuggestions(let proposal) = ParseAIAssistantActionsUseCase().execute(toolCalls: [call]).first else {
            return XCTFail("Expected meal suggestion")
        }
        let option = try XCTUnwrap(proposal.options.first)
        let restored = try JSONDecoder().decode(MealSuggestionOption.self, from: JSONEncoder().encode(option))
        XCTAssertEqual(restored.portionGrams, 300)
        XCTAssertEqual(restored.asFoodLogProposal(mealType: .lunch).toFoodEntry().scaled(toGrams: 150).calories, 200)
        XCTAssertEqual(ProductDetailsMath.draft(from: restored, mealType: .lunch).portionGrams, 300)
    }

    func testSwapWithoutAnExplicitMeasurementDoesNotInventGrams() {
        let proposal = FoodSwapProposal(
            original: FoodSwapItem(name: "Original", calories: 200, protein: 0, carbs: 50, fats: 0, portionLabel: "2"),
            alternative: FoodSwapItem(name: "Alternative", calories: 120, protein: 8, carbs: 12, fats: 4, portionLabel: "2"),
            savingsKcal: 80, savingsNote: nil, applyToEntryId: nil
        )
        let log = proposal.asFoodLogProposal()
        XCTAssertNil(log.portionGrams)
        XCTAssertNil(log.portionMilliliters)
        XCTAssertEqual(log.calories, 120)
    }

    private func barcodeProduct(size: Double, unit: String, calories: Double) throws -> BarcodeProduct {
        let json: [String: Any] = [
            "id": 1, "title": "Test food", "servings": ["number": 2, "size": size, "unit": unit],
            "nutrition": ["nutrients": [
                ["name": "Calories", "amount": calories, "unit": "kcal"],
                ["name": "Protein", "amount": 8, "unit": "g"],
                ["name": "Carbohydrates", "amount": 12, "unit": "g"],
                ["name": "Fat", "amount": 4, "unit": "g"]
            ]]
        ]
        let item = try JSONDecoder().decode(SpoonacularUpcProductResponse.self, from: JSONSerialization.data(withJSONObject: json))
        return try XCTUnwrap(SpoonacularMapper.mapUpcProduct(item, barcode: "123456789012"))
    }

    private func recipe(weightGrams: Double?, volumeMilliliters: Double? = nil) -> Recipe {
        Recipe(
            id: UUID(), externalId: "ai-portion-test", title: "Soup", summary: nil, imageURL: nil,
            readyInMinutes: 15, servings: 1, calories: 400, protein: 20, carbs: 50, fats: 13,
            ingredients: [RecipeIngredient(id: "rice", name: "Rice", amount: 200, unit: "g", originalText: "Rice 200 g")],
            steps: ["Cook"], sourceName: "AI", origin: .openAI,
            weightGrams: weightGrams, volumeMilliliters: volumeMilliliters
        )
    }
}
