import Foundation

enum SavedRecipeMapper {
    private struct IngredientDTO: Codable {
        var id: String
        var name: String
        var amount: Double?
        var unit: String?
        var originalText: String?
    }

    static func map(_ object: CDSavedRecipe) -> Recipe? {
        guard let id = object.id, let title = object.title else { return nil }

        let ingredients: [RecipeIngredient]
        if let json = object.ingredientsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([IngredientDTO].self, from: data) {
            ingredients = decoded.map {
                RecipeIngredient(
                    id: $0.id,
                    name: $0.name,
                    amount: $0.amount,
                    unit: $0.unit,
                    originalText: $0.originalText
                )
            }
        } else {
            ingredients = []
        }

        let steps: [String]
        if let json = object.stepsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            steps = decoded
        } else {
            steps = []
        }

        return Recipe(
            id: id,
            externalId: object.externalId,
            title: title,
            summary: object.summary,
            imageURL: object.imageURLString.flatMap(URL.init(string:)),
            readyInMinutes: object.readyInMinutes == 0 ? nil : Int(object.readyInMinutes),
            servings: object.servings == 0 ? nil : Int(object.servings),
            calories: object.calories,
            protein: object.protein,
            carbs: object.carbs,
            fats: object.fats,
            ingredients: ingredients,
            steps: steps,
            sourceName: object.sourceName,
            origin: FoodProductSource(apiValue: object.origin),
            weightGrams: object.weightGrams?.doubleValue,
            volumeMilliliters: object.volumeMilliliters?.doubleValue,
            foodType: FoodType(rawValue: object.foodType ?? ""),
            hasCompleteNutrition: object.hasCompleteNutrition?.boolValue,
            fiber: object.fiber?.doubleValue,
            sugar: object.sugar?.doubleValue,
            sodium: object.sodium?.doubleValue
        )
    }

    static func apply(_ recipe: Recipe, to object: CDSavedRecipe) {
        object.id = recipe.id
        object.externalId = recipe.externalId
        object.title = recipe.title.isEmpty ? L10n.tr("recipes.generic") : recipe.title
        object.summary = recipe.summary
        object.imageURLString = recipe.imageURL?.absoluteString
        object.readyInMinutes = Int32(recipe.readyInMinutes ?? 0)
        object.servings = Int32(recipe.servings ?? 0)
        object.calories = recipe.calories ?? 0
        object.protein = recipe.protein ?? 0
        object.carbs = recipe.carbs ?? 0
        object.fats = recipe.fats ?? 0
        object.sourceName = recipe.sourceName
        object.origin = recipe.origin.rawValue
        object.foodType = recipe.foodType?.rawValue
        object.hasCompleteNutrition = recipe.hasCompleteNutrition.map { NSNumber(value: $0) }
        object.weightGrams = recipe.weightGrams.map { NSNumber(value: $0) }
        object.volumeMilliliters = recipe.volumeMilliliters.map { NSNumber(value: $0) }
        object.fiber = recipe.fiber.map { NSNumber(value: $0) }
        object.sugar = recipe.sugar.map { NSNumber(value: $0) }
        object.sodium = recipe.sodium.map { NSNumber(value: $0) }
        object.updatedAt = Date()

        let ingredientDTOs = recipe.ingredients.map {
            IngredientDTO(
                id: $0.id,
                name: $0.name,
                amount: $0.amount,
                unit: $0.unit,
                originalText: $0.originalText
            )
        }
        if let data = try? JSONEncoder().encode(ingredientDTOs),
           let json = String(data: data, encoding: .utf8) {
            object.ingredientsJSON = json
        } else {
            object.ingredientsJSON = "[]"
        }
        if let data = try? JSONEncoder().encode(recipe.steps),
           let json = String(data: data, encoding: .utf8) {
            object.stepsJSON = json
        } else {
            object.stepsJSON = "[]"
        }
    }
}
