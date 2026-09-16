import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class SearchLoadingStateTests: XCTestCase {
    func testEarlyExactMatchKeepsLoadingUntilAdditionalResultsArrive() async {
        let exact = product("tomato", name: "Помідор")
        let additional = product("cherry", name: "Помідор чері")
        let remote = LoadingResponseGate()
        let ai = LoadingSearchService(gates: ["Помідор": remote], catalog: [exact])
        let (model, useCase) = makeModel(ai: ai)
        _ = try? await useCase.executeCategoryCatalog(tag: "", query: "", sectionID: "vegetablesGreens")

        model.updateQuery("Помідор")
        model.searchTapped()
        XCTAssertEqual(model.resultItems.value.map(\.title), ["Помідор"])
        XCTAssertTrue(model.isSearching.value)
        await assertEventually { remote.isWaiting }
        // The catalog request can publish another partial snapshot while the AI request waits.
        await drainMainActor()
        XCTAssertTrue(model.isSearching.value)
        XCTAssertFalse(model.showsEmptyResults.value)

        remote.succeed([additional])
        await assertEventually { !model.isSearching.value }
        XCTAssertEqual(model.resultItems.value.map(\.title), ["Помідор", "Помідор чері"])
    }

    func testLateRequestFailureStopsLoadingAndKeepsExistingResults() async {
        let exact = product("tomato", name: "Помідор")
        let remote = LoadingResponseGate()
        let ai = LoadingSearchService(gates: ["Помідор": remote], catalog: [exact])
        let (model, _) = makeModel(ai: ai)
        model.updateQuery("Помідор")
        model.searchTapped()
        await assertEventually { remote.isWaiting && !model.resultItems.value.isEmpty }
        XCTAssertTrue(model.isSearching.value)

        remote.fail()
        await assertEventually { !model.isSearching.value }
        XCTAssertEqual(model.resultItems.value.map(\.title), ["Помідор"])
        XCTAssertFalse(model.showsEmptyResults.value)
    }

    func testLoadingWaitsForCatalogWhenUnifiedSearchFinishesFirst() async {
        let catalog = LoadingResponseGate()
        let unified = LoadingResponseGate()
        let ai = LoadingSearchService(gates: ["Помідор": unified])
        let spoonacular = LoadingSpoonacularService(productGate: catalog)
        let (model, _) = makeModel(ai: ai, spoonacular: spoonacular)
        model.updateQuery("Помідор")
        model.searchTapped()
        await assertEventually { catalog.isWaiting && unified.isWaiting }
        unified.succeed([product("cherry", name: "Помідор чері")])
        await assertEventually { unified.didReturn }
        XCTAssertTrue(model.isSearching.value)
        catalog.succeed([product("tomato", name: "Помідор")])
        await assertEventually { !model.isSearching.value }
        XCTAssertEqual(model.resultItems.value.map(\.title), ["Помідор", "Помідор чері"])
    }

    func testNewQueryIgnoresLateOldResultsWithoutEndingNewLoading() async {
        let first = LoadingResponseGate()
        let second = LoadingResponseGate()
        let ai = LoadingSearchService(gates: ["Помідор": first, "Яблуко": second])
        let (model, _) = makeModel(ai: ai)
        model.updateQuery("Помідор")
        model.searchTapped()
        await assertEventually { first.isWaiting }
        model.updateQuery("Яблуко")
        XCTAssertFalse(model.isSearching.value)
        XCTAssertEqual(ai.queries, ["Помідор"], "Typing must not start an unconfirmed search.")
        model.searchTapped()
        await assertEventually { second.isWaiting }

        first.succeed([product("old", name: "Помідор")])
        await assertEventually { first.didReturn }
        await drainMainActor()
        XCTAssertTrue(model.isSearching.value)
        XCTAssertTrue(model.resultItems.value.isEmpty)
        second.succeed([product("new", name: "Яблуко")])
        await assertEventually { !model.isSearching.value }
        XCTAssertEqual(model.resultItems.value.map(\.title), ["Яблуко"])
    }

    func testClearAndBackStopLoadingAndRejectLateResponses() async {
        for shouldClear in [true, false] {
            let remote = LoadingResponseGate()
            let ai = LoadingSearchService(gates: ["Помідор": remote])
            let (model, _) = makeModel(ai: ai)
            var didGoBack = false
            model.onBack = { didGoBack = true }
            model.updateQuery("Помідор")
            model.searchTapped()
            await assertEventually { remote.isWaiting }
            if shouldClear { model.clearQuery() } else { model.backTapped() }
            XCTAssertFalse(model.isSearching.value)
            XCTAssertEqual(didGoBack, !shouldClear)
            remote.succeed([product("late", name: "Помідор")])
            await assertEventually { remote.didReturn }
            await drainMainActor()
            XCTAssertFalse(model.isSearching.value)
            XCTAssertTrue(model.resultItems.value.isEmpty)
            XCTAssertFalse(model.showsEmptyResults.value)
            if shouldClear { XCTAssertEqual(model.phase.value, .browse) }
        }
    }

    private func makeModel(
        ai: LoadingSearchService,
        spoonacular: LoadingSpoonacularService = LoadingSpoonacularService()
    ) -> (FoodSearchViewModel, SearchFoodProductsUseCase) {
        let useCase = SearchFoodProductsUseCase(
            spoonacularService: spoonacular,
            aiFoodSearchService: ai,
            openFoodFactsService: LoadingOpenFoodFacts(),
            textFoodAnalysisService: LoadingTextAnalysis()
        )
        let model = FoodSearchViewModel(
            mealType: .breakfast, date: Date(timeIntervalSince1970: 1_700_000_000),
            searchFoodProductsUseCase: useCase,
            fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase(service: LoadingRecipeSections()),
            fetchSavedFoodsUseCase: FetchSavedFoodsUseCase(
                foodEntryRepository: FoodEntryRepository(coreDataStack: CoreDataStack(inMemory: true))
            ),
            voiceRecorder: LoadingVoiceRecorder(),
            transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase(voiceFoodTranscriptionService: LoadingVoiceTranscription())
        )
        return (model, useCase)
    }

    private func product(_ id: String, name: String) -> FoodProduct {
        FoodProduct(id: UUID(), externalId: id, name: name, brand: nil, kind: .product,
                    imageURL: nil, calories: 20, protein: 1, carbs: 4, fats: 0,
                    amount: 100, unit: "g", source: .catalog, foodType: .product)
    }

    private func assertEventually(file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(condition(), file: file, line: line)
    }

    private func drainMainActor() async {
        for _ in 0..<20 { await Task.yield() }
    }
}

/// Intentionally ignores cancellation, as a cached or already received network response may do.
@MainActor
private final class LoadingResponseGate {
    private var continuation: CheckedContinuation<[FoodProduct], Error>?
    private var result: Result<[FoodProduct], Error>?
    private(set) var isWaiting = false
    private(set) var didReturn = false

    func wait() async throws -> [FoodProduct] {
        isWaiting = true
        defer { didReturn = true }
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func succeed(_ products: [FoodProduct]) { finish(.success(products)) }
    func fail() { finish(.failure(URLError(.timedOut))) }

    private func finish(_ result: Result<[FoodProduct], Error>) {
        self.result = result
        continuation?.resume(with: result)
        continuation = nil
    }
}

@MainActor
private final class LoadingSearchService: AIFoodSearching {
    let gates: [String: LoadingResponseGate]
    let catalog: [FoodProduct]
    private(set) var queries: [String] = []
    init(gates: [String: LoadingResponseGate], catalog: [FoodProduct] = []) {
        self.gates = gates
        self.catalog = catalog
    }
    func searchFoods(query: String) async throws -> [FoodProduct] {
        queries.append(query)
        return try await gates[query]?.wait() ?? []
    }
    func searchRecipes(query: String) async throws -> [Recipe] { [] }
    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] { ["vegetablesGreens": catalog] }
    func fetchCatalogSection(id: String) async throws -> [FoodProduct] { catalog }
    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        FoodSearchCatalogPage(products: [], nextOffset: 0, hasMore: false)
    }
    func enrichDetails(title: String, imageURL: URL?, source: String, kind: String) async throws -> FoodProduct? { nil }
}

private final class LoadingSpoonacularService: SpoonacularServiceProtocol {
    let productGate: LoadingResponseGate?
    init(productGate: LoadingResponseGate? = nil) { self.productGate = productGate }
    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] { try await productGate?.wait() ?? [] }
    func searchIngredients(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func searchRecipes(query: String, maxCalories: Int?, number: Int) async throws -> [Recipe] { [] }
    func recipeDetails(id: String) async throws -> Recipe { throw URLError(.badServerResponse) }
    func ingredientDetails(id: String, amount: Double, unit: String) async throws -> FoodProduct { throw URLError(.badServerResponse) }
    func productDetails(id: String) async throws -> FoodProduct { throw URLError(.badServerResponse) }
    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct { throw BarcodeLookupError.notFound }
}

private final class LoadingOpenFoodFacts: OpenFoodFactsSearching {
    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func searchCategory(tag: String, number: Int) async throws -> [FoodProduct] { [] }
    func lookup(barcode: String) async throws -> BarcodeProduct { throw BarcodeLookupError.notFound }
}

private final class LoadingTextAnalysis: TextFoodAnalysisServiceProtocol {
    func analyze(text: String, mealType: MealType, userContext: AIAssistantUserContext?) async throws -> FoodPhotoAnalysis {
        throw FoodPhotoAnalysisError.invalidResponse
    }
}

@MainActor
private final class LoadingRecipeSections: RecipeSectionsFetching {
    func fetchSections(locale: String) async throws -> [RecipeBrowseSection] { [] }
    func fetchSectionPage(id: RecipeBrowseSectionKind, locale: String, offset: Int, limit: Int) async throws -> RecipeSectionPage {
        RecipeSectionPage(recipes: [], nextOffset: 0, hasMore: false)
    }
}

private final class LoadingVoiceRecorder: VoiceFoodAudioRecording {
    var isRecording = false
    var onPartialTranscript: ((String) -> Void)?
    var onUtteranceFinal: (() -> Void)?
    func requestPermission() async -> Bool { false }
    func startRecording() throws {}
    func stopRecording() throws -> Data { Data() }
    func cancelRecording() {}
    func normalizedPower() -> CGFloat { 0 }
}

private final class LoadingVoiceTranscription: VoiceFoodTranscriptionServiceProtocol {
    func transcribe(audioData: Data, mimeType: String) async throws -> VoiceFoodTranscription {
        VoiceFoodTranscription(text: "", language: nil, model: nil)
    }
    func analyze(audioData: Data, mimeType: String, mealType: MealType, userContext: AIAssistantUserContext?) async throws -> VoiceFoodAnalysis {
        throw FoodPhotoAnalysisError.invalidResponse
    }
}
