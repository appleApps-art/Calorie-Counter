import Foundation

struct UserGoals: Equatable {
    let calorieTarget: Double
    let proteinTarget: Double
    let carbsTarget: Double
    let fatsTarget: Double
    let fiberTarget: Double
    let sugarTarget: Double
    let sodiumTarget: Double
    let waterTargetMilliliters: Double

    static let `default` = UserGoals(
        calorieTarget: 2000,
        proteinTarget: 150,
        carbsTarget: 200,
        fatsTarget: 65,
        fiberTarget: 25,
        sugarTarget: 50,
        sodiumTarget: 2300,
        waterTargetMilliliters: 2500
    )
}
