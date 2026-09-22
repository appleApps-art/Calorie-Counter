import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class RecipeDetailChromeTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testTheTabPillIsDrawnOnTheFirstLayoutPass() throws {
        let controller = present(makeRecipe())

        let track = try XCTUnwrap(controller.value(forKey: "tabTrack") as? UIView)
        let fill = try XCTUnwrap(track.subviews.first { $0.subviews.count == 1 && $0.layer.cornerRadius > 0 })
        let pill = try XCTUnwrap(fill.subviews.first)
        XCTAssertGreaterThan(track.bounds.width, 0)
        XCTAssertEqual(fill.frame, track.bounds, "The grey track must cover the tabs before anything else loads")
        XCTAssertGreaterThan(pill.frame.width, 4, "The teal pill behind the selected tab must be visible")
        XCTAssertLessThanOrEqual(pill.frame.maxX, fill.bounds.maxX + 0.5)
    }

    func testMetaChipsStayOnOneLineAndScrollInstead() throws {
        let controller = present(makeRecipe())

        let chips = try XCTUnwrap(controller.value(forKey: "chipsStack") as? UIStackView)
        XCTAssertTrue(chips.superview is UIScrollView, "The chip row scrolls sideways")
        let buttons = chips.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, 3)
        let heights = buttons.map(\.bounds.height)
        let shortest = try XCTUnwrap(heights.min())
        XCTAssertGreaterThan(shortest, 0)
        heights.forEach { height in
            XCTAssertEqual(height, shortest, accuracy: 1, "A chip wrapped onto a second line")
        }
    }

    func testTheChipRowKeepsTheHeightOfItsChipsAfterLaterLayoutPasses() throws {
        let controller = present(makeRecipe())
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        controller.view.setNeedsLayout()
        window?.layoutIfNeeded()

        let chips = try XCTUnwrap(controller.value(forKey: "chipsStack") as? UIStackView)
        let scroll = try XCTUnwrap(chips.superview as? UIScrollView)
        let tallest = try XCTUnwrap(chips.arrangedSubviews.map(\.bounds.height).max())
        XCTAssertEqual(scroll.bounds.height, tallest, accuracy: 1, "The chip row must not stretch the card")
    }

    func testASpinnerSitsOnThePhotoUntilItArrives() async throws {
        HeldImageProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HeldImageProtocol.self]
        let loader = RemoteImageLoader(session: URLSession(configuration: configuration), retryDelayNanoseconds: 1_000_000)
        var recipe = makeRecipe()
        recipe.imageURL = URL(string: "https://images.example/salmon.jpg")
        let controller = present(recipe, imageLoader: loader)

        let photo = try XCTUnwrap(controller.value(forKey: "photoImageView") as? UIImageView)
        let spinner = try XCTUnwrap(photo.subviews.compactMap { $0 as? UIActivityIndicatorView }.first)
        let started = await waitUntil { spinner.isAnimating }
        XCTAssertTrue(started, "The empty photo frame shows a spinner while the photo loads")
        XCTAssertEqual(spinner.style, .medium)

        HeldImageProtocol.release()
        let finished = await waitUntil { photo.image != nil && !spinner.isAnimating }
        XCTAssertTrue(finished, "The spinner goes away once the photo is shown")
    }

    func testTheSpinnerStopsWhenThePhotoCannotLoad() async throws {
        HeldImageProtocol.reset()
        HeldImageProtocol.fails = true
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HeldImageProtocol.self]
        let loader = RemoteImageLoader(
            session: URLSession(configuration: configuration),
            retryDelayNanoseconds: 1_000_000,
            maximumWait: 0.5,
            failureCooldown: 0
        )
        var recipe = makeRecipe()
        recipe.imageURL = URL(string: "https://images.example/missing.jpg")
        let controller = present(recipe, imageLoader: loader)
        HeldImageProtocol.release()

        let photo = try XCTUnwrap(controller.value(forKey: "photoImageView") as? UIImageView)
        let spinner = try XCTUnwrap(photo.subviews.compactMap { $0 as? UIActivityIndicatorView }.first)
        let stopped = await waitUntil(timeout: 5) { !spinner.isAnimating }
        XCTAssertTrue(stopped, "A failed photo must not leave a spinner running forever")
        XCTAssertNil(photo.image)
    }

    private func waitUntil(timeout: TimeInterval = 3, _ condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    // MARK: - Helpers

    private func present(_ recipe: Recipe, imageLoader: RemoteImageLoader = .shared) -> RecipeDetailViewController {
        let harness = TestHarness()
        let viewModel = RecipeDetailViewModel(
            recipe: recipe,
            searchRecipesUseCase: SearchRecipesUseCase(
                spoonacularService: MealPlanFakeSpoonacular(),
                aiFoodSearchService: MealPlanFakeAISearch()
            ),
            recipeRepository: harness.recipes,
            aiAssistantService: AIAssistantService(),
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                foodEntryRepository: harness.food,
                waterEntryRepository: harness.water,
                userGoalsRepository: harness.goals,
                workoutEntryRepository: harness.workout
            ),
            imageLoader: imageLoader
        )
        let controller = RecipeDetailViewController(viewModel: viewModel)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        // One pass, as on screen: the controller lays out before the views nested in its scroll view.
        window.layoutIfNeeded()
        self.window = window
        return controller
    }

    private func makeRecipe() -> Recipe {
        Recipe(
            id: UUID(),
            externalId: nil,
            title: "Лосось із броколі та авокадо",
            summary: "Легка вечеря.",
            imageURL: nil,
            readyInMinutes: 30,
            servings: 1,
            calories: 295,
            protein: 24,
            carbs: 9,
            fats: 18,
            ingredients: [RecipeIngredient(id: "1", name: "лосось", amount: 120, unit: "g", originalText: nil)],
            steps: ["Запечіть лосось.", "Додайте броколі."],
            sourceName: "Bity AI",
            origin: .openAI,
            hasCompleteNutrition: true
        )
    }
}

/// Holds image requests until the test lets them through, so the loading state can be observed.
private final class HeldImageProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var released = false
    private static var waiting: [HeldImageProtocol] = []
    static var fails = false

    static func reset() {
        lock.withLock {
            released = false
            waiting = []
            fails = false
        }
    }

    static func release() {
        let pending = lock.withLock { () -> [HeldImageProtocol] in
            released = true
            defer { waiting = [] }
            return waiting
        }
        pending.forEach { $0.respond() }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let respondNow = Self.lock.withLock { () -> Bool in
            if Self.released { return true }
            Self.waiting.append(self)
            return false
        }
        if respondNow { respond() }
    }

    override func stopLoading() {}

    private func respond() {
        guard let url = request.url else { return }
        if Self.fails {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: image)
        client?.urlProtocolDidFinishLoading(self)
    }
}
