import Foundation

enum FoodEntryMapper {
    static func map(_ object: CDFoodEntry) -> FoodEntry? {
        guard
            let id = object.id,
            let name = object.name,
            let mealTypeRaw = object.mealType,
            let mealType = MealType(rawValue: mealTypeRaw),
            let date = object.date
        else {
            return nil
        }

        return FoodEntry(
            id: id,
            name: name,
            mealType: mealType,
            calories: object.calories,
            protein: object.protein,
            carbs: object.carbs,
            fats: object.fats,
            fiber: object.fiber,
            sugar: object.sugar,
            sodium: object.sodium,
            date: date,
            portionGrams: object.portionGrams?.doubleValue,
            portionMilliliters: object.portionMilliliters?.doubleValue,
            notes: object.notes ?? "",
            source: object.source
        )
    }

    static func apply(_ entry: FoodEntry, to object: CDFoodEntry) {
        object.id = entry.id
        object.name = entry.name
        object.mealType = entry.mealType.rawValue
        object.calories = entry.calories
        object.protein = entry.protein
        object.carbs = entry.carbs
        object.fats = entry.fats
        object.fiber = entry.fiber
        object.sugar = entry.sugar
        object.sodium = entry.sodium
        object.date = entry.date
        object.portionGrams = entry.portionGrams.map { NSNumber(value: $0) }
        object.portionMilliliters = entry.portionMilliliters.map { NSNumber(value: $0) }
        object.notes = entry.notes.isEmpty ? nil : entry.notes
        object.source = entry.source
    }
}
