import Foundation

enum UserGoalsMapper {
    static func map(_ object: CDUserGoals) -> UserGoals {
        UserGoals(
            calorieTarget: object.calorieTarget,
            proteinTarget: object.proteinTarget,
            carbsTarget: object.carbsTarget,
            fatsTarget: object.fatsTarget,
            fiberTarget: object.fiberTarget,
            sugarTarget: object.sugarTarget,
            sodiumTarget: object.sodiumTarget,
            waterTargetMilliliters: object.waterTargetMilliliters
        )
    }

    static func apply(_ goals: UserGoals, to object: CDUserGoals) {
        if object.id == nil {
            object.id = UUID()
        }
        object.calorieTarget = goals.calorieTarget
        object.proteinTarget = goals.proteinTarget
        object.carbsTarget = goals.carbsTarget
        object.fatsTarget = goals.fatsTarget
        object.fiberTarget = goals.fiberTarget
        object.sugarTarget = goals.sugarTarget
        object.sodiumTarget = goals.sodiumTarget
        object.waterTargetMilliliters = goals.waterTargetMilliliters
    }
}
