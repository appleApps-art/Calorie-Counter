import Foundation

struct SpoonacularRecipeSearchResponse: Decodable {
    let results: [SpoonacularRecipeSearchItem]?
}

struct SpoonacularRecipeSearchItem: Decodable {
    let id: Int
    let title: String?
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let nutrition: SpoonacularNutrition?
    let summary: String?
}

struct SpoonacularRecipeInformation: Decodable {
    let id: Int
    let title: String?
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let summary: String?
    let sourceName: String?
    let nutrition: SpoonacularNutrition?
    let extendedIngredients: [SpoonacularExtendedIngredient]?
    let analyzedInstructions: [SpoonacularAnalyzedInstruction]?
}

struct SpoonacularExtendedIngredient: Decodable {
    let id: Int?
    let name: String?
    let original: String?
    let amount: Double?
    let unit: String?
}

struct SpoonacularAnalyzedInstruction: Decodable {
    let steps: [SpoonacularStep]?
}

struct SpoonacularStep: Decodable {
    let number: Int?
    let step: String?
}

struct SpoonacularNutrition: Decodable {
    let nutrients: [SpoonacularNutrient]?
}

struct SpoonacularNutrient: Decodable {
    let name: String?
    let amount: Double?
    let unit: String?
}

struct SpoonacularIngredientSearchResponse: Decodable {
    let results: [SpoonacularIngredientSearchItem]?
}

struct SpoonacularIngredientSearchItem: Decodable {
    let id: Int
    let name: String?
    let image: String?
}

struct SpoonacularIngredientInformation: Decodable {
    let id: Int
    let name: String?
    let image: String?
    let nutrition: SpoonacularNutrition?
    let amount: Double?
    let unit: String?
}

struct SpoonacularProductSearchResponse: Decodable {
    let products: [SpoonacularProductSearchItem]?
}

struct SpoonacularProductSearchItem: Decodable {
    let id: Int
    let title: String?
    let image: String?
    let brand: String?
}

struct SpoonacularUpcProductResponse: Decodable {
    let id: Int?
    let title: String?
    let breadcrumbs: [String]?
    let brand: String?
    let image: String?
    let images: [String]?
    let servings: SpoonacularUpcServings?
    let nutrition: SpoonacularNutrition?
    let upc: String?
    let badges: [String]?
}

struct SpoonacularUpcServings: Decodable {
    let number: Double?
    let size: Double?
    let unit: String?
}

struct SpoonacularErrorResponse: Decodable {
    let error: String?
}

enum SpoonacularServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(message: String)
    case decodingFailed
    case transport(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Spoonacular proxy URL"
        case .invalidResponse:
            return "Invalid Spoonacular response"
        case .server(let message):
            return message
        case .decodingFailed:
            return "Failed to decode Spoonacular response"
        case .transport(let underlying):
            return underlying.localizedDescription
        }
    }
}

enum SpoonacularMapper {
    static func mapSearchItem(_ item: SpoonacularRecipeSearchItem) -> Recipe {
        let nutrients = nutrientMap(item.nutrition)
        return Recipe(
            id: UUID(),
            externalId: String(item.id),
            title: item.title ?? "Recipe",
            summary: stripHTML(item.summary),
            imageURL: URL(string: item.image ?? ""),
            readyInMinutes: item.readyInMinutes,
            servings: item.servings,
            calories: nutrients["calories"],
            protein: nutrients["protein"],
            carbs: nutrients["carbohydrates"] ?? nutrients["carbs"],
            fats: nutrients["fat"],
            ingredients: [],
            steps: [],
            sourceName: nil
        )
    }

    static func mapInformation(_ info: SpoonacularRecipeInformation) -> Recipe {
        let nutrients = nutrientMap(info.nutrition)
        let ingredients = (info.extendedIngredients ?? []).enumerated().map { index, ingredient in
            RecipeIngredient(
                id: ingredient.id.map(String.init) ?? "ing-\(index)",
                name: ingredient.name ?? ingredient.original ?? "Ingredient",
                amount: ingredient.amount,
                unit: ingredient.unit,
                originalText: ingredient.original
            )
        }
        let steps = (info.analyzedInstructions ?? [])
            .flatMap { $0.steps ?? [] }
            .sorted { ($0.number ?? 0) < ($1.number ?? 0) }
            .compactMap(\.step)

        return Recipe(
            id: UUID(),
            externalId: String(info.id),
            title: info.title ?? "Recipe",
            summary: stripHTML(info.summary),
            imageURL: URL(string: info.image ?? ""),
            readyInMinutes: info.readyInMinutes,
            servings: info.servings,
            calories: nutrients["calories"],
            protein: nutrients["protein"],
            carbs: nutrients["carbohydrates"] ?? nutrients["carbs"],
            fats: nutrients["fat"],
            ingredients: ingredients,
            steps: steps,
            sourceName: info.sourceName
        )
    }

    static func mapIngredientSearchItem(_ item: SpoonacularIngredientSearchItem) -> FoodProduct {
        FoodProduct(
            id: UUID(),
            externalId: String(item.id),
            name: item.name ?? "Ingredient",
            brand: nil,
            kind: .ingredient,
            imageURL: item.image.flatMap { URL(string: "https://img.spoonacular.com/ingredients_100x100/\($0)") },
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            amount: 100,
            unit: "g"
        )
    }

    static func mapIngredientInformation(_ info: SpoonacularIngredientInformation) -> FoodProduct {
        let nutrients = nutrientMap(info.nutrition)
        return FoodProduct(
            id: UUID(),
            externalId: String(info.id),
            name: info.name ?? "Ingredient",
            brand: nil,
            kind: .ingredient,
            imageURL: info.image.flatMap { URL(string: "https://img.spoonacular.com/ingredients_100x100/\($0)") },
            calories: nutrients["calories"],
            protein: nutrients["protein"],
            carbs: nutrients["carbohydrates"] ?? nutrients["carbs"],
            fats: nutrients["fat"],
            amount: info.amount,
            unit: info.unit
        )
    }

    static func mapProductSearchItem(_ item: SpoonacularProductSearchItem) -> FoodProduct {
        FoodProduct(
            id: UUID(),
            externalId: String(item.id),
            name: item.title ?? "Product",
            brand: item.brand,
            kind: .product,
            imageURL: URL(string: item.image ?? ""),
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            amount: nil,
            unit: nil
        )
    }

    static func mapUpcProduct(_ item: SpoonacularUpcProductResponse, barcode: String) -> BarcodeProduct? {
        guard let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }
        let nutrients = nutrientMap(item.nutrition)
        let image = item.image ?? item.images?.first
        let servingLabel: String?
        if let size = item.servings?.size, let unit = item.servings?.unit {
            servingLabel = String(format: "%g %@", size, unit)
        } else {
            servingLabel = nil
        }

        return BarcodeProduct(
            id: UUID(),
            barcode: barcode,
            name: title,
            brand: item.brand,
            quantityLabel: nil,
            servingSizeLabel: servingLabel,
            imageURL: image.flatMap(URL.init(string:)),
            caloriesPer100g: nutrients["calories"],
            proteinPer100g: nutrients["protein"],
            carbsPer100g: nutrients["carbohydrates"] ?? nutrients["carbs"],
            fatsPer100g: nutrients["fat"],
            caloriesPerServing: nil,
            proteinPerServing: nil,
            carbsPerServing: nil,
            fatsPerServing: nil,
            source: .spoonacular
        )
    }

    private static func nutrientMap(_ nutrition: SpoonacularNutrition?) -> [String: Double] {
        var map: [String: Double] = [:]
        for nutrient in nutrition?.nutrients ?? [] {
            guard let name = nutrient.name?.lowercased(), let amount = nutrient.amount else { continue }
            map[name] = amount
        }
        return map
    }

    private static func stripHTML(_ value: String?) -> String? {
        guard let value else { return nil }
        return value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
