import Foundation

struct RecipeIngredientSwapProposal: Equatable {
    var recipeExternalId: String?
    var originalName: String
    var originalAmount: Double?
    var originalUnit: String?
    var replacementName: String
    var replacementAmount: Double?
    var replacementUnit: String?
    var replacementCalories: Double?
    var replacementProtein: Double?
    var replacementCarbs: Double?
    var replacementFats: Double?
    var updatedRecipeCalories: Double?
    var updatedRecipeProtein: Double?
    var updatedRecipeCarbs: Double?
    var updatedRecipeFats: Double?
    var reason: String?
}
