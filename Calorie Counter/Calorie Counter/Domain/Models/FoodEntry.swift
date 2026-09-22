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
    var imageURL: URL? = nil
    var imageData: Data? = nil
    var healthSampleID: String? = nil
    var isEaten: Bool = false
    var ingredientLines: [String] = []
    var recipeSteps: [String] = []
    var catalogExternalId: String? = nil
    var catalogKind: FoodProductKind? = nil

    var foodType: FoodType? = nil
    var hasCompleteNutrition: Bool? = nil

    var resolvedFoodType: FoodType? {
        foodType ?? FoodType.inferred(kind: catalogKind, source: FoodProductSource(apiValue: source), hasSteps: !recipeSteps.isEmpty)
    }

    var opensAsRecipe: Bool {
        resolvedFoodType == .dish
    }

    func asRecipe() -> Recipe {
        let lines = ingredientLines.isEmpty
            ? ProductDetailsMath.parseIngredientLines(notes).map(ProductDetailsMath.formatIngredient)
            : ingredientLines
        let ingredients = lines.enumerated().compactMap { index, line -> RecipeIngredient? in
            guard let parsed = ProductDetailsMath.parseIngredientLine(line) else { return nil }
            return RecipeIngredient(
                id: "\(index)-\(parsed.name)",
                name: parsed.name,
                amount: parsed.grams ?? parsed.milliliters,
                unit: parsed.grams != nil ? "g" : (parsed.milliliters != nil ? "ml" : nil),
                originalText: line
            )
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = (trimmedNotes.isEmpty || !ingredientLines.isEmpty) ? nil : trimmedNotes
        let catalogID = catalogExternalId.flatMap { $0.isEmpty ? nil : $0 }
        let recipeExternalId = catalogID ?? "diary-\(id.uuidString)"
        let hasCompleteLocalRecipe = catalogID == nil && catalogKind == nil
            && !ingredients.isEmpty && !recipeSteps.isEmpty && hasCompleteNutrition != false
            && calories.isFinite && calories > 0 && [protein, carbs, fats].allSatisfy { $0.isFinite && $0 >= 0 }
        return Recipe(
            id: id,
            externalId: catalogKind == .recipe || hasCompleteLocalRecipe ? recipeExternalId
                : (catalogKind ?? .product).rawValue + ":" + recipeExternalId,
            title: name,
            summary: summary,
            imageURL: imageURL,
            readyInMinutes: nil,
            servings: 1,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            ingredients: ingredients,
            steps: recipeSteps,
            sourceName: source,
            origin: FoodProductSource(apiValue: source),
            weightGrams: portionGrams,
            volumeMilliliters: portionMilliliters,
            foodType: resolvedFoodType,
            hasCompleteNutrition: hasCompleteNutrition,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
        )
    }

    func scaled(toGrams newGrams: Double) -> FoodEntry {
        let current = portionGrams ?? 100
        let factor = current > 0 ? newGrams / current : 1
        return scaled(by: factor, portionGrams: newGrams, portionMilliliters: portionMilliliters)
    }

    func scaled(toMilliliters newMilliliters: Double) -> FoodEntry {
        let current = portionMilliliters ?? 100
        let factor = current > 0 ? newMilliliters / current : 1
        return scaled(by: factor, portionGrams: portionGrams, portionMilliliters: newMilliliters)
    }

    private func scaled(by factor: Double, portionGrams: Double?, portionMilliliters: Double?) -> FoodEntry {
        FoodEntry(
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
            portionGrams: portionGrams,
            portionMilliliters: portionMilliliters,
            notes: notes,
            source: source,
            imageURL: imageURL,
            imageData: imageData,
            healthSampleID: healthSampleID,
            isEaten: isEaten,
            ingredientLines: ingredientLines,
            recipeSteps: recipeSteps,
            catalogExternalId: catalogExternalId,
            catalogKind: catalogKind,
            foodType: foodType,
            hasCompleteNutrition: hasCompleteNutrition
        )
    }
}
