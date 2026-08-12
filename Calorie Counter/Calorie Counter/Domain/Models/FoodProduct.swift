import Foundation

enum FoodProductKind: String, Equatable {
    case ingredient
    case product
}

struct FoodProduct: Equatable, Identifiable {
    var id: UUID
    var externalId: String
    var name: String
    var brand: String?
    var kind: FoodProductKind
    var imageURL: URL?
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fats: Double?
    var amount: Double?
    var unit: String?
}
