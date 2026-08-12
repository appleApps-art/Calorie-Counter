import Foundation

enum ApplyRecipeIngredientSwapUseCase {
    static func execute(recipe: Recipe, proposal: RecipeIngredientSwapProposal) -> Recipe {
        var updated = recipe
        let originalLower = proposal.originalName.lowercased()
        var ingredients = updated.ingredients
        if let index = ingredients.firstIndex(where: {
            $0.name.lowercased().contains(originalLower) || originalLower.contains($0.name.lowercased())
        }) {
            ingredients[index] = RecipeIngredient(
                id: ingredients[index].id,
                name: proposal.replacementName,
                amount: proposal.replacementAmount ?? ingredients[index].amount,
                unit: proposal.replacementUnit ?? ingredients[index].unit,
                originalText: [
                    proposal.replacementAmount.map { String($0) },
                    proposal.replacementUnit,
                    proposal.replacementName,
                ].compactMap { $0 }.joined(separator: " ")
            )
        } else {
            ingredients.append(
                RecipeIngredient(
                    id: UUID().uuidString,
                    name: proposal.replacementName,
                    amount: proposal.replacementAmount,
                    unit: proposal.replacementUnit,
                    originalText: proposal.replacementName
                )
            )
        }
        updated.ingredients = ingredients
        if let calories = proposal.updatedRecipeCalories { updated.calories = calories }
        if let protein = proposal.updatedRecipeProtein { updated.protein = protein }
        if let carbs = proposal.updatedRecipeCarbs { updated.carbs = carbs }
        if let fats = proposal.updatedRecipeFats { updated.fats = fats }
        return updated
    }
}
