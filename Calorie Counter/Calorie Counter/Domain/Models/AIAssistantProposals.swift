import Foundation

struct FoodLogProposal: Equatable {
    var name: String
    var mealType: MealType
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var fiber: Double = 0
    var sugar: Double = 0
    var sodium: Double = 0
    var portionGrams: Double? = nil
    var portionMilliliters: Double? = nil
    var confidence: Double = 0.5
    var notes: String = ""
    var source: String = "text"

    func toFoodEntry(date: Date = Date()) -> FoodEntry {
        FoodEntry(
            id: UUID(),
            name: name,
            mealType: mealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            date: date,
            portionGrams: portionGrams,
            portionMilliliters: portionMilliliters,
            notes: notes,
            source: source
        )
    }
}

struct FoodReplaceProposal: Equatable {
    var targetEntryId: UUID?
    var targetName: String?
    var targetMealType: MealType?
    var newItem: FoodLogProposal
    var reason: String?
}

struct FoodSwapItem: Equatable {
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var portionLabel: String?
}

struct FoodSwapProposal: Equatable {
    var original: FoodSwapItem
    var alternative: FoodSwapItem
    var savingsKcal: Double
    var savingsNote: String?
    var applyToEntryId: UUID?
}

struct MealSuggestionOption: Equatable {
    var title: String
    var summary: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var cookTimeMinutes: Double?
    var externalRecipeId: String?
    var ingredients: [String]
}

struct MealSuggestionsProposal: Equatable {
    var mealType: MealType
    var remainingCaloriesTarget: Double?
    var options: [MealSuggestionOption]
}

struct RecipeSaveProposal: Equatable {
    var title: String
    var summary: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var cookTimeMinutes: Double?
    var externalRecipeId: String?
    var ingredients: [String]
    var steps: [String]

    func toRecipe() -> Recipe {
        Recipe(
            id: UUID(),
            externalId: externalRecipeId,
            title: title,
            summary: summary,
            imageURL: nil,
            readyInMinutes: cookTimeMinutes.map { Int($0.rounded()) },
            servings: 1,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            ingredients: ingredients.enumerated().map { index, name in
                RecipeIngredient(id: "\(index)-\(name)", name: name, amount: nil, unit: nil, originalText: name)
            },
            steps: steps,
            sourceName: "AI"
        )
    }
}

struct PreferenceSaveProposal: Equatable {
    var kind: UserPreferenceKind
    var value: String
    var note: String?
}

enum AIAssistantAction: Equatable {
    case logFood(FoodLogProposal)
    case replaceFood(FoodReplaceProposal)
    case swapFood(FoodSwapProposal)
    case mealSuggestions(MealSuggestionsProposal)
    case saveRecipe(RecipeSaveProposal)
    case swapRecipeIngredient(RecipeIngredientSwapProposal)
    case logWater(WaterLogProposal)
    case savePreference(PreferenceSaveProposal)
}
