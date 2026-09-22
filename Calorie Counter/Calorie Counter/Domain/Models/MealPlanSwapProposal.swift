import Foundation

/// Bity's answer to "change the porridge on day two": which slot of the plan to touch and what to
/// put there. The app, not the assistant, writes the plan.
struct MealPlanSwapProposal: Equatable {
    var planId: String?
    var dayNumber: Int?
    var mealType: MealType?
    var currentTitle: String?
    var replacementTitle: String
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fats: Double?
    var ingredients: [String] = []
    var steps: [String] = []
    var reason: String?
}
