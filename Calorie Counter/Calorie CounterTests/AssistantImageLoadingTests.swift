import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class AssistantImageLoadingTests: XCTestCase {
    private var session: URLSession!
    private var loader: RemoteImageLoader!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AssistantImageURLProtocol.self]
        configuration.urlCache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
        session = URLSession(configuration: configuration)
        loader = RemoteImageLoader(session: session, retryDelayNanoseconds: 0)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        AssistantImageURLProtocol.handler = nil
        loader = nil
        session = nil
        super.tearDown()
    }

    func testSearchPhotoSpinnerStopsOnSuccessFailureAndCachedImages() async throws {
        func descendants(_ view: UIView) -> [UIView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        for status in [200, 404] {
            let data = makePNG()
            AssistantImageURLProtocol.handler = { _ in (status, [:], data) }
            let url = URL(string: "https://example.com/search-\(status).png")!
            let product = FoodProduct(id: UUID(), externalId: "photo-test", name: "Eggs", brand: nil,
                                      kind: .recipe, imageURL: url, calories: 100,
                                      protein: 10, carbs: 2, fats: 5, source: .spoonacular)
            let item = FoodSearchItem(id: product.id, title: product.name, subtitle: "",
                                      imageURL: url, imageData: nil, product: product)
            let row = FoodSearchResultRowView()
            row.configure(item, showsSeparator: false, imageLoader: loader)
            let spinner = try XCTUnwrap(descendants(row).compactMap { $0 as? UIActivityIndicatorView }.first)
            XCTAssertTrue(spinner.isAnimating)
            for _ in 0..<100 where spinner.isAnimating {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTAssertFalse(spinner.isAnimating)
            XCTAssertTrue(spinner.isHidden)
            let photo = try XCTUnwrap(row.value(forKey: "photoImageView") as? UIImageView)
            XCTAssertNotNil(photo.image)
            XCTAssertEqual(photo.image?.isSymbolImage, status != 200)
            if status == 200 {
                row.configure(item, showsSeparator: false, imageLoader: loader)
                XCTAssertFalse(spinner.isAnimating, "Cached image must finish synchronously")
            }
        }
    }

    func testSearchSkeletonCancelsPhotoSpinnerAndIgnoresOldCompletion() async throws {
        func descendants(_ view: UIView) -> [UIView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let data = makePNG()
        AssistantImageURLProtocol.handler = { _ in (200, [:], data) }
        let url = URL(string: "https://example.com/old-search.png")!
        let product = FoodProduct(id: UUID(), externalId: "old-photo", name: "Eggs", brand: nil,
                                  kind: .recipe, imageURL: url, calories: 100,
                                  protein: 10, carbs: 2, fats: 5, source: .spoonacular)
        let item = FoodSearchItem(id: product.id, title: product.name, subtitle: "",
                                  imageURL: url, imageData: nil, product: product)
        let row = FoodSearchResultRowView()
        row.configure(item, showsSeparator: false, imageLoader: loader)
        let spinner = try XCTUnwrap(descendants(row).compactMap { $0 as? UIActivityIndicatorView }.first)
        XCTAssertTrue(spinner.isAnimating)
        row.showSkeleton(showsSeparator: false)
        XCTAssertFalse(spinner.isAnimating)
        _ = await loader.fetch(url)
        let photo = try XCTUnwrap(row.value(forKey: "photoImageView") as? UIImageView)
        XCTAssertNil(photo.image)
        XCTAssertTrue(row.isSkeleton)
    }

    func testBrothImageSkipsLegacyCubeURL() async throws {
        let fallback = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Курячий бульйон"))
        let imageData = makePNG()
        var requested: [URL] = []
        AssistantImageURLProtocol.handler = { request in
            requested.append(try XCTUnwrap(request.url))
            return (200, [:], imageData)
        }
        let image = await loader.fetch(URL(string: "https://example.com/stock-cube.jpg"), fallbackURL: fallback)
        XCTAssertNotNil(image)
        XCTAssertEqual(requested, [fallback])
        XCTAssertTrue(fallback.absoluteString.contains("v=broth-2"))
        XCTAssertFalse(AIAssistantAPIConfiguration.isPreparedBroth("бульйонний кубик"))
        XCTAssertFalse(AIAssistantAPIConfiguration.isPreparedBroth("chicken stock powder"))
    }

    func testPendingImageIsRetriedUntilReadyAndCached() async throws {
        let imageData = makePNG()
        var requests = 0
        AssistantImageURLProtocol.handler = { request in
            requests += 1
            XCTAssertEqual(request.cachePolicy, .useProtocolCachePolicy)
            return requests == 1 ? (202, [:], Data()) : (200, [:], imageData)
        }
        let url = try XCTUnwrap(URL(string: "https://assistant.chatte.workers.dev/v1/generated-images/12345678-1234-4234-a234-123456789012"))
        let image = await loader.fetch(url)
        XCTAssertNotNil(image)
        XCTAssertEqual(requests, 2)
        let cached = await loader.fetch(url)
        XCTAssertNotNil(cached)
        XCTAssertEqual(requests, 2)
    }

    func testNamedImageForLegacyEntryAlsoWaitsForReady() async throws {
        let imageData = makePNG()
        let url = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов & рис"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first?.value, "Плов & рис")
        var requests = 0
        AssistantImageURLProtocol.handler = { _ in
            requests += 1
            return requests < 3 ? (202, [:], Data()) : (200, [:], imageData)
        }
        let image = await loader.fetch(url)
        XCTAssertNotNil(image)
        XCTAssertEqual(requests, 3)
    }

    func testFailedImageJobStopsRetrying() async throws {
        var requests = 0
        AssistantImageURLProtocol.handler = { _ in
            requests += 1
            return (404, ["x-image-status": "failed"], Data())
        }
        let url = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        let image = await loader.fetch(url)
        XCTAssertNil(image)
        XCTAssertEqual(requests, 1)
    }

    func testBrokenPhotoUsesNamedFallbackAndCompletes() async throws {
        let imageData = makePNG()
        let fallback = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        var requests: [URL] = []
        AssistantImageURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            requests.append(url)
            return url == fallback ? (200, [:], imageData) : (403, [:], Data())
        }
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        let completed = expectation(description: "Fallback image is displayed")
        loader.display(URL(string: "https://example.com/broken.jpg"), in: imageView,
                       placeholder: nil, fallbackURL: fallback) { success in
            XCTAssertTrue(success)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 3)
        XCTAssertNotNil(imageView.image)
        XCTAssertEqual(requests.map(\.path), ["/broken.jpg", "/v1/food/image"])
    }

    func testLocalImageDoesNotStartNetworkLookup() {
        AssistantImageURLProtocol.handler = { _ in
            XCTFail("Local image must be preserved")
            return (500, [:], Data())
        }
        let imageView = UIImageView()
        var completed = false
        loader.display(nil, data: makePNG(), in: imageView, placeholder: nil,
                       fallbackURL: AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов")) { success in
            completed = success
        }
        XCTAssertTrue(completed)
        XCTAssertNotNil(imageView.image)
    }

    func testMissingGeneratedImageImmediatelyUsesNameRecovery() async throws {
        let imageData = makePNG()
        let fallback = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        let missing = URL(string: "https://assistant.chatte.workers.dev/v1/generated-images/12345678-1234-4234-a234-123456789012")!
        var paths: [String] = []
        AssistantImageURLProtocol.handler = { request in
            paths.append(request.url!.path)
            return request.url == missing ? (404, [:], Data()) : (200, [:], imageData)
        }
        let completed = expectation(description: "Missing image recovers immediately")
        let imageView = UIImageView()
        loader.display(missing, in: imageView, placeholder: nil, fallbackURL: fallback) { success in
            XCTAssertTrue(success)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(paths, [missing.path, fallback.path])
    }

    func testUnavailableStorageStopsAfterThreeAttemptsAndCompletesWithPlaceholder() async throws {
        var requests = 0
        AssistantImageURLProtocol.handler = { _ in
            requests += 1
            return (503, [:], Data())
        }
        let imageView = UIImageView()
        let placeholder = UIImage(systemName: "fork.knife")
        let completed = expectation(description: "Unavailable service stops loading")
        loader.display(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"),
                       in: imageView, placeholder: placeholder) { success in
            XCTAssertFalse(success)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertEqual(requests, 3)
        XCTAssertEqual(imageView.image, placeholder)
    }

    func testPendingImageHasFinitePollingAndFailureCooldown() async throws {
        var requests = 0
        AssistantImageURLProtocol.handler = { _ in
            requests += 1
            return (202, ["cache-control": "no-store"], Data())
        }
        let url = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        let image = await loader.fetch(url)
        XCTAssertNil(image)
        XCTAssertEqual(requests, 12)
        let retry = await loader.fetch(url)
        XCTAssertNil(retry)
        XCTAssertEqual(requests, 12)
    }

    func testRetryAfterCannotExtendTheLoadingDeadline() async throws {
        var requests = 0
        AssistantImageURLProtocol.handler = { _ in
            requests += 1
            return (202, ["Retry-After": "120"], Data())
        }
        let url = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        let started = Date()
        let image = await loader.fetch(url)
        XCTAssertNil(image)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
        XCTAssertEqual(requests, 1)
    }

    func testRepeatedTimeoutsStopAfterThreeAttempts() async throws {
        var requests = 0
        AssistantImageURLProtocol.handler = { request in
            requests += 1
            XCTAssertLessThanOrEqual(request.timeoutInterval, 26)
            throw URLError(.timedOut)
        }
        let url = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        let image = await loader.fetch(url)
        XCTAssertNil(image)
        XCTAssertEqual(requests, 3)
    }

    func testConcurrentRowsReuseTheSameDownload() async throws {
        let imageData = makePNG()
        var requests = 0
        AssistantImageURLProtocol.handler = { _ in
            requests += 1
            return (200, [:], imageData)
        }
        let url = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        async let first = loader.fetch(url)
        async let second = loader.fetch(url)
        async let third = loader.fetch(url)
        let images = await [first, second, third]
        XCTAssertTrue(images.allSatisfy { $0 != nil })
        XCTAssertEqual(requests, 1)
    }

    func testReadyImageSurvivesRecreatingTheLoaderThroughURLCache() async throws {
        let imageData = makePNG()
        var requests = 0
        AssistantImageURLProtocol.handler = { _ in
            requests += 1
            return (200, ["Cache-Control": "public, max-age=2592000"], imageData)
        }
        let url = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        let first = await loader.fetch(url)
        XCTAssertNotNil(first)
        let anotherLoader = RemoteImageLoader(session: session)
        let restored = await anotherLoader.fetch(url)
        XCTAssertNotNil(restored)
        XCTAssertEqual(requests, 1)
    }

    func testNoStoreImageIsNotPersisted() async throws {
        let imageData = makePNG()
        var requests = 0
        AssistantImageURLProtocol.handler = { _ in
            requests += 1
            return (200, ["Cache-Control": "no-store"], imageData)
        }
        let url = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        _ = await loader.fetch(url)
        _ = await RemoteImageLoader(session: session).fetch(url)
        XCTAssertEqual(requests, 2)
    }

    private func makePNG() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    func testDiaryRowRecoversMissingPhoto() async throws {
        try await verifyDiaryPhotoRecovery(originalURL: nil)
    }

    func testDiaryRowRecoversBrokenPhoto() async throws {
        try await verifyDiaryPhotoRecovery(originalURL: URL(string: "https://example.com/missing.jpg"))
    }

    func testRecipeDetailsRecoverMissingPhoto() async throws {
        try await verifyRecipePhotoRecovery(originalURL: nil)
    }

    func testRecipeDetailsRecoverBrokenPhoto() async throws {
        try await verifyRecipePhotoRecovery(originalURL: URL(string: "https://example.com/missing.jpg"))
    }

    private func verifyDiaryPhotoRecovery(originalURL: URL?) async throws {
        let fallback = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        let data = makePNG()
        var urls: [URL] = []
        AssistantImageURLProtocol.handler = { request in
            urls.append(request.url!)
            return request.url == fallback ? (200, [:], data) : (404, [:], Data())
        }
        let row = FoodItemRowView()
        row.configure(HomeFoodItem(id: UUID(), name: "Плов", detailText: "300г · 520 ккал",
                                  isEaten: false, imageURL: originalURL, imageData: nil), imageLoader: loader)
        func descendants(_ view: UIView) -> [UIView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let photo = try XCTUnwrap(descendants(row).compactMap { $0 as? UIImageView }.first)
        for _ in 0..<100 where photo.image == nil || photo.image?.isSymbolImage == true {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNotNil(photo.image)
        XCTAssertFalse(photo.image?.isSymbolImage ?? true)
        XCTAssertEqual(urls, [originalURL, fallback].compactMap { $0 })
    }

    func testRecipeDetailsReuseSuccessfulResponseAndCoalesceConcurrentRequests() async throws {
        var count = 0
        AssistantImageURLProtocol.handler = { _ in
            count += 1
            return (200, [:], Data(#"{"id":123,"title":"Recipe","extendedIngredients":[],"analyzedInstructions":[]}"#.utf8))
        }
        let service = SpoonacularService(session: session)
        async let first = service.recipeDetails(id: "123")
        async let second = service.recipeDetails(id: "123")
        let (a, b) = try await (first, second)
        let reopened = try await service.recipeDetails(id: "123")
        XCTAssertEqual(a, b)
        XCTAssertEqual(reopened, a)
        XCTAssertEqual(count, 1)
    }

    func testRecipeDetailsDoesNotCacheFailedResponse() async throws {
        var count = 0
        AssistantImageURLProtocol.handler = { _ in
            count += 1
            if count == 1 { return (404, [:], Data()) }
            return (200, [:], Data(#"{"id":456,"title":"Recipe","extendedIngredients":[],"analyzedInstructions":[]}"#.utf8))
        }
        let service = SpoonacularService(session: session)
        do {
            _ = try await service.recipeDetails(id: "456")
            XCTFail("Expected request failure")
        } catch {}
        let recovered = try await service.recipeDetails(id: "456")
        XCTAssertEqual(recovered.title, "Recipe")
        XCTAssertEqual(count, 2)
    }

    private func verifyRecipePhotoRecovery(originalURL: URL?) async throws {
        let harness = TestHarness()
        let fallback = try XCTUnwrap(AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        let data = makePNG()
        var urls: [URL] = []
        AssistantImageURLProtocol.handler = { request in
            urls.append(request.url!)
            return request.url == fallback ? (200, [:], data) : (404, [:], Data())
        }
        let recipe = Recipe(id: UUID(), externalId: nil, title: "Плов", summary: nil,
                            imageURL: originalURL, readyInMinutes: 30, servings: 1,
                            calories: 520, protein: 18, carbs: 65, fats: 20,
                            ingredients: [RecipeIngredient(id: "rice", name: "Rice", amount: 100, unit: "g")],
                            steps: ["Cook rice"], sourceName: "AI")
        let model = RecipeDetailViewModel(
            recipe: recipe,
            searchRecipesUseCase: SearchRecipesUseCase(spoonacularService: SpoonacularService(session: session),
                                                       aiFoodSearchService: AIFoodSearchService(session: session)),
            recipeRepository: harness.recipes, aiAssistantService: AIAssistantService(session: session),
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(foodEntryRepository: harness.food,
                waterEntryRepository: harness.water, userGoalsRepository: harness.goals, workoutEntryRepository: harness.workout),
            imageLoader: loader
        )
        let completed = expectation(description: "Recipe hero photo recovered")
        model.heroImage.bind { image in
            if image != nil { completed.fulfill() }
        }
        model.viewDidLoad()
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertNotNil(model.heroImage.value)
        XCTAssertEqual(urls, [originalURL, fallback].compactMap { $0 })
    }
}

private final class AssistantImageURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (status, headers, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
