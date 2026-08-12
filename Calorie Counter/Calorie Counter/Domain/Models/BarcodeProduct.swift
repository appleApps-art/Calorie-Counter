import Foundation

enum BarcodeProductSource: String, Equatable {
    case openFoodFacts
    case spoonacular
}

struct BarcodeProduct: Equatable, Identifiable {
    var id: UUID
    var barcode: String
    var name: String
    var brand: String?
    var quantityLabel: String?
    var servingSizeLabel: String?
    var imageURL: URL?
    var caloriesPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatsPer100g: Double?
    var caloriesPerServing: Double?
    var proteinPerServing: Double?
    var carbsPerServing: Double?
    var fatsPerServing: Double?
    var source: BarcodeProductSource

    func toFoodProduct(preferServing: Bool = false) -> FoodProduct {
        let useServing = preferServing && caloriesPerServing != nil
        return FoodProduct(
            id: id,
            externalId: barcode,
            name: name,
            brand: brand,
            kind: .product,
            imageURL: imageURL,
            calories: useServing ? caloriesPerServing : caloriesPer100g,
            protein: useServing ? proteinPerServing : proteinPer100g,
            carbs: useServing ? carbsPerServing : carbsPer100g,
            fats: useServing ? fatsPerServing : fatsPer100g,
            amount: useServing ? nil : 100,
            unit: useServing ? servingSizeLabel : "g"
        )
    }
}
