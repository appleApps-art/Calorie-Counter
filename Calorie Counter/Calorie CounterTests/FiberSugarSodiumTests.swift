import XCTest
@testable import Calorie_Counter

/// Fiber, sugar and sodium used to be dropped on the way from a recipe, an AI dish or a barcode
/// to the diary, so those goals never moved. These follow each path to the end.
@MainActor
final class FiberSugarSodiumTests: XCTestCase {
    func testACatalogRecipeKeepsFiberSugarAndSodiumAllTheWayToTheDiary() throws {
        let json = """
        {"results":[{"id":1,"title":"Lentil soup","servings":2,"nutrition":{"nutrients":[
          {"name":"Calories","amount":320,"unit":"kcal"},{"name":"Protein","amount":18,"unit":"g"},
          {"name":"Carbohydrates","amount":45,"unit":"g"},{"name":"Fat","amount":7,"unit":"g"},
          {"name":"Fiber","amount":12,"unit":"g"},{"name":"Sugar","amount":6,"unit":"g"},
          {"name":"Sodium","amount":540,"unit":"mg"}]}}]}
        """
        let response = try JSONDecoder().decode(SpoonacularRecipeSearchResponse.self, from: Data(json.utf8))
        let recipe = SpoonacularMapper.mapSearchItem(try XCTUnwrap(response.results?.first))
        XCTAssertEqual(recipe.fiber, 12)
        XCTAssertEqual(recipe.sugar, 6)
        XCTAssertEqual(recipe.sodium, 540)

        let draft = ProductDetailsMath.draft(from: recipe)
        XCTAssertEqual(draft.fiber, 12)
        XCTAssertEqual(draft.sugar, 6)
        XCTAssertEqual(draft.sodium, 540)
        let entry = draft.toFoodEntry()
        XCTAssertGreaterThan(entry.fiber, 0, "The diary counts the recipe's fiber")
        XCTAssertGreaterThan(entry.sodium, 0)
    }

    func testABarcodeProductBringsItsFiberSugarAndSodiumInMilligrams() throws {
        let json = """
        {"energy-kcal_100g":380,"proteins_100g":10,"carbohydrates_100g":60,"fat_100g":9,
         "fiber_100g":8.5,"sugars_100g":12,"sodium_100g":0.42}
        """
        let nutriments = try JSONDecoder().decode(OpenFoodFactsNutriments.self, from: Data(json.utf8))
        let product = BarcodeProduct(
            id: UUID(), barcode: "4006381333931", name: "Muesli", brand: nil, quantityLabel: nil,
            servingSizeLabel: nil, imageURL: nil,
            caloriesPer100g: nutriments.energyKcal100g, proteinPer100g: nutriments.proteins100g,
            carbsPer100g: nutriments.carbohydrates100g, fatsPer100g: nutriments.fat100g,
            caloriesPerServing: nil, proteinPerServing: nil, carbsPerServing: nil, fatsPerServing: nil,
            source: .openFoodFacts,
            fiberPer100g: nutriments.fiber100g,
            sugarPer100g: nutriments.sugars100g,
            sodiumPer100g: nutriments.sodium100g.map { $0 * 1000 }
        )
        let draft = ProductDetailsMath.draft(from: product, imageData: nil, mealType: .breakfast, date: Date())
        XCTAssertEqual(draft.fiber, 8.5)
        XCTAssertEqual(draft.sugar, 12)
        XCTAssertEqual(draft.sodium, 420, accuracy: 0.01, "Open Food Facts sends grams; the app counts milligrams")
    }

    func testAnAIDishCardCarriesFiberSugarAndSodiumIntoTheLog() throws {
        let calls = try JSONDecoder().decode([AIAssistantToolCall].self, from: JSONSerialization.data(withJSONObject: [[
            "id": "meal-1", "name": "propose_meal_suggestions", "arguments": [
                "mealType": "lunch",
                "options": [[
                    "title": "Салат з нутом", "summary": "Легкий обід",
                    "calories": 420, "protein": 18, "carbs": 48, "fats": 15,
                    "fiber": 11, "sugar": 7, "sodium": 380
                ]]
            ]
        ]]))
        guard case .mealSuggestions(let proposal) = ParseAIAssistantActionsUseCase().execute(toolCalls: calls).first,
              let option = proposal.options.first else {
            return XCTFail("The dish card parses")
        }
        XCTAssertEqual(option.fiber, 11)
        let logged = option.asFoodLogProposal(mealType: .lunch)
        XCTAssertEqual(logged.fiber, 11)
        XCTAssertEqual(logged.sugar, 7)
        XCTAssertEqual(logged.sodium, 380)
        XCTAssertEqual(ProductDetailsMath.draft(from: option, mealType: .lunch, date: Date()).fiber, 11)
    }

    func testSavedRecipesAndPlansKeepTheValues() throws {
        let harness = TestHarness()
        var recipe = Recipe(
            id: UUID(), externalId: "77", title: "Chili", summary: nil, imageURL: nil,
            readyInMinutes: 30, servings: 2, calories: 450, protein: 30, carbs: 40, fats: 15,
            ingredients: [], steps: ["Cook."], sourceName: nil
        )
        recipe.fiber = 13
        recipe.sugar = 9
        recipe.sodium = 610
        try harness.recipes.save(recipe)
        let saved = try XCTUnwrap(try harness.recipes.fetchSaved(externalId: "77"))
        XCTAssertEqual(saved.fiber, 13)
        XCTAssertEqual(saved.sugar, 9)
        XCTAssertEqual(saved.sodium, 610)

        let plans = MealPlanRepository(coreDataStack: harness.stack)
        let plan = MealPlan(
            id: UUID(), title: "План 1", weeks: 1, imageURL: nil, recipes: [recipe],
            createdAt: Date(), dayLayouts: [1], mealTypeKeys: ["lunch"]
        )
        try plans.save(plan)
        let stored = try XCTUnwrap(try plans.fetchAll().first?.recipes.first)
        XCTAssertEqual(stored.fiber, 13)
        XCTAssertEqual(stored.sodium, 610)
    }
}
