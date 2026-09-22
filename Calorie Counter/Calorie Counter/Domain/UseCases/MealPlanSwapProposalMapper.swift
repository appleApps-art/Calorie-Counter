import Foundation

/// Turns Bity's proposed dish into a recipe the plan can hold, keeping the meal's own facts
/// wherever the assistant left a gap.
enum MealPlanSwapProposalMapper {
    static func recipe(
        from proposal: MealPlanSwapProposal,
        replacing current: Recipe,
        imageURL: URL? = nil
    ) -> Recipe {
        var recipe = current
        recipe.id = UUID()
        recipe.externalId = nil
        recipe.title = proposal.replacementTitle
        // Bity names a dish, it does not photograph it: the picture comes from the same food-image
        // lookup the recipe page falls back to, so the plan row shows it straight away.
        recipe.imageURL = imageURL
        recipe.origin = .openAI
        recipe.calories = proposal.calories ?? current.calories
        recipe.protein = proposal.protein ?? current.protein
        recipe.carbs = proposal.carbs ?? current.carbs
        recipe.fats = proposal.fats ?? current.fats
        if !proposal.ingredients.isEmpty {
            recipe.ingredients = proposal.ingredients.map {
                RecipeIngredient(id: UUID().uuidString, name: $0, amount: nil, unit: nil, originalText: $0)
            }
        }
        if !proposal.steps.isEmpty {
            recipe.steps = proposal.steps
        }
        return recipe
    }
}
