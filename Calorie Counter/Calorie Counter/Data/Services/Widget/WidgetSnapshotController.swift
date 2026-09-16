import Foundation
import WidgetKit

final class WidgetSnapshotController {
    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase

    init(fetchDailyDiaryUseCase: FetchDailyDiaryUseCase) {
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
    }

    func refresh() {
        guard let summary = try? fetchDailyDiaryUseCase.execute() else { return }
        WidgetDiarySnapshotStore.save(WidgetDiarySnapshot(summary: summary))
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.diary)
    }
}

private extension WidgetDiarySnapshot {
    init(summary: DailyDiarySummary) {
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
            waterTargetMilliliters: summary.goals.waterTargetMilliliters
        )
    }
}
