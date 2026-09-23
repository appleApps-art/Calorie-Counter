import Foundation
import WidgetKit

/// Publishes the diary to everything that lives outside the app: the home screen widget and the
/// Live Activity both read the same snapshot.
final class WidgetSnapshotController {
    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let evaluateStreakUseCase: EvaluateStreakUseCase
    private let liveActivityController: LiveActivityController

    init(
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        evaluateStreakUseCase: EvaluateStreakUseCase,
        liveActivityController: LiveActivityController
    ) {
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.evaluateStreakUseCase = evaluateStreakUseCase
        self.liveActivityController = liveActivityController
    }

    func refresh() {
        guard let summary = try? fetchDailyDiaryUseCase.execute() else { return }
        let streak = (try? evaluateStreakUseCase.execute())?.current ?? 0
        let snapshot = WidgetDiarySnapshot(summary: summary, streakDays: streak)
        WidgetDiarySnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.diary)
        liveActivityController.refresh(snapshot: snapshot)
    }

    func endLiveActivity() {
        liveActivityController.endAll()
    }
}

private extension WidgetDiarySnapshot {
    init(summary: DailyDiarySummary, streakDays: Int) {
        var mealCalories: [String: Double] = [:]
        for meal in MealType.allCases {
            mealCalories[meal.rawValue] = summary.eatenEntries
                .filter { $0.mealType == meal }
                .reduce(0) { $0 + $1.calories }
        }
        self.init(
            remainingCalories: summary.remainingCalories,
            calorieTarget: summary.goals.calorieTarget,
            eatenCalories: summary.totalCalories,
            protein: summary.totalProtein,
            proteinTarget: summary.goals.proteinTarget,
            carbs: summary.totalCarbs,
            carbsTarget: summary.goals.carbsTarget,
            fats: summary.totalFats,
            fatsTarget: summary.goals.fatsTarget,
            waterMilliliters: summary.waterMilliliters,
            waterTargetMilliliters: summary.goals.waterTargetMilliliters,
            mealCalories: mealCalories,
            streakDays: streakDays
        )
    }
}
