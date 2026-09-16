import Foundation

struct HomeMealItem: Equatable {
    let mealType: MealType
    let title: String
    let goalText: String
}

struct HomeWeekDay: Equatable {
    let weekday: String
    let dayNumber: String
    let isSelected: Bool
    let isToday: Bool
}

struct HomeFoodItem: Equatable {
    let id: UUID
    let name: String
    let detailText: String
    let isEaten: Bool
    let imageURL: URL?
    let imageData: Data?
}

struct HomeMealSection: Equatable {
    let mealType: MealType
    let emoji: String
    let title: String
    let caloriesText: String
    let foods: [HomeFoodItem]
}

struct HomeDisplay: Equatable {
    var dateTitle: String
    var caloriePercentText: String
    var calorieProgress: Double
    var foodValueText: String
    var remainingValueText: String
    var proteinPercentText: String
    var carbsPercentText: String
    var fatPercentText: String
    var proteinProgress: Double
    var carbsProgress: Double
    var fatProgress: Double
    var fiberValueText: String
    var sugarValueText: String
    var sodiumValueText: String
    var exercisePercentText: String
    var exerciseProgress: Double
    var exerciseValueText: String
    var burnRemainingText: String
    var meals: [HomeMealSection]
    var waterRangeText: String
    var waterHintText: String
    var waterFills: [Double]
    var glassMilliliters: Int

    static let empty = HomeDisplay(
        dateTitle: "",
        caloriePercentText: "0%",
        calorieProgress: 0,
        foodValueText: "",
        remainingValueText: "",
        proteinPercentText: "0%",
        carbsPercentText: "0%",
        fatPercentText: "0%",
        proteinProgress: 0,
        carbsProgress: 0,
        fatProgress: 0,
        fiberValueText: "",
        sugarValueText: "",
        sodiumValueText: "",
        exercisePercentText: "0%",
        exerciseProgress: 0,
        exerciseValueText: "",
        burnRemainingText: "",
        meals: [],
        waterRangeText: "",
        waterHintText: "",
        waterFills: Array(repeating: 0, count: 8),
        glassMilliliters: 150
    )
}
