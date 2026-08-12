import Foundation

struct DailyDiarySummary: Equatable {
    let date: Date
    let foodEntries: [FoodEntry]
    let waterEntries: [WaterEntry]
    let workouts: [WorkoutEntry]
    let waterMilliliters: Double
    let goals: UserGoals

    var totalCalories: Double {
        foodEntries.reduce(0) { $0 + $1.calories }
    }

    var totalProtein: Double {
        foodEntries.reduce(0) { $0 + $1.protein }
    }

    var totalCarbs: Double {
        foodEntries.reduce(0) { $0 + $1.carbs }
    }

    var totalFats: Double {
        foodEntries.reduce(0) { $0 + $1.fats }
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
        workouts.reduce(0) { $0 + $1.caloriesBurned }
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
            fiber: foodEntries.reduce(0) { $0 + $1.fiber },
            sugar: foodEntries.reduce(0) { $0 + $1.sugar },
            sodium: foodEntries.reduce(0) { $0 + $1.sodium }
        )
    }

    func entries(for mealType: MealType) -> [FoodEntry] {
        foodEntries.filter { $0.mealType == mealType }
    }
}
