import Foundation

struct DailyDiarySummary: Equatable {
    let date: Date
    let foodEntries: [FoodEntry]
    let waterEntries: [WaterEntry]
    let workouts: [WorkoutEntry]
    let waterMilliliters: Double
    let goals: UserGoals
    var healthActivity: HealthDailyActivity? = nil

    var eatenEntries: [FoodEntry] {
        foodEntries.filter(\.isEaten)
    }

    var totalCalories: Double {
        eatenEntries.reduce(0) { $0 + $1.calories }
    }

    var totalProtein: Double {
        eatenEntries.reduce(0) { $0 + $1.protein }
    }

    var totalCarbs: Double {
        eatenEntries.reduce(0) { $0 + $1.carbs }
    }

    var totalFats: Double {
        eatenEntries.reduce(0) { $0 + $1.fats }
    }

    var totalFiber: Double {
        eatenEntries.reduce(0) { $0 + $1.fiber }
    }

    var totalSugar: Double {
        eatenEntries.reduce(0) { $0 + $1.sugar }
    }

    var totalSodium: Double {
        eatenEntries.reduce(0) { $0 + $1.sodium }
    }

    var remainingCalories: Double {
        goals.calorieTarget - totalCalories
    }

    var remainingProtein: Double {
        goals.proteinTarget - totalProtein
    }

    var remainingCarbs: Double {
        goals.carbsTarget - totalCarbs
    }

    var remainingFats: Double {
        goals.fatsTarget - totalFats
    }

    var remainingWaterMilliliters: Double {
        goals.waterTargetMilliliters - waterMilliliters
    }

    var burnedCalories: Double {
        ActivityEnergyCalculator.total(workouts: workouts, healthActivity: healthActivity)
    }

    var netCalories: Double {
        totalCalories - burnedCalories
    }

    var nutritionFacts: FoodNutritionFacts {
        NutritionFactsCalculator.facts(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fats: totalFats,
            fiber: totalFiber,
            sugar: totalSugar,
            sodium: totalSodium
        )
    }

    func entries(for mealType: MealType) -> [FoodEntry] {
        foodEntries.filter { $0.mealType == mealType }
    }
}
