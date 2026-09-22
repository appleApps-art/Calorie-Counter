import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class OfflineModeTests: XCTestCase {
    override func tearDown() {
        NetworkMonitor.shared.update(isOnline: true)
        OfflineStubProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Kept answers

    func testAnAnswerSeenOnlineIsServedOffline() async throws {
        let store = OfflineResponseStore(directory: temporaryFolder())
        let monitor = NetworkMonitor()
        let request = URLRequest(url: URL(string: "https://assistant.test/v1/recipes/sections?locale=uk")!)

        let online = try await OfflineFallback.data(for: request, store: store, monitor: monitor) { Data("fresh".utf8) }
        XCTAssertEqual(online, Data("fresh".utf8))

        monitor.update(isOnline: false)
        var calledNetwork = false
        let offline = try await OfflineFallback.data(for: request, store: store, monitor: monitor) {
            calledNetwork = true
            return Data()
        }
        XCTAssertEqual(offline, Data("fresh".utf8))
        XCTAssertFalse(calledNetwork, "Offline nothing waits on the network")
    }

    func testWithNothingKeptOfflineSaysSoAtOnce() async {
        let store = OfflineResponseStore(directory: temporaryFolder())
        let monitor = NetworkMonitor()
        monitor.update(isOnline: false)
        let request = URLRequest(url: URL(string: "https://assistant.test/v1/food/search")!)
        do {
            _ = try await OfflineFallback.data(for: request, store: store, monitor: monitor) { Data("x".utf8) }
            XCTFail("Expected the offline error")
        } catch {
            XCTAssertTrue(error is NoConnectionError)
            XCTAssertEqual(error.localizedDescription, L10n.tr("offline.message"))
        }
    }

    func testAFailingServerFallsBackToTheLastGoodAnswer() async throws {
        let store = OfflineResponseStore(directory: temporaryFolder())
        let monitor = NetworkMonitor()
        let request = URLRequest(url: URL(string: "https://assistant.test/v1/recipes/sections/breakfast")!)
        _ = try await OfflineFallback.data(for: request, store: store, monitor: monitor) { Data("good".utf8) }

        let served = try await OfflineFallback.data(for: request, store: store, monitor: monitor) {
            throw URLError(.networkConnectionLost)
        }
        XCTAssertEqual(served, Data("good".utf8))
    }

    func testKeptAnswersAreKeyedByAddressAndBodyNotByTheApiKey() {
        let store = OfflineResponseStore(directory: temporaryFolder())
        var first = URLRequest(url: URL(string: "https://assistant.test/v1/food/search")!)
        first.httpMethod = "POST"
        first.httpBody = Data(#"{"query":"борщ"}"#.utf8)
        first.setValue("key-1", forHTTPHeaderField: "x-api-key")
        store.store(Data("borscht".utf8), for: first)

        var sameWithOtherKey = first
        sameWithOtherKey.setValue("key-2", forHTTPHeaderField: "x-api-key")
        XCTAssertEqual(store.data(for: sameWithOtherKey), Data("borscht".utf8))

        var otherQuery = first
        otherQuery.httpBody = Data(#"{"query":"омлет"}"#.utf8)
        XCTAssertNil(store.data(for: otherQuery))
    }

    func testTheStoreStaysWithinItsBudget() throws {
        let folder = temporaryFolder()
        let store = OfflineResponseStore(directory: folder, maxBytes: 3_000)
        for index in 0..<10 {
            store.store(Data(repeating: 1, count: 1_000), for: URLRequest(url: URL(string: "https://a.test/\(index)")!))
        }
        store.prune()
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertLessThanOrEqual(files.count, 3)
    }

    // MARK: - Services

    func testABarcodeScannedOnceIsFoundAgainOffline() async throws {
        let service = OpenFoodFactsService(session: stubSession())
        let barcode = "48\(Int.random(in: 10_000_000_000...99_999_999_999))"
        OfflineStubProtocol.handler = { _ in
            (200, Data(#"{"status":1,"product":{"product_name":"Кефір","nutriments":{"energy-kcal_100g":52}}}"#.utf8))
        }
        let first = try await service.lookup(barcode: barcode)
        XCTAssertEqual(first.name, "Кефір")

        NetworkMonitor.shared.update(isOnline: false)
        OfflineStubProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let again = try await service.lookup(barcode: barcode)
        XCTAssertEqual(again.name, "Кефір")
        XCTAssertEqual(again.caloriesPer100g, 52)
    }

    func testAnActionOnlyTheServerCanDoFailsAtOnceOffline() async {
        NetworkMonitor.shared.update(isOnline: false)
        let started = Date()
        do {
            _ = try await TextFoodAnalysisService(session: stubSession()).analyze(text: "Омлет з двох яєць")
            XCTFail("Expected the offline error")
        } catch {
            XCTAssertTrue(error.isNoConnection)
            XCTAssertEqual(error.localizedDescription, L10n.tr("offline.message"))
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 1, "No timeouts or retries without a connection")
    }

    func testAFoodCategoryOpensFromTheBuiltInCatalogOffline() async throws {
        NetworkMonitor.shared.update(isOnline: false)
        let service = AIFoodSearchService(session: stubSession(), catalogCache: URLCache(memoryCapacity: 0, diskCapacity: 0))
        let page = try await service.fetchCatalogSectionPage(id: "fruitsBerries", offset: 0, limit: 10)
        XCTAssertEqual(page.products.count, 10)
        XCTAssertTrue(page.hasMore)
    }

    func testOfflineAnUnknownFoodOpensAsAProductInsteadOfFailingTheCatalog() async throws {
        let useCase = SearchFoodProductsUseCase(
            spoonacularService: MealPlanFakeSpoonacular(),
            aiFoodSearchService: OfflineClassifier(),
            openFoodFactsService: OpenFoodFactsService(session: stubSession()),
            textFoodAnalysisService: TextFoodAnalysisService(session: stubSession())
        )
        NetworkMonitor.shared.update(isOnline: false)
        let unknown = FoodProduct(
            id: UUID(), externalId: "borscht", name: "Борщ", brand: nil, kind: .ingredient, imageURL: nil,
            calories: 60, protein: 3, carbs: 8, fats: 2, amount: 100, unit: "g", source: .openAI
        )
        let classified = try await useCase.classifyFoods([unknown])
        XCTAssertEqual(classified.first?.foodType, .product)
    }

    func testThePaywallDoesNotHoldOnboardingOffline() {
        NetworkMonitor.shared.update(isOnline: false)
        let factory = CountingPaywallFactory()
        var error: Error?
        SubscriptionCoordinator(factory: factory).presentPaywall(
            from: UIViewController(),
            placement: .onboarding,
            events: SubscriptionPaywallEvents(onError: { error = $0 })
        )
        XCTAssertTrue(error is NoConnectionError, "Onboarding continues at once")
        XCTAssertEqual(factory.requests, 0)
    }

    // MARK: - Screens

    func testARecipeSectionWithNothingKeptShowsTheOfflineState() async throws {
        NetworkMonitor.shared.update(isOnline: false)
        let viewModel = RecipeSectionViewModel(
            kind: .healthyBreakfast,
            title: "Сніданки",
            fetchBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase(service: OfflineSections())
        )
        let screen = RecipeSectionViewController(viewModel: viewModel)
        screen.loadViewIfNeeded()
        let deadline = Date().addingTimeInterval(3)
        while viewModel.isLoading.value, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let offline = try XCTUnwrap(emptyStates(in: screen.view).first { !$0.isHidden })
        XCTAssertTrue(labels(in: offline).contains(L10n.tr("offline.title")))

        NetworkMonitor.shared.update(isOnline: true)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.isLoading.value || emptyStates(in: screen.view).allSatisfy(\.isHidden),
                      "Back online the section loads again by itself")
    }

    func testTheOfflineStateOffersToTryAgain() {
        let empty = EmptyScreenView(frame: CGRect(x: 0, y: 0, width: 402, height: 600))
        var retried = false
        empty.configureOffline { retried = true }
        empty.onAction?()
        XCTAssertTrue(retried)
        XCTAssertTrue(labels(in: empty).contains(L10n.tr("offline.subtitle")))
    }

    // MARK: - Helpers

    private func temporaryFolder() -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    private func stubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func emptyStates(in root: UIView) -> [EmptyScreenView] {
        (root as? EmptyScreenView).map { [$0] } ?? root.subviews.flatMap(emptyStates)
    }

    private func labels(in root: UIView) -> [String] {
        if let label = root as? UILabel { return [label.text ?? ""] }
        return root.subviews.flatMap(labels)
    }
}

private final class OfflineStubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        do {
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private struct OfflineSections: RecipeSectionsFetching {
    func fetchSections(locale: String) async throws -> [RecipeBrowseSection] { throw NoConnectionError() }
    func fetchSectionPage(id: RecipeBrowseSectionKind, locale: String, offset: Int, limit: Int) async throws -> RecipeSectionPage {
        throw NoConnectionError()
    }
}

private final class OfflineClassifier: AIFoodSearching {
    func classifyFoods(_ products: [FoodProduct]) async throws -> [FoodProduct] { throw NoConnectionError() }
    func searchFoods(query: String) async throws -> [FoodProduct] { [] }
    func searchRecipes(query: String) async throws -> [Recipe] { [] }
    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] { [:] }
    func fetchCatalogSection(id: String) async throws -> [FoodProduct] { [] }
    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        FoodSearchCatalogPage(products: [], nextOffset: offset, hasMore: false)
    }
    func enrichDetails(title: String, imageURL: URL?, source: String, kind: String) async throws -> FoodProduct? { nil }
}

private final class CountingPaywallFactory: SubscriptionPaywallPresenting {
    var requests = 0
    func makePaywallViewController(placement: SubscriptionPlacement, events: SubscriptionPaywallEvents) async throws -> UIViewController {
        requests += 1
        return UIViewController()
    }
}
