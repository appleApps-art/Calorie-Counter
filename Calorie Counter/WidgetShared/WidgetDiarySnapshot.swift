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
    /// Eaten calories per meal, keyed by `WidgetMealKind.rawValue`.
    var mealCalories: [String: Double]
    var streakDays: Int

    var calorieProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(1, max(0, eatenCalories / calorieTarget))
    }

    var isOverCalorieTarget: Bool {
        eatenCalories > calorieTarget && calorieTarget > 0
    }

    func calories(for meal: WidgetMealKind) -> Double {
        mealCalories[meal.rawValue] ?? 0
    }

    init(
        remainingCalories: Double,
        calorieTarget: Double,
        eatenCalories: Double,
        protein: Double,
        proteinTarget: Double,
        carbs: Double,
        carbsTarget: Double,
        fats: Double,
        fatsTarget: Double,
        waterMilliliters: Double,
        waterTargetMilliliters: Double,
        mealCalories: [String: Double] = [:],
        streakDays: Int = 0
    ) {
        self.remainingCalories = remainingCalories
        self.calorieTarget = calorieTarget
        self.eatenCalories = eatenCalories
        self.protein = protein
        self.proteinTarget = proteinTarget
        self.carbs = carbs
        self.carbsTarget = carbsTarget
        self.fats = fats
        self.fatsTarget = fatsTarget
        self.waterMilliliters = waterMilliliters
        self.waterTargetMilliliters = waterTargetMilliliters
        self.mealCalories = mealCalories
        self.streakDays = streakDays
    }

    /// Snapshots written by an older build lack the meal breakdown and the streak; they decode to
    /// zeros rather than failing and blanking the widget.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remainingCalories = try container.decode(Double.self, forKey: .remainingCalories)
        calorieTarget = try container.decode(Double.self, forKey: .calorieTarget)
        eatenCalories = try container.decode(Double.self, forKey: .eatenCalories)
        protein = try container.decode(Double.self, forKey: .protein)
        proteinTarget = try container.decode(Double.self, forKey: .proteinTarget)
        carbs = try container.decode(Double.self, forKey: .carbs)
        carbsTarget = try container.decode(Double.self, forKey: .carbsTarget)
        fats = try container.decode(Double.self, forKey: .fats)
        fatsTarget = try container.decode(Double.self, forKey: .fatsTarget)
        waterMilliliters = try container.decode(Double.self, forKey: .waterMilliliters)
        waterTargetMilliliters = try container.decode(Double.self, forKey: .waterTargetMilliliters)
        mealCalories = try container.decodeIfPresent([String: Double].self, forKey: .mealCalories) ?? [:]
        streakDays = try container.decodeIfPresent(Int.self, forKey: .streakDays) ?? 0
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
        waterTargetMilliliters: 2500,
        mealCalories: [
            WidgetMealKind.breakfast.rawValue: 320,
            WidgetMealKind.lunch.rawValue: 440,
            WidgetMealKind.dinner.rawValue: 0,
            WidgetMealKind.snacks.rawValue: 0
        ],
        streakDays: 5
    )
}
