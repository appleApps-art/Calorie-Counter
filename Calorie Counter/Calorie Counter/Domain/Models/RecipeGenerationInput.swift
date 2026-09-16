import Foundation

struct RecipeGenerationInput: Equatable {
    var ingredients: [String]
    var mealTypes: [String]
    var cuisine: String?
    var diet: String?
    var maxReadyMinutes: Int?
    var maxCalories: Int?
    var details: String
    var startDate: Date?
    var endDate: Date?
}
