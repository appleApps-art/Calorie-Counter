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

    var nutritionFacts: FoodNutritionFacts {
        NutritionFactsCalculator.facts(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
        )
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
            source: source
        )
    }
}

enum FoodPhotoAnalysisError: LocalizedError, Equatable {
    case emptyImage
    case emptyText
    case compressionFailed
    case invalidResponse
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
        case .analysisFailed(let message):
            return message
        case .transport(let message):
            return message
        }
    }
}
