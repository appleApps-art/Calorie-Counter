import XCTest
@testable import Calorie_Counter

final class LiveActivityAndDeepLinkTests: XCTestCase {
    func testMealDeepLinkRoundTripsForEveryMeal() throws {
        for meal in WidgetMealKind.allCases {
            let url = AppDeepLink.logMeal(meal).url
            XCTAssertEqual(url.scheme, AppDeepLink.scheme)
            XCTAssertEqual(AppDeepLink(url: url), .logMeal(meal))
        }
    }

    func testPlainLogLinkFallsBackToTheGenericQuickLog() throws {
        let url = try XCTUnwrap(URL(string: "bity://log"))
        XCTAssertEqual(AppDeepLink(url: url), .logFood)
    }

    func testUnknownMealFallsBackInsteadOfDroppingTheLink() throws {
        let url = try XCTUnwrap(URL(string: "bity://log?meal=brunch"))
        XCTAssertEqual(AppDeepLink(url: url), .logFood)
    }

    func testForeignSchemesAreRejected() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/log?meal=dinner"))
        XCTAssertNil(AppDeepLink(url: url))
    }

    func testEveryWidgetMealMatchesAMealTypeTheDiaryUses() {
        XCTAssertEqual(
            Set(WidgetMealKind.allCases.map(\.rawValue)),
            Set(MealType.allCases.map(\.rawValue))
        )
        for meal in WidgetMealKind.allCases {
            XCTAssertNotNil(MealType(rawValue: meal.rawValue))
        }
    }

    func testSnapshotWrittenByAnOlderBuildStillDecodes() throws {
        let legacy = """
        {"remainingCalories":240,"calorieTarget":2000,"eatenCalories":1760,"protein":90,
         "proteinTarget":150,"carbs":180,"carbsTarget":200,"fats":50,"fatsTarget":65,
         "waterMilliliters":1000,"waterTargetMilliliters":2500}
        """
        let snapshot = try JSONDecoder().decode(WidgetDiarySnapshot.self, from: Data(legacy.utf8))
        XCTAssertEqual(snapshot.streakDays, 0)
        XCTAssertEqual(snapshot.calories(for: .breakfast), 0)
        XCTAssertEqual(snapshot.eatenCalories, 1760)
    }

    func testLiveActivityStateCarriesThePerMealBreakdown() {
        let snapshot = WidgetDiarySnapshot(
            remainingCalories: 400,
            calorieTarget: 2000,
            eatenCalories: 1600,
            protein: 0, proteinTarget: 0,
            carbs: 0, carbsTarget: 0,
            fats: 0, fatsTarget: 0,
            waterMilliliters: 0, waterTargetMilliliters: 0,
            mealCalories: [
                WidgetMealKind.breakfast.rawValue: 300,
                WidgetMealKind.lunch.rawValue: 900,
                WidgetMealKind.dinner.rawValue: 400
            ],
            streakDays: 7
        )
        let state = DayActivityAttributes.ContentState(snapshot: snapshot)
        XCTAssertEqual(state.breakfastCalories, 300)
        XCTAssertEqual(state.lunchCalories, 900)
        XCTAssertEqual(state.dinnerCalories, 400)
        XCTAssertEqual(state.snacksCalories, 0)
        XCTAssertEqual(state.streakDays, 7)
        XCTAssertEqual(state.remainingCalories, 400)
        XCTAssertEqual(state.progress, 0.8, accuracy: 0.0001)
        XCTAssertFalse(state.isOverTarget)
    }

    func testGoingOverTheTargetIsReportedAsOver() {
        var state = DayActivityAttributes.ContentState.preview
        state.eatenCalories = 2400
        state.calorieTarget = 2000
        XCTAssertTrue(state.isOverTarget)
        XCTAssertEqual(state.progress, 1)
        XCTAssertEqual(state.remainingCalories, -400)
    }
}
