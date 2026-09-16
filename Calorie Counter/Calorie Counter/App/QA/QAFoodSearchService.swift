#if DEBUG
import Foundation

final class QAFoodSearchService: AIFoodSearching {
    func searchFoods(query: String) async throws -> [FoodProduct] {
        QACatalog.recipes(matching: query).map { recipe in
            FoodProduct(
                id: recipe.id,
                externalId: recipe.externalId ?? "",
                name: recipe.title,
                brand: nil,
                kind: .recipe,
                imageURL: recipe.imageURL,
                calories: recipe.calories,
                protein: recipe.protein,
                carbs: recipe.carbs,
                fats: recipe.fats,
                fiber: 4,
                sugar: 3,
                sodium: 180,
                amount: 1,
                unit: "serving",
                source: .catalog,
                ingredients: recipe.ingredients.map(\.name),
                steps: recipe.steps,
                servingSizeLabel: "1 serving"
            )
        }
    }

    func searchRecipes(query: String) async throws -> [Recipe] {
        QACatalog.recipes(matching: query)
    }

    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] {
        ["qa": try await searchFoods(query: "healthy")]
    }

    func fetchCatalogSection(id: String) async throws -> [FoodProduct] {
        try await searchFoods(query: id)
    }

    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        let all = try await searchFoods(query: id)
        let slice = Array(all.dropFirst(max(0, offset)).prefix(max(1, limit)))
        return FoodSearchCatalogPage(
            products: slice,
            nextOffset: offset + slice.count,
            hasMore: offset + slice.count < all.count
        )
    }

    func enrichDetails(
        title: String,
        imageURL: URL?,
        source: String,
        kind: String
    ) async throws -> FoodProduct? {
        try await searchFoods(query: title).first
    }
}

final class QARecipeSectionsService: RecipeSectionsFetching {
    func fetchSections(locale _: String) async throws -> [RecipeBrowseSection] {
        RecipeBrowseSectionKind.allCases.compactMap { kind in
            let recipes = QACatalog.recipes(matching: kind.query)
            guard !recipes.isEmpty else { return nil }
            return RecipeBrowseSection(id: kind, recipes: Array(recipes.prefix(8)))
        }
    }

    func fetchSectionPage(
        id: RecipeBrowseSectionKind,
        locale _: String,
        offset: Int,
        limit: Int
    ) async throws -> RecipeSectionPage {
        let all = QACatalog.recipes(matching: id.query)
        let slice = Array(all.dropFirst(offset).prefix(limit))
        return RecipeSectionPage(
            recipes: slice,
            nextOffset: offset + slice.count,
            hasMore: offset + slice.count < all.count
        )
    }
}
#endif
