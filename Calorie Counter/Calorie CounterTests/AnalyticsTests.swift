import XCTest
@testable import Calorie_Counter

@MainActor
final class AnalyticsTests: XCTestCase {
    private let recorder = RecordingDestination()

    override func setUp() {
        super.setUp()
        Analytics.hub.base = recorder
    }

    override func tearDown() {
        Analytics.hub.base = NoOpAnalyticsService()
        NetworkMonitor.shared.update(isOnline: true)
        super.tearDown()
    }

    // MARK: - Path through the app

    func testEveryScreenViewSaysWhereTheUserCameFromAndHowLongTheyStayed() {
        let hub = AnalyticsHub()
        let start = Date()
        _ = hub.properties(for: .screenViewed(.home), now: start)
        let search = hub.properties(for: .screenViewed(.foodSearch), now: start.addingTimeInterval(42))

        XCTAssertEqual(search["screen"] as? String, "food_search")
        XCTAssertEqual(search["previous_screen"] as? String, "home")
        XCTAssertEqual(search["seconds_on_previous_screen"] as? Int, 42)
        XCTAssertEqual(search["screen_index"] as? Int, 2)
    }

    func testEveryActionIsPlacedOnTheScreenItHappenedOn() {
        let hub = AnalyticsHub()
        _ = hub.properties(for: .screenViewed(.recipeDetail))
        let saved = hub.properties(for: .recipeSaved(saved: true))
        XCTAssertEqual(saved["screen"] as? String, "recipe_detail")
        XCTAssertEqual(saved["saved"] as? Bool, true)
        XCTAssertEqual(saved["is_offline"] as? Bool, false)

        NetworkMonitor.shared.update(isOnline: false)
        XCTAssertEqual(hub.properties(for: .recipeShared)["is_offline"] as? Bool, true)
    }

    func testClosingASheetPutsTheUserBackOnTheScreenUnderneath() {
        let hub = AnalyticsHub()
        _ = hub.properties(for: .screenViewed(.home))
        _ = hub.properties(for: .screenViewed(.quickLog))
        // iOS does not show Home again when a sheet closes; the dismissal does.
        hub.journey.leave("quick_log")
        XCTAssertEqual(hub.properties(for: .waterRemoved)["screen"] as? String, "home")
    }

    func testReturningFromAPushedScreenStillSaysWhereTheUserWas() {
        let hub = AnalyticsHub()
        let start = Date()
        _ = hub.properties(for: .screenViewed(.home), now: start)
        _ = hub.properties(for: .screenViewed(.foodSearch), now: start.addingTimeInterval(5))
        // The closed screen ends before the one underneath shows again.
        hub.journey.leave("food_search", at: start.addingTimeInterval(25))
        let home = hub.properties(for: .screenViewed(.home), now: start.addingTimeInterval(26))
        XCTAssertEqual(home["previous_screen"] as? String, "food_search")
        XCTAssertEqual(home["seconds_on_previous_screen"] as? Int, 20)
    }

    func testGoingBackToAnEarlierScreenLeavesEverythingAboveIt() {
        let hub = AnalyticsHub()
        for screen in [AnalyticsScreen.recipes, .recipeSection, .recipeDetail] {
            _ = hub.properties(for: .screenViewed(screen))
        }
        let back = hub.properties(for: .screenViewed(.recipes))
        XCTAssertEqual(back["previous_screen"] as? String, "recipe_detail")
        hub.journey.leave("recipes")
        XCTAssertNil(hub.journey.currentScreen, "Nothing from the abandoned branch is left behind")
    }

    // MARK: - Launches and sessions

    func testTheVeryFirstLaunchIsReportedOnceWithItsDate() throws {
        let defaults = try isolatedDefaults()
        var now = Date(timeIntervalSince1970: 1_790_000_000)
        let lifecycle = AnalyticsLifecycle(analytics: Analytics.hub, defaults: defaults, appVersion: "1.2 (7)", now: { now })

        lifecycle.appWillEnterForeground(isColdStart: true, isExistingUser: false, snapshot: ["goal": "lose"])
        XCTAssertEqual(recorder.names, ["app_first_opened", "app_opened"])
        XCTAssertEqual(recorder.onceProperties.last?["first_app_version"] as? String, "1.2 (7)")
        XCTAssertNotNil(recorder.onceProperties.last?["first_open_date"] as? String)
        let opened = try XCTUnwrap(recorder.events.last)
        XCTAssertEqual(opened.properties["launch"] as? String, "cold")
        XCTAssertEqual(opened.properties["open_count"] as? Int, 1)
        XCTAssertEqual(recorder.userProperties.last?["goal"] as? String, "lose", "The session snapshot rides along")

        lifecycle.appDidEnterBackground()
        now = now.addingTimeInterval(3 * 3600)
        recorder.clear()
        lifecycle.appWillEnterForeground(isColdStart: false, isExistingUser: false, snapshot: [:])
        XCTAssertEqual(recorder.names, ["app_opened"], "A return is a session start, not another first launch")
        XCTAssertEqual(recorder.events.last?.properties["launch"] as? String, "warm")
        XCTAssertEqual(recorder.events.last?.properties["open_count"] as? Int, 2)
        XCTAssertEqual(recorder.events.last?.properties["hours_since_last_open"] as? Int, 3)
    }

    func testLeavingTheAppSaysOnWhichScreenAndAfterHowLong() throws {
        let defaults = try isolatedDefaults()
        var now = Date(timeIntervalSince1970: 1_790_000_000)
        let hub = AnalyticsHub()
        hub.base = recorder
        let lifecycle = AnalyticsLifecycle(analytics: hub, defaults: defaults, now: { now })
        lifecycle.appWillEnterForeground(isColdStart: true, isExistingUser: false, snapshot: [:])
        hub.track(.screenViewed(.addFoodEntry))
        now = now.addingTimeInterval(95)
        _ = hub.journey.enter("add_food_entry", at: now.addingTimeInterval(-30))

        lifecycle.appDidEnterBackground()
        let left = try XCTUnwrap(recorder.events.last)
        XCTAssertEqual(left.name, "app_backgrounded")
        XCTAssertEqual(left.properties["last_screen"] as? String, "add_food_entry")
        XCTAssertEqual(left.properties["seconds_in_foreground"] as? Int, 95)
        XCTAssertEqual(left.properties["seconds_on_last_screen"] as? Int, 30)
    }

    func testAnExistingUserIsNotCountedAsANewInstallAfterTheUpdate() throws {
        let lifecycle = AnalyticsLifecycle(analytics: Analytics.hub, defaults: try isolatedDefaults())
        lifecycle.appWillEnterForeground(isColdStart: true, isExistingUser: true, snapshot: [:])
        XCTAssertEqual(recorder.names, ["app_opened"])
        XCTAssertTrue(recorder.onceProperties.isEmpty)
    }

    // MARK: - Feature events

    func testRecognitionOutcomesSayWhyNothingCameBack() {
        func outcome(_ error: Error) -> String? {
            AnalyticsEvent.recognitionFailed("photo", error: error).properties["outcome"] as? String
        }
        XCTAssertEqual(outcome(FoodPhotoAnalysisError.noFood), "no_food")
        XCTAssertEqual(outcome(BarcodeLookupError.notFound), "not_found")
        XCTAssertEqual(outcome(NoConnectionError()), "offline")
        XCTAssertEqual(outcome(FoodPhotoAnalysisError.invalidResponse), "failed")
        XCTAssertEqual(AnalyticsEvent.recognized("photo", confidence: 0.874).properties["confidence"] as? Int, 87)
    }

    func testANewLevelAndANewBadgeAreEachReportedOnce() throws {
        let harness = TestHarness()
        let rewards = RewardsRepository(coreDataStack: harness.stack)
        let evaluate = EvaluateBadgesUseCase(
            rewardsRepository: rewards,
            foodEntryRepository: harness.food,
            waterEntryRepository: harness.water,
            weightEntryRepository: harness.weight,
            workoutEntryRepository: harness.workout,
            progressPhotoRepository: harness.photos,
            userGoalsRepository: harness.goals
        )
        let award = AwardXPUseCase(rewardsRepository: rewards, evaluateBadgesUseCase: evaluate)
        let today = Calendar.current.startOfDay(for: Date())
        for offset in 0..<7 {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: today)!
            try harness.food.save(FoodEntry(
                id: UUID(), name: "Oats", mealType: .breakfast,
                calories: 300, protein: 12, carbs: 40, fats: 8, fiber: 4, sugar: 2, sodium: 80, date: day
            ))
        }

        for _ in 0..<10 { try award.execute(kind: .food) }
        XCTAssertEqual(recorder.events.filter { $0.name == "level_reached" }.map { $0.properties["level"] as? Int }, [2])
        let unlocked = recorder.events.filter { $0.name == "badge_unlocked" }.compactMap { $0.properties["badge"] as? String }
        XCTAssertEqual(unlocked.filter { $0 == RewardBadge.mealTrackerMaster.rawValue }.count, 1)
    }

    func testEveryEventHasAStableSnakeCaseName() {
        let events: [AnalyticsEvent] = [
            .appFirstOpened(appVersion: "1"), .appBackgrounded(secondsInForeground: 1, lastScreen: nil, secondsOnLastScreen: nil),
            .onboardingStepCompleted(step: "goal", value: "lose"), .foodRecognitionFinished(method: "photo", outcome: "offline", confidence: nil),
            .recipeOpened(source: "browse", origin: "catalog"), .recipeCreateFinished(kind: "recipe", success: true, origin: "ai", seconds: 3),
            .settingChanged(name: "theme", value: "dark"), .offlineStateShown(context: "recipes_browse")
        ]
        for event in events {
            XCTAssertNotNil(event.name.range(of: "^[a-z]+(_[a-z]+)*$", options: .regularExpression), event.name)
        }
    }

    // MARK: - Helpers

    private func isolatedDefaults() throws -> UserDefaults {
        let name = "analytics-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
}

final class RecordingDestination: AnalyticsDestination {
    struct Sent {
        let name: String
        let properties: [String: Any]
    }

    private(set) var events: [Sent] = []
    private(set) var userProperties: [[String: Any]] = []
    private(set) var onceProperties: [[String: Any]] = []
    var names: [String] { events.map(\.name) }
    var deviceID: String? { nil }
    var userID: String? { nil }

    func send(eventType: String, properties: [String: Any]) { events.append(Sent(name: eventType, properties: properties)) }
    func setUserID(_ userID: String?) {}
    func setUserProperties(_ properties: [String: Any]) { userProperties.append(properties) }
    func setUserPropertiesOnce(_ properties: [String: Any]) { onceProperties.append(properties) }
    func incrementUserProperty(_ name: String, by value: Int) {}
    func clear() { events = []; userProperties = []; onceProperties = [] }
}
