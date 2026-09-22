import XCTest
@testable import Calorie_Counter

@MainActor
final class SavedRecipesSearchTests: XCTestCase {
    func testMatchesSearchUsesTitleAndIngredientsIgnoringCase() {
        let recipe = Recipe(
            id: UUID(),
            title: "Рататуй",
            ingredients: [
                RecipeIngredient(id: "1", name: "Баклажан", originalText: "1 великий баклажан"),
                RecipeIngredient(id: "2", name: "Zucchini")
            ],
            steps: []
        )
        XCTAssertTrue(recipe.matchesSearch("рататуй"))
        XCTAssertTrue(recipe.matchesSearch("РАТА"))
        XCTAssertTrue(recipe.matchesSearch("баклажан"))
        XCTAssertTrue(recipe.matchesSearch("zucchini"))
        XCTAssertTrue(recipe.matchesSearch("рататуй баклажан"))
        XCTAssertTrue(recipe.matchesSearch("   "))
        XCTAssertFalse(recipe.matchesSearch("лазанья"))
        XCTAssertFalse(recipe.matchesSearch("рататуй курка"))
    }

    func testSavedTabFiltersSavedRecipesWhileTypingWithoutBackendSearch() throws {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        try container.recipeRepository.save(recipe("Рататуй", ingredients: ["Баклажан"]))
        try container.recipeRepository.save(recipe("Лазанья", ingredients: ["Фарш"]))
        let viewModel = makeViewModel(container)

        viewModel.selectTab(.saved)
        XCTAssertEqual(Set(viewModel.visibleSavedRecipes.value.map(\.title)), ["Рататуй", "Лазанья"])

        viewModel.updateQuery("рата")
        XCTAssertEqual(viewModel.visibleSavedRecipes.value.map(\.title), ["Рататуй"])
        XCTAssertFalse(viewModel.showsFilterResults.value)
        XCTAssertFalse(viewModel.isLoading.value)

        viewModel.updateQuery("фарш")
        XCTAssertEqual(viewModel.visibleSavedRecipes.value.map(\.title), ["Лазанья"])

        viewModel.searchTapped()
        XCTAssertEqual(viewModel.visibleSavedRecipes.value.map(\.title), ["Лазанья"])
        XCTAssertFalse(viewModel.showsFilterResults.value)
        XCTAssertFalse(viewModel.isLoading.value)

        viewModel.updateQuery("борщ")
        XCTAssertTrue(viewModel.visibleSavedRecipes.value.isEmpty)
        XCTAssertTrue(viewModel.isSearchingLocally)

        viewModel.updateQuery("")
        XCTAssertEqual(viewModel.visibleSavedRecipes.value.count, 2)
        XCTAssertFalse(viewModel.isSearchingLocally)
    }

    func testMealPlansTabFiltersPlansByTitleWithoutBackendSearch() throws {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        try container.mealPlanRepository.save(plan("High-Protein Week", recipes: [recipe("Chicken Bowl", ingredients: [])]))
        try container.mealPlanRepository.save(plan("Веганський тиждень", recipes: []))
        let backend = RecipeSearchStub(results: [:])
        let viewModel = makeViewModel(container, backend: backend)

        viewModel.selectTab(.mealPlans)
        XCTAssertEqual(viewModel.visibleMealPlans.value.count, 2)

        viewModel.updateQuery("protein")
        XCTAssertEqual(viewModel.visibleMealPlans.value.map(\.title), ["High-Protein Week"])
        XCTAssertTrue(viewModel.isSearchingLocally)

        viewModel.updateQuery("ВЕГАН")
        XCTAssertEqual(viewModel.visibleMealPlans.value.map(\.title), ["Веганський тиждень"])

        viewModel.updateQuery("chicken")
        viewModel.searchTapped()
        XCTAssertTrue(viewModel.visibleMealPlans.value.isEmpty)
        XCTAssertFalse(viewModel.showsFilterResults.value)
        XCTAssertFalse(viewModel.isLoading.value)
        XCTAssertTrue(backend.queries.isEmpty)

        viewModel.updateQuery("")
        XCTAssertEqual(viewModel.visibleMealPlans.value.count, 2)
        XCTAssertFalse(viewModel.isSearchingLocally)
    }

    func testEachTabKeepsItsOwnQueryAndResults() async throws {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        try container.recipeRepository.save(recipe("Рататуй", ingredients: []))
        try container.recipeRepository.save(recipe("Лазанья", ingredients: []))
        let backend = RecipeSearchStub(results: ["рататуй": [recipe("Рататуй з бекенду", ingredients: [])]])
        let viewModel = makeViewModel(container, backend: backend)

        viewModel.updateQuery("рататуй")
        viewModel.searchTapped()
        await waitUntil { !viewModel.isLoading.value }
        XCTAssertTrue(viewModel.showsFilterResults.value)
        XCTAssertFalse(viewModel.hidesTabs)
        XCTAssertEqual(viewModel.resultRecipes.value.map(\.title), ["Рататуй з бекенду"])

        viewModel.selectTab(.saved)
        XCTAssertEqual(viewModel.queryText.value, "")
        XCTAssertFalse(viewModel.showsFilterResults.value)
        XCTAssertEqual(viewModel.visibleSavedRecipes.value.count, 2)

        viewModel.updateQuery("лаз")
        XCTAssertEqual(viewModel.visibleSavedRecipes.value.map(\.title), ["Лазанья"])

        viewModel.selectTab(.mealPlans)
        XCTAssertEqual(viewModel.queryText.value, "")
        XCTAssertFalse(viewModel.showsFilterResults.value)

        viewModel.selectTab(.all)
        XCTAssertEqual(viewModel.queryText.value, "рататуй")
        XCTAssertTrue(viewModel.showsFilterResults.value)
        XCTAssertEqual(viewModel.resultRecipes.value.map(\.title), ["Рататуй з бекенду"])

        viewModel.selectTab(.saved)
        XCTAssertEqual(viewModel.queryText.value, "лаз")
        XCTAssertEqual(viewModel.visibleSavedRecipes.value.map(\.title), ["Лазанья"])
        XCTAssertEqual(backend.queries, ["рататуй"])
    }

    func testSearchStartedOnOneTabFinishesIntoThatTab() async throws {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let backend = RecipeSearchStub(results: ["паста": [recipe("Паста", ingredients: [])]])
        backend.delayNanoseconds = 200_000_000
        let viewModel = makeViewModel(container, backend: backend)

        viewModel.updateQuery("паста")
        viewModel.searchTapped()
        XCTAssertTrue(viewModel.isLoading.value)
        viewModel.selectTab(.saved)
        XCTAssertFalse(viewModel.isLoading.value)
        XCTAssertFalse(viewModel.showsFilterResults.value)

        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(viewModel.resultRecipes.value.isEmpty)

        viewModel.selectTab(.all)
        XCTAssertFalse(viewModel.isLoading.value)
        XCTAssertEqual(viewModel.resultRecipes.value.map(\.title), ["Паста"])
        XCTAssertEqual(backend.queries, ["паста"])
    }

    func testTabsHideOnlyWhileFiltersAreActive() {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let viewModel = makeViewModel(container, backend: RecipeSearchStub(results: [:]))
        var filters = RecipeSearchFilters.empty
        filters.maxCalories = 400
        XCTAssertTrue(filters.hasActiveConstraints)

        viewModel.applyFilters(filters)
        XCTAssertTrue(viewModel.hidesTabs)

        viewModel.applyFilters(.empty)
        XCTAssertFalse(viewModel.hidesTabs)
    }

    private func makeViewModel(
        _ container: DIContainer,
        backend: RecipeSearchStub? = nil
    ) -> RecipesViewModel {
        RecipesViewModel(
            searchRecipesUseCase: SearchRecipesUseCase(
                spoonacularService: RecipeSpoonacularStub(),
                aiFoodSearchService: backend ?? RecipeSearchStub(results: [:])
            ),
            fetchBrowseSectionsUseCase: container.fetchRecipeBrowseSectionsUseCase,
            recipeRepository: container.recipeRepository,
            fetchMealPlansUseCase: container.fetchMealPlansUseCase,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
        )
    }

    private func plan(_ title: String, recipes: [Recipe]) -> MealPlan {
        MealPlan(id: UUID(), title: title, weeks: 1, imageURL: nil, recipes: recipes, createdAt: Date())
    }

    fileprivate func recipe(_ title: String, ingredients: [String]) -> Recipe {
        Recipe(
            id: UUID(),
            externalId: "test-\(UUID().uuidString)",
            title: title,
            imageURL: URL(string: "https://example.com/\(UUID().uuidString).jpg"),
            calories: 300,
            ingredients: ingredients.enumerated().map { RecipeIngredient(id: "\($0.offset)", name: $0.element) },
            steps: ["Step"]
        )
    }
}

@MainActor
private final class RecipeSearchStub: AIFoodSearching {
    let results: [String: [Recipe]]
    var delayNanoseconds: UInt64 = 0
    private(set) var queries: [String] = []

    init(results: [String: [Recipe]]) {
        self.results = results
    }

    func searchRecipes(query: String) async throws -> [Recipe] {
        queries.append(query)
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return results[query] ?? []
    }
    func searchFoods(query: String) async throws -> [FoodProduct] { [] }
    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] { [:] }
    func fetchCatalogSection(id: String) async throws -> [FoodProduct] { [] }
    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        FoodSearchCatalogPage(products: [], nextOffset: 0, hasMore: false)
    }
    func enrichDetails(title: String, imageURL: URL?, source: String, kind: String) async throws -> FoodProduct? { nil }
}

private final class RecipeSpoonacularStub: SpoonacularServiceProtocol {
    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func searchIngredients(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func searchRecipes(query: String, maxCalories: Int?, number: Int) async throws -> [Recipe] { [] }
    func recipeDetails(id: String) async throws -> Recipe { throw URLError(.badServerResponse) }
    func ingredientDetails(id: String, amount: Double, unit: String) async throws -> FoodProduct { throw URLError(.badServerResponse) }
    func productDetails(id: String) async throws -> FoodProduct { throw URLError(.badServerResponse) }
    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct { throw BarcodeLookupError.notFound }
}
