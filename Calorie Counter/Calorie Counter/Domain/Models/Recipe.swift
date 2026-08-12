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
}
