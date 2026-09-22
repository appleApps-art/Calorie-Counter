import Foundation

struct FoodIngredient: Equatable, Identifiable {
    var id: UUID
    var name: String
    var grams: Double?
    var milliliters: Double?
    var quantityText: String?

    init(
        id: UUID = UUID(),
        name: String,
        grams: Double? = nil,
        milliliters: Double? = nil,
        quantityText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.grams = grams
        self.milliliters = milliliters
        self.quantityText = quantityText
    }
}

struct FoodHealthSuggestion: Equatable {
    var name: String
    var summary: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var portionGrams: Double?
    var portionMilliliters: Double?
    var servingLabel: String
    var ingredients: [FoodIngredient]
    var tags: [String]
    var foodType: FoodType? = nil
}

struct ProductDetailsDraft: Equatable {
    var name: String
    var servingLabel: String
    var mealType: MealType
    var date: Date
    var logDates: [Date] = []
    var servings: Int
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var portionGrams: Double?
    var portionMilliliters: Double?
    var ingredients: [FoodIngredient]
    var tags: [String]
    var notes: String
    var source: String
    var imageURL: URL? = nil
    var imageData: Data?
    var recipeSteps: [String] = []
    var suggestion: FoodHealthSuggestion?
    var catalogExternalId: String? = nil
    var catalogKind: FoodProductKind? = nil
    var foodType: FoodType? = nil
    var hasCompleteNutrition: Bool? = nil

    var resolvedFoodType: FoodType? {
        foodType ?? FoodType.inferred(kind: catalogKind, source: FoodProductSource(apiValue: source), hasSteps: !recipeSteps.isEmpty)
    }

    var nutritionFacts: FoodNutritionFacts {
        let sample = perReferenceNutrition
        return NutritionFactsCalculator.facts(
            calories: sample.calories,
            protein: sample.protein,
            carbs: sample.carbs,
            fats: sample.fats,
            fiber: sample.fiber,
            sugar: sample.sugar,
            sodium: sample.sodium
        )
    }

    var perReferenceNutrition: (
        calories: Double,
        protein: Double,
        carbs: Double,
        fats: Double,
        fiber: Double,
        sugar: Double,
        sodium: Double
    ) {
        guard let grams = portionGrams, grams > 0 else {
            return (calories, protein, carbs, fats, fiber, sugar, sodium)
        }
        let factor = 100 / grams
        return (
            calories * factor,
            protein * factor,
            carbs * factor,
            fats * factor,
            fiber * factor,
            sugar * factor,
            sodium * factor
        )
    }

    var loggedCalories: Double { calories * Double(servings) }
    var loggedProtein: Double { protein * Double(servings) }
    var loggedCarbs: Double { carbs * Double(servings) }
    var loggedFats: Double { fats * Double(servings) }
    var loggedFiber: Double { fiber * Double(servings) }
    var loggedSugar: Double { sugar * Double(servings) }
    var loggedSodium: Double { sodium * Double(servings) }

    func resolvedLogDates() -> [Date] {
        let calendar = Calendar.current
        let source = logDates.isEmpty ? [date] : logDates
        return Array(Set(source.map { calendar.startOfDay(for: $0) })).sorted()
    }

    func toFoodEntry(on date: Date? = nil) -> FoodEntry {
        let loggedIngredients = ingredients.map { ProductDetailsMath.scaledIngredient($0, by: Double(servings)) }
        let ingredientNotes = loggedIngredients
            .map { ProductDetailsMath.formatIngredient($0) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        let mergedNotes: String
        if notes.isEmpty {
            mergedNotes = ingredientNotes
        } else if ingredientNotes.isEmpty {
            mergedNotes = notes
        } else {
            mergedNotes = notes + "\n" + ingredientNotes
        }
        return FoodEntry(
            id: UUID(),
            name: name,
            mealType: mealType,
            calories: loggedCalories,
            protein: loggedProtein,
            carbs: loggedCarbs,
            fats: loggedFats,
            fiber: loggedFiber,
            sugar: loggedSugar,
            sodium: loggedSodium,
            date: date ?? self.date,
            portionGrams: portionGrams.map { $0 * Double(servings) },
            portionMilliliters: portionMilliliters.map { $0 * Double(servings) },
            notes: mergedNotes,
            source: source,
            imageURL: imageURL,
            imageData: imageData,
            ingredientLines: ingredientNotes.isEmpty
                ? []
                : loggedIngredients.map(ProductDetailsMath.formatIngredient).filter { !$0.isEmpty },
            recipeSteps: recipeSteps,
            catalogExternalId: catalogExternalId,
            catalogKind: catalogKind,
            foodType: resolvedFoodType,
            hasCompleteNutrition: hasCompleteNutrition
        )
    }

    func toFoodEntries() -> [FoodEntry] {
        resolvedLogDates().map { toFoodEntry(on: $0) }
    }
}

enum ProductDetailsMath {
    static func draft(
        from analysis: FoodPhotoAnalysis,
        imageData: Data?,
        mealType: MealType,
        date: Date
    ) -> ProductDetailsDraft {
        var ingredients = analysis.ingredients
        if ingredients.isEmpty {
            ingredients = parseIngredientLines(analysis.notes)
        }
        return ProductDetailsDraft(
            name: analysis.name,
            servingLabel: analysis.servingLabel,
            mealType: mealType,
            date: date,
            servings: 1,
            calories: analysis.calories,
            protein: analysis.protein,
            carbs: analysis.carbs,
            fats: analysis.fats,
            fiber: analysis.fiber,
            sugar: analysis.sugar,
            sodium: analysis.sodium,
            portionGrams: analysis.portionGrams,
            portionMilliliters: analysis.portionMilliliters,
            ingredients: ingredients,
            tags: analysis.tags,
            notes: analysis.notes,
            source: analysis.source ?? "photo",
            imageData: imageData,
            suggestion: analysis.suggestion,
            foodType: analysis.foodType
        )
    }

    static func draft(
        from option: MealSuggestionOption,
        mealType: MealType,
        date: Date = Date()
    ) -> ProductDetailsDraft {
        let ingredients = option.ingredients.compactMap(parseIngredientLine)
        let steps = option.steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let catalogId = option.externalRecipeId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let numericId = catalogId.flatMap { id -> String? in
            id.isEmpty || !id.allSatisfy(\.isNumber) ? nil : id
        }
        return ProductDetailsDraft(
            name: option.title,
            servingLabel: "",
            mealType: mealType,
            date: date,
            servings: 1,
            calories: option.calories,
            protein: option.protein,
            carbs: option.carbs,
            fats: option.fats,
            fiber: option.fiber ?? 0,
            sugar: option.sugar ?? 0,
            sodium: option.sodium ?? 0,
            portionGrams: option.portionGrams,
            portionMilliliters: option.portionMilliliters,
            ingredients: ingredients,
            tags: [],
            notes: option.summary,
            source: numericId == nil ? FoodProductSource.openAI.rawValue : FoodProductSource.spoonacular.rawValue,
            imageURL: option.imageURL,
            imageData: nil,
            recipeSteps: steps,
            suggestion: nil,
            catalogExternalId: catalogId.flatMap { $0.isEmpty ? nil : $0 },
            catalogKind: .recipe,
            foodType: .dish
        )
    }

    static func draft(from entry: FoodEntry) -> ProductDetailsDraft {
        let ingredients = entry.ingredientLines.isEmpty
            ? parseIngredientLines(entry.notes)
            : entry.ingredientLines.compactMap(parseIngredientLine)
        return ProductDetailsDraft(
            name: entry.name,
            servingLabel: formatPortion(grams: entry.portionGrams, milliliters: entry.portionMilliliters),
            mealType: entry.mealType,
            date: entry.date,
            servings: 1,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fats: entry.fats,
            fiber: entry.fiber,
            sugar: entry.sugar,
            sodium: entry.sodium,
            portionGrams: entry.portionGrams,
            portionMilliliters: entry.portionMilliliters,
            ingredients: ingredients,
            tags: [],
            notes: entry.notes,
            source: entry.source ?? "diary",
            imageURL: entry.imageURL,
            imageData: entry.imageData,
            recipeSteps: entry.recipeSteps,
            suggestion: nil,
            catalogExternalId: entry.catalogExternalId,
            catalogKind: entry.catalogKind,
            foodType: entry.resolvedFoodType,
            hasCompleteNutrition: entry.hasCompleteNutrition
        )
    }

    static func draft(
        from recipe: Recipe,
        mealType: MealType = .lunch,
        date: Date = Date()
    ) -> ProductDetailsDraft {
        let servingsCount = max(recipe.servings ?? 1, 1)
        let servingLabel = servingsCount == 1
            ? L10n.format("recipes.details.serving", 1)
            : L10n.format("recipes.details.servings", servingsCount)
        let mappedIngredients = recipe.ingredients.map { item in
            var perServing = item
            perServing.amount = item.amount.map { $0 / Double(servingsCount) }
            return ingredient(from: perServing)
        }
        let portionGrams = recipe.weightGrams
        return ProductDetailsDraft(
            name: recipe.title,
            servingLabel: servingLabel,
            mealType: mealType,
            date: date,
            servings: servingsCount,
            calories: recipe.calories ?? 0,
            protein: recipe.protein ?? 0,
            carbs: recipe.carbs ?? 0,
            fats: recipe.fats ?? 0,
            fiber: recipe.fiber ?? 0,
            sugar: recipe.sugar ?? 0,
            sodium: recipe.sodium ?? 0,
            portionGrams: portionGrams,
            portionMilliliters: recipe.volumeMilliliters,
            ingredients: mappedIngredients,
            tags: [],
            notes: recipe.summary ?? "",
            source: recipe.origin.rawValue,
            imageURL: recipe.imageURL,
            imageData: nil,
            recipeSteps: recipe.steps,
            suggestion: nil,
            catalogExternalId: recipe.catalogFoodID ?? recipe.externalId,
            catalogKind: recipe.catalogFoodKind ?? .recipe,
            foodType: recipe.foodType ?? .dish,
            hasCompleteNutrition: recipe.hasCompleteNutrition
        )
    }

    private static func ingredient(from item: RecipeIngredient) -> FoodIngredient {
        let unit = (item.unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let quantity = quantityText(from: item)
        if gramUnits.contains(unit), let amount = item.amount {
            return FoodIngredient(name: item.name, grams: amount, quantityText: quantity)
        }
        if milliliterUnits.contains(unit), let amount = item.amount {
            return FoodIngredient(name: item.name, milliliters: amount, quantityText: quantity)
        }
        return FoodIngredient(name: item.name, quantityText: quantity)
    }

    private static let gramUnits = ["g", "gr", "gram", "grams", "г", "грам", "грами", "грамів"]
    private static let milliliterUnits = ["ml", "milliliter", "milliliters", "millilitre", "millilitres", "мл"]

    private static func quantityText(from item: RecipeIngredient) -> String? {
        let unit = (item.unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let amount = item.amount {
            let lowered = unit.lowercased()
            if gramUnits.contains(lowered) {
                return formatGrams(amount)
            }
            if milliliterUnits.contains(lowered) {
                return L10n.format("editMeal.mlValue", Int(amount.rounded()))
            }
            let formatted = formatAmount(amount, unit: unit)
            return formatted.isEmpty ? nil : formatted
        }
        return quantityFromOriginalText(item)
    }

    private static func quantityFromOriginalText(_ item: RecipeIngredient) -> String? {
        let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let original = item.originalText?.trimmingCharacters(in: .whitespacesAndNewlines),
            !original.isEmpty,
            original.caseInsensitiveCompare(name) != .orderedSame
        else { return nil }
        guard let range = original.range(of: name, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return original
        }
        var leftover = original
        leftover.removeSubrange(range)
        leftover = leftover.trimmingCharacters(in: CharacterSet(charactersIn: ",;·").union(.whitespacesAndNewlines))
        return leftover.isEmpty ? nil : leftover
    }

    static func draft(
        from product: FoodProduct,
        imageData: Data?,
        mealType: MealType,
        date: Date
    ) -> ProductDetailsDraft {
        let unit = product.unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let amount = product.amount
        let isMilliliters = milliliterUnits.contains(unit.lowercased())
        let isGrams = gramUnits.contains(unit.lowercased())
        let servingLabel: String
        if let label = product.servingSizeLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            servingLabel = label
        } else if product.kind == .recipe {
            servingLabel = amount.map { formatAmount($0, unit: unit.isEmpty ? "serving" : unit) } ?? ""
        } else if let amount {
            servingLabel = formatAmount(amount, unit: unit)
        } else {
            servingLabel = ""
        }
        let ingredients = product.ingredients.compactMap(parseIngredientLine)
        return ProductDetailsDraft(
            name: product.brand.map { "\($0) · \(product.name)" } ?? product.name,
            servingLabel: servingLabel,
            mealType: mealType,
            date: date,
            servings: 1,
            calories: product.calories ?? 0,
            protein: product.protein ?? 0,
            carbs: product.carbs ?? 0,
            fats: product.fats ?? 0,
            fiber: product.fiber ?? 0,
            sugar: product.sugar ?? 0,
            sodium: product.sodium ?? 0,
            portionGrams: defaultPortionGrams(
                isMilliliters: isMilliliters,
                isGrams: isGrams,
                amount: amount,
                servingLabel: servingLabel
            ),
            portionMilliliters: isMilliliters ? amount : nil,
            ingredients: ingredients,
            tags: [],
            notes: "",
            source: product.source == .unknown ? "search" : product.source.rawValue,
            imageURL: product.imageURL,
            imageData: imageData,
            recipeSteps: product.steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            suggestion: nil,
            catalogExternalId: product.externalId,
            catalogKind: product.kind,
            foodType: product.resolvedFoodType,
            hasCompleteNutrition: product.hasCompleteNutrition != false && [product.calories, product.protein, product.carbs, product.fats].allSatisfy { value in
                value.map { $0.isFinite && $0 >= 0 } == true
            }
        )
    }

    static func draft(from item: PantryItem) -> ProductDetailsDraft {
        let unit = item.unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isMilliliters = ["ml", "мл"].contains(unit.lowercased())
        let quantity = item.quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        let servingLabel = quantity.isEmpty
            ? (item.amount.map { formatAmount($0, unit: unit.isEmpty ? "g" : unit) } ?? "")
            : quantity
        return ProductDetailsDraft(
            name: item.name,
            servingLabel: servingLabel,
            mealType: .snacks,
            date: Date(),
            servings: 1,
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            sugar: 0,
            sodium: 0,
            portionGrams: isMilliliters ? nil : item.amount,
            portionMilliliters: isMilliliters ? item.amount : nil,
            ingredients: [],
            tags: [],
            notes: "",
            source: FoodProductSource.catalog.rawValue,
            imageURL: item.imageURL,
            imageData: item.imageData,
            catalogKind: .product,
            foodType: .product
        )
    }

    private static func formatAmount(_ value: Double, unit: String) -> String {
        let amountText = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value.rounded()))
            : String(value)
        return "\(amountText) \(unit)".trimmingCharacters(in: .whitespaces)
    }

    static func draft(
        from product: BarcodeProduct,
        imageData: Data?,
        mealType: MealType,
        date: Date
    ) -> ProductDetailsDraft {
        let hasPer100g = product.caloriesPer100g != nil
            || product.proteinPer100g != nil
            || product.carbsPer100g != nil
            || product.fatsPer100g != nil
        let servingLabel = cleaned(product.servingSizeLabel)
            ?? cleaned(product.quantityLabel)
            ?? (hasPer100g ? formatGrams(100) : "")
        return ProductDetailsDraft(
            name: product.name,
            servingLabel: servingLabel,
            mealType: mealType,
            date: date,
            servings: 1,
            calories: (hasPer100g ? product.caloriesPer100g : product.caloriesPerServing) ?? 0,
            protein: (hasPer100g ? product.proteinPer100g : product.proteinPerServing) ?? 0,
            carbs: (hasPer100g ? product.carbsPer100g : product.carbsPerServing) ?? 0,
            fats: (hasPer100g ? product.fatsPer100g : product.fatsPerServing) ?? 0,
            fiber: (hasPer100g ? product.fiberPer100g : product.fiberPerServing) ?? 0,
            sugar: (hasPer100g ? product.sugarPer100g : product.sugarPerServing) ?? 0,
            sodium: (hasPer100g ? product.sodiumPer100g : product.sodiumPerServing) ?? 0,
            portionGrams: hasPer100g ? 100 : product.servingGrams,
            portionMilliliters: hasPer100g ? nil : product.servingMilliliters,
            ingredients: [],
            tags: [],
            notes: "",
            source: "barcode",
            imageURL: product.imageURL,
            imageData: imageData,
            suggestion: nil,
            foodType: .product
        )
    }

    static func applyingSuggestion(_ suggestion: FoodHealthSuggestion, to draft: ProductDetailsDraft) -> ProductDetailsDraft {
        var next = draft
        next.name = suggestion.name
        next.servingLabel = suggestion.servingLabel
        next.servings = 1
        next.calories = suggestion.calories
        next.protein = suggestion.protein
        next.carbs = suggestion.carbs
        next.fats = suggestion.fats
        next.fiber = suggestion.fiber
        next.sugar = suggestion.sugar
        next.sodium = suggestion.sodium
        next.portionGrams = suggestion.portionGrams
        next.portionMilliliters = suggestion.portionMilliliters
        next.ingredients = suggestion.ingredients
        next.tags = suggestion.tags
        next.suggestion = nil
        next.foodType = suggestion.foodType
        next.hasCompleteNutrition = nil
        next.catalogExternalId = nil
        next.catalogKind = nil
        next.recipeSteps = []
        next.source = "suggestion"
        return next
    }

    static func scaled(_ draft: ProductDetailsDraft, toGrams newGrams: Double) -> ProductDetailsDraft {
        guard newGrams > 0 else { return draft }
        guard let current = draft.portionGrams, current > 0 else { return draft }
        let factor = newGrams / current
        return multiplied(draft, by: factor, portionGrams: newGrams, portionMilliliters: draft.portionMilliliters.map { $0 * factor })
    }

    static func scaled(_ draft: ProductDetailsDraft, toMilliliters newMilliliters: Double) -> ProductDetailsDraft {
        guard newMilliliters > 0 else { return draft }
        guard let current = draft.portionMilliliters, current > 0 else { return draft }
        let factor = newMilliliters / current
        return multiplied(draft, by: factor, portionGrams: draft.portionGrams.map { $0 * factor }, portionMilliliters: newMilliliters)
    }

    static func replacingIngredient(_ ingredient: FoodIngredient, in draft: ProductDetailsDraft) -> ProductDetailsDraft {
        var next = draft
        guard let index = next.ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return draft }
        next.ingredients[index] = ingredient
        return next
    }

    static func removingIngredient(id: UUID, from draft: ProductDetailsDraft) -> ProductDetailsDraft {
        var next = draft
        next.ingredients.removeAll { $0.id == id }
        return next
    }

    static func parsePortion(_ text: String, defaultIsMilliliters: Bool = false) -> (value: Double, isMilliliters: Bool)? {
        let trimmed = AppUnits.metricInput(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = portionRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }
        guard let valueRange = Range(match.range(at: 1), in: trimmed) else { return nil }
        let raw = trimmed[valueRange].replacingOccurrences(of: ",", with: ".")
        guard let value = Double(raw), value.isFinite, value > 0 else { return nil }
        var unit = ""
        if match.numberOfRanges > 2, let unitRange = Range(match.range(at: 2), in: trimmed) {
            unit = trimmed[unitRange].lowercased()
        }
        let isMilliliters = unit.isEmpty ? defaultIsMilliliters : ["ml", "мл"].contains(unit)
        return (value, isMilliliters)
    }

    static func parseIngredientLine(_ text: String) -> FoodIngredient? {
        let trimmed = AppUnits.metricInput(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let match = ingredientRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let nameRange = Range(match.range(at: 1), in: trimmed),
           let valueRange = Range(match.range(at: 2), in: trimmed) {
            let name = trimmed[nameRange].trimmingCharacters(in: .whitespacesAndNewlines)
            let raw = trimmed[valueRange].replacingOccurrences(of: ",", with: ".")
            let value = Double(raw)
            var unit = ""
            if match.numberOfRanges > 3, let unitRange = Range(match.range(at: 3), in: trimmed) {
                unit = trimmed[unitRange].lowercased()
            }
            let isMilliliters = ["ml", "мл"].contains(unit)
            guard !name.isEmpty else { return nil }
            if isMilliliters {
                return FoodIngredient(name: name, milliliters: value)
            }
            return FoodIngredient(name: name, grams: value)
        }
        if let match = leadingIngredientRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let valueRange = Range(match.range(at: 1), in: trimmed),
           let nameRange = Range(match.range(at: 3), in: trimmed) {
            let name = trimmed[nameRange].trimmingCharacters(in: .whitespacesAndNewlines)
            let raw = trimmed[valueRange].replacingOccurrences(of: ",", with: ".")
            let value = Double(raw)
            var unit = ""
            if let unitRange = Range(match.range(at: 2), in: trimmed) {
                unit = trimmed[unitRange].lowercased()
            }
            let isMilliliters = ["ml", "мл"].contains(unit)
            guard !name.isEmpty else { return nil }
            if isMilliliters {
                return FoodIngredient(name: name, milliliters: value)
            }
            return FoodIngredient(name: name, grams: value)
        }
        return FoodIngredient(name: trimmed)
    }

    static func parseIngredientLines(_ text: String) -> [FoodIngredient] {
        text.replacingOccurrences(of: #"(?<=\d),(?=\d)"#, with: ".", options: .regularExpression)
            .split(whereSeparator: { $0 == "\n" || $0 == ";" || $0 == "," })
            .compactMap { parseIngredientLine(String($0)) }
            .filter { !$0.name.isEmpty }
    }

    static func formatPortion(grams: Double?, milliliters: Double?) -> String {
        if let milliliters, milliliters > 0 {
            return AppUnits.current.volumeText(milliliters)
        }
        if let grams, grams > 0 {
            return AppUnits.current.massText(grams)
        }
        return ""
    }

    static func loggedPortionText(for draft: ProductDetailsDraft) -> String {
        let servings = Double(max(draft.servings, 1))
        let portion = formatPortion(
            grams: draft.portionGrams.map { $0 * servings },
            milliliters: draft.portionMilliliters.map { $0 * servings }
        )
        return portion.isEmpty
            ? L10n.format(draft.servings == 1 ? "recipes.details.serving" : "recipes.details.servings", max(draft.servings, 1))
            : portion
    }

    static func numericPortionText(for draft: ProductDetailsDraft) -> String {
        let servings = Double(max(draft.servings, 1))
        if let milliliters = draft.portionMilliliters, milliliters > 0 {
            return AppUnits.current.number(AppUnits.current.volume(milliliters * servings))
        }
        if let grams = draft.portionGrams, grams > 0 {
            return AppUnits.current.number(AppUnits.current.mass(grams * servings))
        }
        return ""
    }

    static func applyingLoggedPortion(
        _ draft: ProductDetailsDraft,
        value: Double,
        isMilliliters: Bool
    ) -> ProductDetailsDraft {
        guard value.isFinite, value > 0 else { return draft }
        let servings = max(draft.servings, 1)
        let currentPerServing: Double
        if isMilliliters {
            guard let milliliters = draft.portionMilliliters else { return draft }
            currentPerServing = milliliters
        } else {
            guard let grams = draft.portionGrams else { return draft }
            currentPerServing = grams
        }
        guard currentPerServing > 0 else { return draft }
        let proposedServings = value / currentPerServing
        let rounded = proposedServings.rounded()
        if rounded >= 1, rounded <= 99, abs(rounded - proposedServings) <= 1e-9 {
            var next = draft
            next.servings = Int(rounded)
            return next
        }
        let newPerServing = value / Double(servings)
        if isMilliliters {
            return scaled(draft, toMilliliters: newPerServing)
        }
        return scaled(draft, toGrams: newPerServing)
    }

    static func formatNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(Int(value.rounded()))
        }
        return String(format: "%g", value)
    }

    static func formatIngredientAmount(_ ingredient: FoodIngredient) -> String {
        if !AppUnits.current.usesMetric {
            if let ml = ingredient.milliliters { return AppUnits.current.volumeText(ml) }
            if let grams = ingredient.grams { return AppUnits.current.massText(grams) }
        }
        if let quantity = ingredient.quantityText?.trimmingCharacters(in: .whitespacesAndNewlines), !quantity.isEmpty {
            return quantity
        }
        if let milliliters = ingredient.milliliters {
            return AppUnits.current.volumeText(milliliters)
        }
        if let grams = ingredient.grams {
            return AppUnits.current.massText(grams)
        }
        return ""
    }

    static func formatIngredient(_ ingredient: FoodIngredient) -> String {
        let amount = formatIngredientAmount(ingredient)
        if amount.isEmpty {
            return ingredient.name
        }
        return "\(ingredient.name) \(amount)"
    }

    static func formatGrams(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return L10n.format("editMeal.gramsValue", Int(value.rounded()))
        }
        return L10n.format("product.gramsDecimal", value)
    }

    static func formatCalories(_ value: Double) -> String {
        L10n.format("home.kcalValue", Int(value.rounded()))
    }

    static func formatDailyValue(_ percent: Double) -> String {
        L10n.format("product.dv", Int(percent.rounded()))
    }

    static func recipeDetailSubtitle(for recipe: Recipe) -> String {
        recipeDetailSubtitle(for: draft(from: recipe))
    }

    static func recipeDetailSubtitle(for draft: ProductDetailsDraft) -> String {
        let count = max(draft.servings, 1)
        let servingLabel = L10n.format(count == 1 ? "recipes.details.serving" : "recipes.details.servings", count)
        let portion = formatPortion(grams: draft.portionGrams, milliliters: draft.portionMilliliters)
        if portion.isEmpty {
            return servingLabel
        }
        return "\(servingLabel) · \(portion)"
    }

    static func subtitle(for draft: ProductDetailsDraft) -> String {
        let portion = formatPortion(grams: draft.portionGrams, milliliters: draft.portionMilliliters)
        if draft.servingLabel.isEmpty {
            return portion
        }
        if portion.isEmpty {
            return draft.servingLabel
        }
        return AppUnits.current.usesMetric ? "\(draft.servingLabel) (\(portion))" : portion
    }

    static func displayTags(for draft: ProductDetailsDraft) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for badge in draft.nutritionFacts.badges {
            appendTag(badge.title, into: &result, seen: &seen)
        }
        for raw in draft.tags {
            if let badge = FoodNutritionBadge.fromTag(raw) {
                appendTag(badge.title, into: &result, seen: &seen)
            } else {
                appendTag(raw, into: &result, seen: &seen)
            }
        }
        return result
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func appendTag(_ tag: String, into result: inout [String], seen: inout Set<String>) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = trimmed.lowercased()
        guard !seen.contains(key) else { return }
        seen.insert(key)
        result.append(trimmed)
    }

    private static func multiplied(
        _ draft: ProductDetailsDraft,
        by factor: Double,
        portionGrams: Double?,
        portionMilliliters: Double?
    ) -> ProductDetailsDraft {
        var next = draft
        next.calories *= factor
        next.protein *= factor
        next.carbs *= factor
        next.fats *= factor
        next.fiber *= factor
        next.sugar *= factor
        next.sodium *= factor
        next.portionGrams = portionGrams
        next.portionMilliliters = portionMilliliters
        next.ingredients = draft.ingredients.map { scaledIngredient($0, by: factor) }
        return next
    }

    static func scaledIngredient(_ ingredient: FoodIngredient, by factor: Double) -> FoodIngredient {
        guard factor != 1 else { return ingredient }
        var next = ingredient
        next.grams = ingredient.grams.map { $0 * factor }
        next.milliliters = ingredient.milliliters.map { $0 * factor }
        if let grams = next.grams {
            next.quantityText = "\(formatNumber(grams)) g"
        } else if let milliliters = next.milliliters {
            next.quantityText = "\(formatNumber(milliliters)) ml"
        } else if let quantity = ingredient.quantityText {
            let parts = quantity.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            if parts.count == 2, let amount = Double(parts[0].replacingOccurrences(of: ",", with: ".")) {
                next.quantityText = "\(formatNumber(amount * factor)) \(parts[1])"
            }
        }
        return next
    }

    static func fillingDefaultPortion(_ draft: ProductDetailsDraft) -> ProductDetailsDraft {
        if let milliliters = draft.portionMilliliters, milliliters > 0 { return draft }
        if let grams = draft.portionGrams, grams > 0 { return draft }
        var next = draft
        next.portionGrams = nil
        next.portionMilliliters = nil
        if let milliliters = millilitersFromLabel(draft.servingLabel), milliliters > 0 {
            next.portionMilliliters = milliliters
            return next
        }
        next.portionGrams = defaultPortionGrams(
            isMilliliters: false,
            isGrams: true,
            amount: nil,
            servingLabel: draft.servingLabel
        )
        return next
    }

    private static func defaultPortionGrams(
        isMilliliters: Bool,
        isGrams: Bool,
        amount: Double?,
        servingLabel: String
    ) -> Double? {
        if isMilliliters { return nil }
        if let amount, amount > 0, isGrams { return amount }
        if let fromLabel = gramsFromLabel(servingLabel), fromLabel > 0 {
            return fromLabel
        }
        return nil
    }

    static func gramsFromLabel(_ text: String?) -> Double? {
        valueFromLabel(text, milliliters: false)
    }

    static func millilitersFromLabel(_ text: String?) -> Double? {
        valueFromLabel(text, milliliters: true)
    }

    private static func valueFromLabel(_ text: String?, milliliters: Bool) -> Double? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains(where: \.isLetter),
           let parsed = parsePortion(trimmed), parsed.isMilliliters == milliliters {
            return parsed.value
        }
        let regex = milliliters ? millilitersInLabelRegex : gramsInLabelRegex
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let valueRange = Range(match.range(at: 1), in: trimmed) else {
            return nil
        }
        let raw = trimmed[valueRange].replacingOccurrences(of: ",", with: ".")
        guard let value = Double(raw), value > 0 else { return nil }
        return value
    }

    private static let portionRegex = try! NSRegularExpression(
        pattern: #"^\s*(\d+(?:[.,]\d+)?)\s*(g|gr|grams?|ml|мл|г|грам(?:и|ів)?)?\s*$"#,
        options: [.caseInsensitive]
    )

    private static let ingredientRegex = try! NSRegularExpression(
        pattern: #"^(.*?)[\s]+(\d+(?:[.,]\d+)?)\s*(g|gr|grams?|ml|мл|г|грам(?:и|ів)?)?\s*$"#,
        options: [.caseInsensitive]
    )

    private static let leadingIngredientRegex = try! NSRegularExpression(
        pattern: #"^\s*(\d+(?:[.,]\d+)?)\s*(g|gr|grams?|ml|мл|г|грам(?:и|ів)?)\s+(.*)$"#,
        options: [.caseInsensitive]
    )

    private static let gramsInLabelRegex = try! NSRegularExpression(
        pattern: #"(\d+(?:[.,]\d+)?)\s*(g|gr|grams?|г|грам(?:и|ів)?)\b"#,
        options: [.caseInsensitive]
    )

    private static let millilitersInLabelRegex = try! NSRegularExpression(
        pattern: #"(\d+(?:[.,]\d+)?)\s*(ml|мл)\b"#,
        options: [.caseInsensitive]
    )
}
