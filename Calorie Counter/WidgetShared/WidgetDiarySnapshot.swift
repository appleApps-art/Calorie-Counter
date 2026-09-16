import Foundation

struct WidgetDiarySnapshot: Codable, Equatable {
    var remainingCalories: Double
    var calorieTarget: Double
    var eatenCalories: Double
    var protein: Double
    var proteinTarget: Double
    var carbs: Double
    var carbsTarget: Double
    var fats: Double
    var fatsTarget: Double
    var waterMilliliters: Double
    var waterTargetMilliliters: Double

    var calorieProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(1, max(0, eatenCalories / calorieTarget))
    }

    var isOverCalorieTarget: Bool {
        eatenCalories > calorieTarget && calorieTarget > 0
    }

    static let empty = WidgetDiarySnapshot(
        remainingCalories: 0,
        calorieTarget: 0,
        eatenCalories: 0,
        protein: 0,
        proteinTarget: 0,
        carbs: 0,
        carbsTarget: 0,
        fats: 0,
        fatsTarget: 0,
        waterMilliliters: 0,
        waterTargetMilliliters: 0
    )

    static let placeholder = WidgetDiarySnapshot(
        remainingCalories: 1240,
        calorieTarget: 2000,
        eatenCalories: 760,
        protein: 48,
        proteinTarget: 150,
        carbs: 72,
        carbsTarget: 200,
        fats: 22,
        fatsTarget: 65,
        waterMilliliters: 900,
        waterTargetMilliliters: 2500
    )
}
