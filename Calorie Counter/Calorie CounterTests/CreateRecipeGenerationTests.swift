import XCTest
@testable import Calorie_Counter

final class CreateRecipeGenerationTests: XCTestCase {
    func testTheServerRecipeIsUsedAndGetsTheFormInCatalogVocabulary() async throws {
        let catalog = GenerationFakeSpoonacular()
        let server = GenerationFakeAISearch()
        server.created = completeRecipe(title: "Шпинатна фрітата")
        let useCase = makeUseCase(catalog, server)

        let recipe = try await useCase.execute(
            input(
                ingredients: ["Яйця", "Шпинат", " яйця ", "Оливкова олія"],
                mealTypes: [MealType.lunch.rawValue],
                cuisine: L10n.tr("recipes.filters.italian"),
                diet: L10n.tr("recipes.filters.vegetarian"),
                maxReadyMinutes: 30,
                maxCalories: 250
            )
        )

        XCTAssertEqual(recipe?.title, "Шпинатна фрітата")
        let request = try XCTUnwrap(server.requests.first)
        XCTAssertEqual(request.ingredients, ["Яйця", "Шпинат", "Оливкова олія"])
        XCTAssertEqual(request.type, "main course")
        XCTAssertEqual(request.cuisine, "italian")
        XCTAssertEqual(request.diet, "vegetarian")
        XCTAssertEqual(request.maxReadyTime, 30)
        XCTAssertEqual(request.maxCalories, 250)
        XCTAssertNil(request.details)
        XCTAssertFalse(request.locale.isEmpty)
        XCTAssertTrue(catalog.detailRequests.isEmpty, "A server recipe needs no catalog round trip")
    }

    func testTypedDetailsTravelToTheServer() async throws {
        let server = GenerationFakeAISearch()
        server.created = completeRecipe(title: "Гострий рис")
        _ = try await makeUseCase(GenerationFakeSpoonacular(), server)
            .execute(input(ingredients: ["Рис"], details: "  гостре "))
        XCTAssertEqual(server.requests.first?.details, "гостре")
    }

    func testAServerRecipeWithoutAPhotoIsNotAccepted() async throws {
        let catalog = GenerationFakeSpoonacular()
        catalog.matches = [PantryRecipeMatch(id: "7", missedIngredientCount: 0)]
        catalog.details = ["7": completeRecipe(title: "Каталожний омлет")]
        let server = GenerationFakeAISearch()
        var noPhoto = completeRecipe(title: "Без фото")
        noPhoto.imageURL = nil
        server.created = noPhoto

        let recipe = try await makeUseCase(catalog, server).execute(input(ingredients: ["Яйця"]))

        XCTAssertEqual(recipe?.title, "Каталожний омлет")
    }

    func testTheFallbackOnlyTakesRecipesThatNeedNothingElse() async throws {
        let catalog = GenerationFakeSpoonacular()
        catalog.matches = [
            PantryRecipeMatch(id: "1", missedIngredientCount: 2),
            PantryRecipeMatch(id: "2", missedIngredientCount: 0),
        ]
        catalog.details = [
            "1": completeRecipe(title: "Потрібен сир"),
            "2": completeRecipe(title: "Тільки яйця"),
        ]

        let recipe = try await makeUseCase(catalog, GenerationFakeAISearch()).execute(input(ingredients: ["Яйця"]))

        XCTAssertEqual(recipe?.title, "Тільки яйця")
        XCTAssertFalse(catalog.detailRequests.contains("1"))
    }

    func testTheFallbackSkipsARecipeThatCannotOpenAndKeepsTheCatalogOrder() async throws {
        let catalog = GenerationFakeSpoonacular()
        var broken = completeRecipe(title: "Без кроків")
        broken.steps = []
        catalog.matches = [
            PantryRecipeMatch(id: "1", missedIngredientCount: 0),
            PantryRecipeMatch(id: "2", missedIngredientCount: 0),
            PantryRecipeMatch(id: "3", missedIngredientCount: 0),
        ]
        catalog.details = [
            "1": broken,
            "2": completeRecipe(title: "Другий"),
            "3": completeRecipe(title: "Третій"),
        ]

        let recipe = try await makeUseCase(catalog, GenerationFakeAISearch()).execute(input(ingredients: ["Яйця"]))

        XCTAssertEqual(recipe?.title, "Другий")
    }

    func testTheFallbackRespectsCaloriesTimeAndMeal() async throws {
        let catalog = GenerationFakeSpoonacular()
        var heavy = completeRecipe(title: "Важкий")
        heavy.calories = 900
        var slow = completeRecipe(title: "Довгий")
        slow.readyInMinutes = 90
        var dinner = completeRecipe(title: "Вечеря")
        dinner.dishTypes = ["main course"]
        var breakfast = completeRecipe(title: "Сніданок")
        breakfast.dishTypes = ["breakfast"]
        catalog.matches = (1...4).map { PantryRecipeMatch(id: String($0), missedIngredientCount: 0) }
        catalog.details = ["1": heavy, "2": slow, "3": dinner, "4": breakfast]

        let recipe = try await makeUseCase(catalog, GenerationFakeAISearch()).execute(
            input(ingredients: ["Яйця"], mealTypes: [MealType.breakfast.rawValue], maxReadyMinutes: 30, maxCalories: 400)
        )

        XCTAssertEqual(recipe?.title, "Сніданок")
    }

    func testNoRecipeIsInventedWhenNothingUsesOnlyTheUsersProducts() async throws {
        let catalog = GenerationFakeSpoonacular()
        catalog.matches = [PantryRecipeMatch(id: "1", missedIngredientCount: 1)]
        catalog.details = ["1": completeRecipe(title: "Зайчик")]

        let recipe = try await makeUseCase(catalog, GenerationFakeAISearch()).execute(input(ingredients: ["Яйця"]))

        XCTAssertNil(recipe)
        XCTAssertTrue(catalog.searches.isEmpty, "The product list must never become a title search")
    }

    func testAGeneratedRecipeIsNeverReloadedAsACatalogOne() throws {
        let payload = """
        {
          "source": "ai",
          "recipe": {
            "id": 0,
            "title": "Омлет зі шпинатом",
            "image": "https://assistant.example/v1/food/image?name=Omelette",
            "readyInMinutes": 10,
            "servings": 1,
            "sourceName": "Bity AI",
            "dishTypes": ["breakfast"],
            "nutrition": { "nutrients": [
              { "name": "Calories", "amount": 220, "unit": "kcal" },
              { "name": "Protein", "amount": 15, "unit": "g" },
              { "name": "Carbohydrates", "amount": 3, "unit": "g" },
              { "name": "Fat", "amount": 16, "unit": "g" }
            ] },
            "extendedIngredients": [{ "id": null, "name": "Яйця", "amount": 2, "unit": "pcs", "original": "Яйця 2 pcs" }],
            "analyzedInstructions": [{ "steps": [{ "number": 1, "step": "Збийте яйця." }, { "number": 2, "step": "Обсмажте." }] }]
          },
          "cached": false
        }
        """
        let response = try JSONDecoder().decode(RecipeCreationResponse.self, from: Data(payload.utf8))
        let recipe = try XCTUnwrap(AIFoodSearchService.createdRecipe(response))

        XCTAssertNil(recipe.externalId)
        XCTAssertEqual(recipe.origin, .openAI)
        XCTAssertEqual(recipe.hasCompleteNutrition, true)
        XCTAssertEqual(recipe.calories, 220)
        XCTAssertEqual(recipe.steps, ["Збийте яйця.", "Обсмажте."])
        XCTAssertEqual(recipe.dishTypes, ["breakfast"])
        XCTAssertTrue(recipe.hasPhoto)
        XCTAssertTrue(SearchRecipesUseCase.hasCompleteDetails(recipe))
        XCTAssertFalse(SearchRecipesUseCase.hasCatalogRecipeIdentity(recipe))
    }

    func testACatalogRecipeKeepsItsCatalogIdentity() throws {
        let payload = """
        { "source": "catalog", "recipe": { "id": 11, "title": "Frittata", "image": "https://img.spoonacular.com/recipes/11-556x370.jpg" } }
        """
        let response = try JSONDecoder().decode(RecipeCreationResponse.self, from: Data(payload.utf8))
        let recipe = try XCTUnwrap(AIFoodSearchService.createdRecipe(response))
        XCTAssertEqual(recipe.externalId, "11")
        XCTAssertEqual(recipe.origin, .spoonacular)
    }

    // MARK: - Helpers

    private func makeUseCase(_ catalog: GenerationFakeSpoonacular, _ server: GenerationFakeAISearch) -> CreateRecipeUseCase {
        CreateRecipeUseCase(
            searchRecipesUseCase: SearchRecipesUseCase(spoonacularService: catalog, aiFoodSearchService: server),
            recipeRepository: GenerationFakeRecipeRepository()
        )
    }

    private func input(
        ingredients: [String],
        mealTypes: [String] = [],
        cuisine: String? = nil,
        diet: String? = nil,
        maxReadyMinutes: Int? = nil,
        maxCalories: Int? = nil,
        details: String = ""
    ) -> RecipeGenerationInput {
        RecipeGenerationInput(
            ingredients: ingredients,
            mealTypes: mealTypes,
            cuisine: cuisine,
            diet: diet,
            maxReadyMinutes: maxReadyMinutes,
            maxCalories: maxCalories,
            details: details,
            startDate: nil,
            endDate: nil
        )
    }
}

private func completeRecipe(title: String) -> Recipe {
    Recipe(
        id: UUID(),
        externalId: "1",
        title: title,
        summary: "Смачно",
        imageURL: URL(string: "https://img.spoonacular.com/recipes/1-312x231.jpg"),
        readyInMinutes: 20,
        servings: 1,
        calories: 240,
        protein: 12,
        carbs: 20,
        fats: 9,
        ingredients: [RecipeIngredient(id: "1", name: "Яйця", amount: 2, unit: "шт", originalText: nil)],
        steps: ["Збийте яйця", "Обсмажте"],
        sourceName: nil
    )
}

private final class GenerationFakeSpoonacular: SpoonacularServiceProtocol, @unchecked Sendable {
    var matches: [PantryRecipeMatch] = []
    var details: [String: Recipe] = [:]
    private let lock = NSLock()
    private var recordedSearches: [SpoonacularRecipeSearch] = []
    private var recordedDetails: [String] = []

    var searches: [SpoonacularRecipeSearch] { lock.withLock { recordedSearches } }
    var detailRequests: [String] { lock.withLock { recordedDetails } }

    func searchRecipes(query: String, maxCalories: Int?, number: Int) async throws -> [Recipe] {
        try await searchRecipes(SpoonacularRecipeSearch(query: query, number: number, maxCalories: maxCalories))
    }

    func searchRecipes(_ search: SpoonacularRecipeSearch) async throws -> [Recipe] {
        lock.withLock { recordedSearches.append(search) }
        return []
    }

    func pantryRecipeMatches(ingredients: [String], number: Int) async throws -> [PantryRecipeMatch] { matches }

    func recipeDetails(id: String) async throws -> Recipe {
        lock.withLock { recordedDetails.append(id) }
        guard let recipe = details[id] else { throw BarcodeLookupError.notFound }
        return recipe
    }

    func searchIngredients(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func ingredientDetails(id: String, amount: Double, unit: String) async throws -> FoodProduct { throw BarcodeLookupError.notFound }
    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func productDetails(id: String) async throws -> FoodProduct { throw BarcodeLookupError.notFound }
    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct { throw BarcodeLookupError.notFound }
}

private final class GenerationFakeAISearch: AIFoodSearching {
    var created: Recipe?
    private(set) var requests: [RecipeCreationRequest] = []

    func createRecipe(_ request: RecipeCreationRequest) async throws -> Recipe? {
        requests.append(request)
        return created
    }

    func searchFoods(query: String) async throws -> [FoodProduct] { [] }
    func searchRecipes(query: String) async throws -> [Recipe] { [] }
    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] { [:] }
    func fetchCatalogSection(id: String) async throws -> [FoodProduct] { [] }

    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        FoodSearchCatalogPage(products: [], nextOffset: offset, hasMore: false)
    }

    func enrichDetails(title: String, imageURL: URL?, source: String, kind: String) async throws -> FoodProduct? { nil }
}

private final class GenerationFakeRecipeRepository: RecipeRepositoryProtocol {
    private(set) var saved: [Recipe] = []

    func fetchSaved() throws -> [Recipe] { saved }
    func fetchSaved(externalId: String) throws -> Recipe? { saved.first { $0.externalId == externalId } }
    func save(_ recipe: Recipe) throws { saved.append(recipe) }
    func delete(id: UUID) throws { saved.removeAll { $0.id == id } }
    func deleteSaved(_ recipe: Recipe) throws { try delete(id: recipe.id) }
    func isSaved(externalId: String) throws -> Bool { try fetchSaved(externalId: externalId) != nil }
    func isSaved(_ recipe: Recipe) throws -> Bool { saved.contains { $0.id == recipe.id } }
}
