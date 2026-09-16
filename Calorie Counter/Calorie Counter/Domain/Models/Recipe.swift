import Foundation

struct RecipeIngredient: Equatable, Identifiable {
    var id: String
    var name: String
    var amount: Double?
    var unit: String?
    var originalText: String?
}

struct Recipe: Equatable, Identifiable {
    var id: UUID
    var externalId: String?
    var title: String
    var summary: String?
    var imageURL: URL?
    var readyInMinutes: Int?
    var servings: Int?
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fats: Double?
    var ingredients: [RecipeIngredient]
    var steps: [String]
    var sourceName: String?
    var origin: FoodProductSource = .unknown
    var weightGrams: Double? = nil
    var volumeMilliliters: Double? = nil

    var foodType: FoodType? = .dish
    var hasCompleteNutrition: Bool? = nil

    // Persist the namespace in externalId, including when a prepared ingredient is saved as a recipe.
    var ingredientCatalogID: String? {
        catalogFoodKind == .ingredient ? catalogFoodID : nil
    }

    var catalogFoodKind: FoodProductKind? {
        guard let externalId else { return nil }
        if externalId.hasPrefix("ingredient:") { return .ingredient }
        if externalId.hasPrefix("product:") { return .product }
        return nil
    }

    var catalogFoodID: String? {
        guard let kind = catalogFoodKind, let externalId else { return nil }
        let value = String(externalId.dropFirst(kind.rawValue.count + 1))
        return value.isEmpty ? nil : value
    }

    var hasPhoto: Bool {
        guard let imageURL else { return false }
        return !FoodImageURL.isPlaceholder(imageURL)
    }

    var looksLikeListingPage: Bool {
        let t = title.lowercased()
        if t.contains("archive") { return true }
        let words = t.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard words.count <= 3 else { return false }
        if words.contains("recipes") { return true }
        if words.contains("рецепти") || words.contains("рецептів") { return true }
        return false
    }

    var isSearchableRecipe: Bool {
        hasPhoto
    }
}
