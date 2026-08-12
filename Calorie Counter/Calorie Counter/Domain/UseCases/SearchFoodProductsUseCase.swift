import Foundation

final class SearchFoodProductsUseCase {
    private let spoonacularService: SpoonacularServiceProtocol

    init(spoonacularService: SpoonacularServiceProtocol) {
        self.spoonacularService = spoonacularService
    }

    func execute(query: String) async throws -> [FoodProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        async let ingredients = spoonacularService.searchIngredients(query: trimmed, number: 10)
        async let products = spoonacularService.searchProducts(query: trimmed, number: 10)
        let (ingredientResults, productResults) = try await (ingredients, products)
        return ingredientResults + productResults
    }

    func ingredientDetails(id: String) async throws -> FoodProduct {
        try await spoonacularService.ingredientDetails(id: id, amount: 100, unit: "grams")
    }
}
