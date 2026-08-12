import Foundation

struct FoodEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
    let mealType: MealType
    let calories: Double
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
    let date: Date
    var portionGrams: Double? = nil
    var portionMilliliters: Double? = nil
    var notes: String = ""
    var source: String? = nil

    func scaled(toGrams newGrams: Double) -> FoodEntry {
        let current = portionGrams ?? 100
        let factor = current > 0 ? newGrams / current : 1
        return FoodEntry(
            id: id,
            name: name,
            mealType: mealType,
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fats: fats * factor,
            fiber: fiber * factor,
            sugar: sugar * factor,
            sodium: sodium * factor,
            date: date,
            portionGrams: newGrams,
            portionMilliliters: portionMilliliters,
            notes: notes,
            source: source
        )
    }
}
