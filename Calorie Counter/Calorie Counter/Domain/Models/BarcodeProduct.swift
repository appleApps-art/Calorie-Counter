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
    var servingGrams: Double? = nil
    var servingMilliliters: Double? = nil

    func toFoodProduct(preferServing: Bool = false) -> FoodProduct {
        let hasPer100g = caloriesPer100g != nil || proteinPer100g != nil || carbsPer100g != nil || fatsPer100g != nil
        let hasPerServing = caloriesPerServing != nil || proteinPerServing != nil || carbsPerServing != nil || fatsPerServing != nil
        let useServing = hasPerServing && (preferServing || !hasPer100g)
        let servingAmount = servingMilliliters ?? servingGrams
        let servingUnit = servingMilliliters != nil ? "ml" : (servingGrams != nil ? "g" : nil)
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
            amount: useServing ? servingAmount : 100,
            unit: useServing ? servingUnit : "g",
            source: source == .openFoodFacts ? .openFoodFacts : .spoonacular,
            servingSizeLabel: useServing ? servingSizeLabel : nil
        )
    }
}
