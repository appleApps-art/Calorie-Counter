import Foundation

final class SearchRecipesUseCase {
    private let spoonacularService: SpoonacularServiceProtocol

    init(spoonacularService: SpoonacularServiceProtocol) {
        self.spoonacularService = spoonacularService
    }

    func execute(query: String, maxCalories: Int? = nil) async throws -> [Recipe] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await spoonacularService.searchRecipes(query: trimmed, maxCalories: maxCalories, number: 12)
    }

    func details(externalId: String) async throws -> Recipe {
        try await spoonacularService.recipeDetails(id: externalId)
    }
}
