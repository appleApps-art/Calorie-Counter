import Foundation

struct FoodPhotoAnalysis: Equatable {
    var name: String
    var mealType: MealType
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var portionGrams: Double?
    var portionMilliliters: Double?
    var confidence: Double
    var notes: String
    var assistantMessage: String
    var servingLabel: String = ""
    var ingredients: [FoodIngredient] = []
    var tags: [String] = []
    var suggestion: FoodHealthSuggestion? = nil
    var source: String? = "photo"
    var foodType: FoodType? = nil

    /// Scored exactly like the product and recipe screens (per 100 g when the weight is known),
    /// so the score on the result card is the one the user sees after opening the details.
    var nutritionFacts: FoodNutritionFacts {
        ProductDetailsMath.draft(from: self, imageData: nil, mealType: mealType, date: Date()).nutritionFacts
    }

    /// The model found nothing edible: it answers with zero confidence and zero nutrition.
    /// Water or black coffee also have no calories, but come back with a confident name.
    var findsNoFood: Bool {
        confidence < 0.2 && calories < 1 && protein + carbs + fats < 1
    }

    func toFoodEntry(date: Date = Date(), source: String = "photo") -> FoodEntry {
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
            source: source,
            foodType: foodType
        )
    }
}

enum FoodPhotoAnalysisError: LocalizedError, Equatable {
    case emptyImage
    case emptyText
    case compressionFailed
    case invalidResponse
    case noFood
    case analysisFailed(message: String)
    case transport(message: String)

    var errorDescription: String? {
        switch self {
        case .emptyImage:
            return L10n.tr("photo.error.empty")
        case .emptyText:
            return L10n.tr("photo.error.emptyText")
        case .compressionFailed:
            return L10n.tr("photo.error.compression")
        case .invalidResponse:
            return L10n.tr("photo.error.invalidResponse")
        case .noFood:
            return L10n.tr("photo.error.noFood")
        case .analysisFailed(let message):
            return message
        case .transport(let message):
            return message
        }
    }
}
