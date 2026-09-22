import XCTest
@testable import Calorie_Counter

@MainActor
final class RecipeFilterSearchTests: XCTestCase {
    func testFiltersMapToCatalogParameters() {
        var filters = RecipeSearchFilters.empty
        filters.mealTypes = [L10n.tr("recipes.filters.breakfast"), L10n.tr("recipes.filters.lunch"), L10n.tr("recipes.filters.dinner")]
        filters.cuisines = [L10n.tr("recipes.filters.italian"), L10n.tr("recipes.filters.greek")]
        filters.diets = [L10n.tr("recipes.filters.vegetarian"), L10n.tr("recipes.filters.weightGain")]
        filters.maxReadyMinutes = 30
        filters.maxCalories = 400
        filters.difficulties = [L10n.tr("recipes.filters.easy")]
        filters.excludedIngredients = ["Яйця", "Пшениця"]

        XCTAssertEqual(filters.searchParameters, RecipeSearchParameters(
            type: "breakfast,main course",
            cuisine: "italian,greek",
            diet: "vegetarian",
            maxReadyTime: 30,
            maxCalories: 400,
            excludeIngredients: "Яйця,Пшениця"
        ))
    }

    func testLeanDietMeansVeganAndUnmappedChoicesAreIgnored() {
        var filters = RecipeSearchFilters.empty
        filters.diets = [L10n.tr("recipes.filters.lean"), L10n.tr("recipes.filters.balance")]
        filters.difficulties = [L10n.tr("recipes.filters.hard")]
        XCTAssertEqual(filters.searchParameters, RecipeSearchParameters(diet: "vegan"))

        var unmapped = RecipeSearchFilters.empty
        unmapped.diets = [L10n.tr("recipes.filters.weightGain")]
        XCTAssertTrue(unmapped.searchParameters.isEmpty)
        XCTAssertEqual(RecipeSearchFilters.empty.searchParameters, RecipeSearchParameters())
    }

    func testSearchSendsTypedTextAndFiltersSeparately() async throws {
        let backend = FilterSearchStub()
        let useCase = SearchRecipesUseCase(spoonacularService: FilterSpoonacularStub(), aiFoodSearchService: backend)
        var filters = RecipeSearchFilters.empty
        filters.diets = [L10n.tr("recipes.filters.vegetarian")]

        _ = try await useCase.execute(query: "  тако ", filters: filters)
        _ = try await useCase.execute(query: "", filters: filters)
        let unfiltered = try await useCase.execute(query: "", filters: .empty)

        XCTAssertEqual(backend.calls.map(\.query), ["тако", ""])
        XCTAssertEqual(backend.calls.map(\.parameters), [
            RecipeSearchParameters(diet: "vegetarian"),
            RecipeSearchParameters(diet: "vegetarian")
        ])
        XCTAssertTrue(unfiltered.isEmpty)
    }

    func testTypingWithActiveFiltersSearchesBackendWithoutSuggestions() async {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let backend = FilterSearchStub()
        backend.results = [Recipe(
            id: UUID(),
            externalId: "1",
            title: "Veggie Tacos",
            imageURL: URL(string: "https://example.com/tacos.jpg"),
            ingredients: [],
            steps: []
        )]
        let viewModel = makeViewModel(container, backend: backend)
        var filters = RecipeSearchFilters.empty
        filters.diets = [L10n.tr("recipes.filters.vegetarian")]
        viewModel.applyFilters(filters)
        await waitUntil { !viewModel.isLoading.value }

        viewModel.updateQuery("тако")
        await waitUntil(timeout: 2) { backend.calls.count == 2 }
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(backend.calls.last?.query, "тако")
        XCTAssertEqual(backend.calls.last?.parameters, RecipeSearchParameters(diet: "vegetarian"))
        XCTAssertEqual(viewModel.resultRecipes.value.map(\.title), ["Veggie Tacos"])
        XCTAssertTrue(viewModel.suggestionTitles.value.isEmpty)
    }

    func testFilteredResultsLoadNextPagesUntilCatalogEnds() async {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let backend = FilterSearchStub()
        backend.pageSize = 10
        backend.total = 23
        let viewModel = makeViewModel(container, backend: backend)
        var filters = RecipeSearchFilters.empty
        filters.diets = [L10n.tr("recipes.filters.vegan")]

        viewModel.applyFilters(filters)
        await waitUntil { !viewModel.isLoading.value }
        XCTAssertEqual(viewModel.resultRecipes.value.count, 10)

        viewModel.loadMoreResultsIfNeeded()
        XCTAssertTrue(viewModel.isLoadingMoreResults.value)
        await waitUntil { !viewModel.isLoadingMoreResults.value }
        XCTAssertEqual(viewModel.resultRecipes.value.count, 20)

        viewModel.loadMoreResultsIfNeeded()
        await waitUntil { !viewModel.isLoadingMoreResults.value }
        XCTAssertEqual(viewModel.resultRecipes.value.map(\.externalId).last, "23")

        viewModel.loadMoreResultsIfNeeded()
        XCTAssertFalse(viewModel.isLoadingMoreResults.value)
        XCTAssertEqual(backend.calls.map(\.offset), [0, 10, 20])
        XCTAssertTrue(backend.calls.allSatisfy { $0.parameters == RecipeSearchParameters(diet: "vegan") })
        XCTAssertFalse(viewModel.showsEmptyResults.value)
    }

    func testTextSearchKeepsItsPagingPerTab() async {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let backend = FilterSearchStub()
        backend.pageSize = 10
        backend.total = 15
        let viewModel = makeViewModel(container, backend: backend)

        viewModel.updateQuery("pasta")
        viewModel.searchTapped()
        await waitUntil { !viewModel.isLoading.value }
        viewModel.selectTab(.saved)
        viewModel.loadMoreResultsIfNeeded()
        XCTAssertFalse(viewModel.isLoadingMoreResults.value)

        viewModel.selectTab(.all)
        viewModel.loadMoreResultsIfNeeded()
        await waitUntil { !viewModel.isLoadingMoreResults.value }
        XCTAssertEqual(viewModel.resultRecipes.value.count, 15)
        XCTAssertEqual(backend.calls.map(\.offset), [0, 10])
        XCTAssertEqual(backend.calls.map(\.query), ["pasta", "pasta"])
    }

    func testExcludedIngredientCanBeConfirmedAfterTwoTypedLetters() {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let viewModel = RecipeFiltersViewModel(
            filters: .empty,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
        )

        viewModel.updateExcludedQuery("с")
        XCTAssertFalse(viewModel.canConfirmExcluded.value)
        viewModel.updateExcludedQuery("со")
        XCTAssertTrue(viewModel.canConfirmExcluded.value)
        viewModel.updateExcludedQuery("соя ")
        viewModel.trailingActionTapped()

        XCTAssertEqual(viewModel.filters.value.excludedIngredients, ["соя"])
        XCTAssertFalse(viewModel.canConfirmExcluded.value)
        XCTAssertEqual(viewModel.excludedQuery.value, "")

        viewModel.updateExcludedQuery("  ")
        XCTAssertFalse(viewModel.canConfirmExcluded.value)
    }

    private func makeViewModel(_ container: DIContainer, backend: FilterSearchStub) -> RecipesViewModel {
        RecipesViewModel(
            searchRecipesUseCase: SearchRecipesUseCase(spoonacularService: FilterSpoonacularStub(), aiFoodSearchService: backend),
            fetchBrowseSectionsUseCase: container.fetchRecipeBrowseSectionsUseCase,
            recipeRepository: container.recipeRepository,
            fetchMealPlansUseCase: container.fetchMealPlansUseCase,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
        )
    }
}


@MainActor
private final class FilterSearchStub: AIFoodSearching {
    var results: [Recipe] = []
    private(set) var calls: [(query: String, parameters: RecipeSearchParameters, offset: Int)] = []

    func searchRecipes(query: String) async throws -> [Recipe] {
        XCTFail("Recipe search must send filters as parameters")
        return []
    }
    var pageSize = 0
    var total = 0

    func searchRecipePage(query: String, parameters: RecipeSearchParameters, offset: Int) async throws -> RecipeSectionPage {
        calls.append((query, parameters, offset))
        guard pageSize > 0 else {
            return RecipeSectionPage(recipes: results, nextOffset: offset + results.count, hasMore: false)
        }
        let count = max(0, min(pageSize, total - offset))
        let recipes = (0..<count).map { index in
            Recipe(
                id: UUID(),
                externalId: "\(offset + index + 1)",
                title: "Recipe \(offset + index + 1)",
                imageURL: URL(string: "https://example.com/\(offset + index + 1).jpg"),
                ingredients: [],
                steps: []
            )
        }
        return RecipeSectionPage(recipes: recipes, nextOffset: offset + count, hasMore: offset + count < total)
    }
    func searchFoods(query: String) async throws -> [FoodProduct] { [] }
    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] { [:] }
    func fetchCatalogSection(id: String) async throws -> [FoodProduct] { [] }
    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        FoodSearchCatalogPage(products: [], nextOffset: 0, hasMore: false)
    }
    func enrichDetails(title: String, imageURL: URL?, source: String, kind: String) async throws -> FoodProduct? { nil }
}

private final class FilterSpoonacularStub: SpoonacularServiceProtocol {
    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func searchIngredients(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func searchRecipes(query: String, maxCalories: Int?, number: Int) async throws -> [Recipe] { [] }
    func recipeDetails(id: String) async throws -> Recipe { throw URLError(.badServerResponse) }
    func ingredientDetails(id: String, amount: Double, unit: String) async throws -> FoodProduct { throw URLError(.badServerResponse) }
    func productDetails(id: String) async throws -> FoodProduct { throw URLError(.badServerResponse) }
    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct { throw BarcodeLookupError.notFound }
}
