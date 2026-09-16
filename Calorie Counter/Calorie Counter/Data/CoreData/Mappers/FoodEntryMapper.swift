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
            source: object.source,
            imageURL: object.imageURLString.flatMap(URL.init(string:)),
            imageData: object.imageData,
            healthSampleID: object.healthSampleID,
            isEaten: object.isEaten,
            ingredientLines: decodeStringArray(object.ingredientsJSON),
            recipeSteps: decodeStringArray(object.stepsJSON),
            catalogExternalId: object.catalogExternalId,
            catalogKind: FoodProductKind(rawValue: object.catalogKind ?? ""),
            foodType: FoodType(rawValue: object.foodType ?? ""),
            hasCompleteNutrition: object.hasCompleteNutrition?.boolValue
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
        object.imageURLString = entry.imageURL?.absoluteString
        object.imageData = entry.imageData
        object.healthSampleID = entry.healthSampleID
        object.isEaten = entry.isEaten
        object.ingredientsJSON = encodeStringArray(entry.ingredientLines)
        object.stepsJSON = encodeStringArray(entry.recipeSteps)
        object.catalogExternalId = entry.catalogExternalId
        object.catalogKind = entry.catalogKind?.rawValue
        object.foodType = entry.resolvedFoodType?.rawValue
        object.hasCompleteNutrition = entry.hasCompleteNutrition.map { NSNumber(value: $0) }
    }

    private static func encodeStringArray(_ values: [String]) -> String? {
        let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty,
              let data = try? JSONEncoder().encode(cleaned),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    private static func decodeStringArray(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
