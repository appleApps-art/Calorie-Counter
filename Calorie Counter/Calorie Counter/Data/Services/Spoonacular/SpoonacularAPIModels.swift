import Foundation

struct SpoonacularRecipeSearchResponse: Decodable {
    let results: [SpoonacularRecipeSearchItem]?
}

struct SpoonacularRecipeSearchItem: Decodable {
    let id: Int
    var foodType: FoodType? = nil
    let title: String?
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let nutrition: SpoonacularNutrition?
    let summary: String?
}

struct SpoonacularRecipeInformation: Decodable {
    let id: Int
    var foodType: FoodType? = nil
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
    let weightPerServing: SpoonacularMassAmount?
}

struct SpoonacularMassAmount: Decodable {
    let amount: Double?
    let unit: String?
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
    var foodType: FoodType? = nil
    let name: String?
    let image: String?
}

struct SpoonacularIngredientInformation: Decodable {
    let id: Int
    var foodType: FoodType? = nil
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
    var foodType: FoodType? = nil
    let title: String?
    let image: String?
    let brand: String?
}

struct SpoonacularUpcProductResponse: Decodable {
    let id: Int?
    var foodType: FoodType? = nil
    let title: String?
    let breadcrumbs: [String]?
    let brand: String?
    let image: String?
    let images: [String]?
    let servings: SpoonacularUpcServings?
    let nutrition: SpoonacularNutrition?
    let upc: String?
    let badges: [String]?
    let ingredientList: String?
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
    case http(status: Int, message: String, retryAfter: TimeInterval?)
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
        case .http(_, let message, _):
            return message
        case .decodingFailed:
            return "Failed to decode Spoonacular response"
        case .transport(let underlying):
            return underlying.localizedDescription
        }
    }

    var isRetryable: Bool {
        switch self {
        case .http(let status, let message, _):
            let lower = message.lowercased()
            if status == 402 || lower.contains("points limit") {
                return false
            }
            return status == 408 || status == 429 || (500...599).contains(status)
        case .transport, .invalidResponse:
            return true
        default:
            return false
        }
    }

    var retryAfter: TimeInterval? {
        if case .http(_, _, let retryAfter) = self {
            return retryAfter
        }
        return nil
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
            imageURL: foodImageURL(item.image, useIngredientCDN: false),
            readyInMinutes: item.readyInMinutes,
            servings: item.servings,
            calories: nutrients["calories"],
            protein: nutrients["protein"],
            carbs: nutrients["carbohydrates"] ?? nutrients["carbs"],
            fats: nutrients["fat"],
            ingredients: [],
            steps: [],
            sourceName: nil,
            origin: .spoonacular,
            weightGrams: grams(from: item.nutrition?.weightPerServing),
            foodType: item.foodType ?? .dish
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
            imageURL: foodImageURL(info.image, useIngredientCDN: false),
            readyInMinutes: info.readyInMinutes,
            servings: info.servings,
            calories: nutrients["calories"],
            protein: nutrients["protein"],
            carbs: nutrients["carbohydrates"] ?? nutrients["carbs"],
            fats: nutrients["fat"],
            ingredients: ingredients,
            steps: steps,
            sourceName: info.sourceName,
            origin: .spoonacular,
            weightGrams: grams(from: info.nutrition?.weightPerServing),
            foodType: info.foodType ?? .dish
        )
    }

    static func mapIngredientSearchItem(_ item: SpoonacularIngredientSearchItem) -> FoodProduct {
        FoodProduct(
            id: UUID(),
            externalId: String(item.id),
            name: item.name ?? "Ingredient",
            brand: nil,
            kind: .ingredient,
            imageURL: foodImageURL(item.image, useIngredientCDN: true),
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            amount: 100,
            unit: "g",
            source: .spoonacular,
            foodType: item.foodType
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
            imageURL: foodImageURL(info.image, useIngredientCDN: true),
            calories: nutrients["calories"],
            protein: nutrients["protein"],
            carbs: nutrients["carbohydrates"] ?? nutrients["carbs"],
            fats: nutrients["fat"],
            fiber: nutrients["fiber"] ?? nutrients["dietary fiber"],
            sugar: nutrients["sugar"] ?? nutrients["sugars"],
            sodium: nutrients["sodium"],
            amount: info.amount,
            unit: info.unit,
            source: .spoonacular,
            foodType: info.foodType
        )
    }

    static func mapProductSearchItem(_ item: SpoonacularProductSearchItem) -> FoodProduct {
        FoodProduct(
            id: UUID(),
            externalId: String(item.id),
            name: item.title ?? "Product",
            brand: item.brand,
            kind: .product,
            imageURL: productImageURL(id: item.id, raw: item.image),
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            amount: nil,
            unit: nil,
            source: .spoonacular,
            foodType: item.foodType ?? .product
        )
    }

    static func mapGroceryProduct(_ item: SpoonacularUpcProductResponse, fallbackId: String) -> FoodProduct? {
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
        let ingredients = (item.ingredientList ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return FoodProduct(
            id: UUID(),
            externalId: item.id.map(String.init) ?? fallbackId,
            name: title,
            brand: item.brand,
            kind: .product,
            imageURL: productImageURL(id: item.id, raw: image),
            calories: nutrients["calories"],
            protein: nutrients["protein"],
            carbs: nutrients["carbohydrates"] ?? nutrients["carbs"],
            fats: nutrients["fat"],
            fiber: nutrients["fiber"] ?? nutrients["dietary fiber"],
            sugar: nutrients["sugar"] ?? nutrients["sugars"],
            sodium: nutrients["sodium"],
            amount: item.servings?.size,
            unit: item.servings?.unit,
            source: .spoonacular,
            ingredients: ingredients,
            servingSizeLabel: servingLabel,
            foodType: item.foodType ?? .product
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
            imageURL: productImageURL(id: item.id, raw: image),
            caloriesPer100g: nil,
            proteinPer100g: nil,
            carbsPer100g: nil,
            fatsPer100g: nil,
            caloriesPerServing: nutrients["calories"],
            proteinPerServing: nutrients["protein"],
            carbsPerServing: nutrients["carbohydrates"] ?? nutrients["carbs"],
            fatsPerServing: nutrients["fat"],
            source: .spoonacular,
            servingGrams: item.servings?.unit == nil ? nil
                : grams(from: SpoonacularMassAmount(amount: item.servings?.size, unit: item.servings?.unit)),
            servingMilliliters: milliliters(amount: item.servings?.size, unit: item.servings?.unit)
        )
    }

    private static func milliliters(amount: Double?, unit: String?) -> Double? {
        guard let amount, amount.isFinite, amount > 0 else { return nil }
        let normalized = (unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres", "мл": return amount
        case "l", "liter", "liters", "litre", "litres", "л": return amount * 1000
        default: return nil
        }
    }

    private static func grams(from mass: SpoonacularMassAmount?) -> Double? {
        guard let amount = mass?.amount, amount.isFinite, amount > 0 else { return nil }
        let unit = (mass?.unit ?? "g").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch unit {
        case "g", "gr", "gram", "grams", "г", "грам", "грами", "грамів": return amount
        case "kg", "kilogram", "kilograms", "кг": return amount * 1000
        case "mg", "milligram", "milligrams", "мг": return amount / 1000
        case "oz", "ounce", "ounces": return amount * 28.349523125
        case "lb", "lbs", "pound", "pounds": return amount * 453.59237
        default: return nil
        }
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

    private static func productImageURL(id: Int?, raw: String?) -> URL? {
        if let url = foodImageURL(raw, useIngredientCDN: false) {
            return url
        }
        guard let id else { return nil }
        return URL(string: "https://img.spoonacular.com/products/\(id)-312x231.jpg")
    }

    private static func foodImageURL(_ raw: String?, useIngredientCDN: Bool) -> URL? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, !FoodImageURL.isPlaceholder(trimmed) else { return nil }
        let scheme = trimmed.lowercased()
        let resolved: URL?
        if scheme.hasPrefix("http://") || scheme.hasPrefix("https://") {
            resolved = URL(string: trimmed)
        } else if useIngredientCDN {
            resolved = URL(string: "https://img.spoonacular.com/ingredients_100x100/\(trimmed)")
        } else {
            resolved = URL(string: trimmed)
        }
        guard let url = resolved, !FoodImageURL.isPlaceholder(url) else { return nil }
        return url
    }
}
