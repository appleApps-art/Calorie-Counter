import Foundation

struct FoodLogProposal: Equatable, Codable {
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
    var imageURL: URL? = nil
    var ingredientLines: [String] = []
    var recipeSteps: [String] = []
    var catalogExternalId: String? = nil
    var catalogKind: FoodProductKind? = nil
    var foodType: FoodType? = nil

    func toFoodEntry(date: Date = Date(), id: UUID = UUID()) -> FoodEntry {
        let kind: FoodProductKind?
        if let catalogKind {
            kind = catalogKind
        } else if !recipeSteps.isEmpty {
            kind = .recipe
        } else {
            kind = nil
        }
        return FoodEntry(
            id: id,
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
            imageURL: imageURL,
            ingredientLines: ingredientLines,
            recipeSteps: recipeSteps,
            catalogExternalId: catalogExternalId,
            catalogKind: kind,
            foodType: foodType
        )
    }

    enum CodingKeys: String, CodingKey {
        case name, mealType, calories, protein, carbs, fats, fiber, sugar, sodium
        case portionGrams, portionMilliliters, confidence, notes, source, imageURL
        case ingredientLines, recipeSteps, catalogExternalId, catalogKind, foodType
    }

    init(
        name: String,
        mealType: MealType,
        calories: Double,
        protein: Double,
        carbs: Double,
        fats: Double,
        fiber: Double = 0,
        sugar: Double = 0,
        sodium: Double = 0,
        portionGrams: Double? = nil,
        portionMilliliters: Double? = nil,
        confidence: Double = 0.5,
        notes: String = "",
        source: String = "text",
        imageURL: URL? = nil,
        ingredientLines: [String] = [],
        recipeSteps: [String] = [],
        catalogExternalId: String? = nil,
        catalogKind: FoodProductKind? = nil,
        foodType: FoodType? = nil
    ) {
        self.name = name
        self.mealType = mealType
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.portionGrams = portionGrams
        self.portionMilliliters = portionMilliliters
        self.confidence = confidence
        self.notes = notes
        self.source = source
        self.imageURL = imageURL
        self.ingredientLines = ingredientLines
        self.recipeSteps = recipeSteps
        self.catalogExternalId = catalogExternalId
        self.catalogKind = catalogKind
        self.foodType = foodType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        mealType = try container.decode(MealType.self, forKey: .mealType)
        calories = try container.decodeIfPresent(Double.self, forKey: .calories) ?? 0
        protein = try container.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        carbs = try container.decodeIfPresent(Double.self, forKey: .carbs) ?? 0
        fats = try container.decodeIfPresent(Double.self, forKey: .fats) ?? 0
        fiber = try container.decodeIfPresent(Double.self, forKey: .fiber) ?? 0
        sugar = try container.decodeIfPresent(Double.self, forKey: .sugar) ?? 0
        sodium = try container.decodeIfPresent(Double.self, forKey: .sodium) ?? 0
        portionGrams = try container.decodeIfPresent(Double.self, forKey: .portionGrams)
        portionMilliliters = try container.decodeIfPresent(Double.self, forKey: .portionMilliliters)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.5
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "text"
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        ingredientLines = try container.decodeIfPresent([String].self, forKey: .ingredientLines) ?? []
        recipeSteps = try container.decodeIfPresent([String].self, forKey: .recipeSteps) ?? []
        catalogExternalId = try container.decodeIfPresent(String.self, forKey: .catalogExternalId)
        catalogKind = try container.decodeIfPresent(String.self, forKey: .catalogKind).flatMap(FoodProductKind.init(rawValue:))
        foodType = try container.decodeIfPresent(String.self, forKey: .foodType).flatMap(FoodType.init(rawValue:))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(mealType, forKey: .mealType)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(fats, forKey: .fats)
        try container.encode(fiber, forKey: .fiber)
        try container.encode(sugar, forKey: .sugar)
        try container.encode(sodium, forKey: .sodium)
        try container.encodeIfPresent(portionGrams, forKey: .portionGrams)
        try container.encodeIfPresent(portionMilliliters, forKey: .portionMilliliters)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(notes, forKey: .notes)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(ingredientLines, forKey: .ingredientLines)
        try container.encode(recipeSteps, forKey: .recipeSteps)
        try container.encodeIfPresent(catalogExternalId, forKey: .catalogExternalId)
        try container.encodeIfPresent(catalogKind?.rawValue, forKey: .catalogKind)
        try container.encodeIfPresent(foodType?.rawValue, forKey: .foodType)
    }
}

struct FoodReplaceProposal: Equatable {
    var targetEntryId: UUID?
    var targetName: String?
    var targetMealType: MealType?
    var newItem: FoodLogProposal
    var reason: String?
}

struct FoodSwapItem: Equatable, Codable {
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var portionLabel: String?
    var imageURL: URL? = nil
}

struct FoodSwapProposal: Equatable, Codable {
    var original: FoodSwapItem
    var alternative: FoodSwapItem
    var savingsKcal: Double
    var savingsNote: String?
    var applyToEntryId: UUID?

    func asFoodLogProposal(mealType: MealType = .snacks) -> FoodLogProposal {
        let milliliters = ProductDetailsMath.millilitersFromLabel(alternative.portionLabel)
        let hasUnit = alternative.portionLabel?.rangeOfCharacter(from: .letters) != nil
        let grams = milliliters == nil && hasUnit ? ProductDetailsMath.gramsFromLabel(alternative.portionLabel) : nil
        return FoodLogProposal(
            name: alternative.name,
            mealType: mealType,
            calories: alternative.calories,
            protein: alternative.protein,
            carbs: alternative.carbs,
            fats: alternative.fats,
            portionGrams: grams,
            portionMilliliters: milliliters,
            notes: savingsNote ?? "",
            source: "swap",
            imageURL: alternative.imageURL
        )
    }
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
    var imageURL: URL? = nil
    var ingredients: [String]
    var steps: [String] = []
    var mealType: MealType? = nil
    var portionGrams: Double? = nil
    var portionMilliliters: Double? = nil
    var fiber: Double? = nil
    var sugar: Double? = nil
    /// Milligrams.
    var sodium: Double? = nil

    var needsNutritionEnrichment: Bool {
        calories <= 0 || (protein == 0 && carbs == 0 && fats == 0)
    }

    func asFoodLogProposal(mealType: MealType) -> FoodLogProposal {
        FoodLogProposal(
            name: title,
            mealType: mealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber ?? 0,
            sugar: sugar ?? 0,
            sodium: sodium ?? 0,
            portionGrams: portionGrams,
            portionMilliliters: portionMilliliters,
            notes: summary,
            source: "suggestion",
            imageURL: imageURL,
            ingredientLines: ingredients,
            recipeSteps: steps,
            catalogExternalId: externalRecipeId,
            catalogKind: .recipe
        )
    }

    func merging(_ product: FoodProduct) -> MealSuggestionOption {
        var next = self
        if next.calories <= 0, let calories = product.calories, calories > 0 {
            next.calories = calories
        }
        if next.protein == 0, let protein = product.protein {
            next.protein = protein
        }
        if next.carbs == 0, let carbs = product.carbs {
            next.carbs = carbs
        }
        if next.fats == 0, let fats = product.fats {
            next.fats = fats
        }
        if next.fiber == nil { next.fiber = product.fiber }
        if next.sugar == nil { next.sugar = product.sugar }
        if next.sodium == nil { next.sodium = product.sodium }
        if next.imageURL == nil {
            next.imageURL = product.imageURL
        }
        if next.ingredients.isEmpty {
            next.ingredients = product.ingredients
        }
        if next.steps.isEmpty {
            next.steps = product.steps
        }
        if (next.externalRecipeId ?? "").isEmpty, !product.externalId.isEmpty {
            next.externalRecipeId = product.externalId
        }
        return next
    }
}

extension MealSuggestionOption: Codable {
    enum CodingKeys: String, CodingKey {
        case title, summary, calories, protein, carbs, fats
        case cookTimeMinutes, externalRecipeId, imageURL, ingredients, steps, mealType
        case portionGrams, portionMilliliters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        calories = try container.decodeIfPresent(Double.self, forKey: .calories) ?? 0
        protein = try container.decodeIfPresent(Double.self, forKey: .protein) ?? 0
        carbs = try container.decodeIfPresent(Double.self, forKey: .carbs) ?? 0
        fats = try container.decodeIfPresent(Double.self, forKey: .fats) ?? 0
        cookTimeMinutes = try container.decodeIfPresent(Double.self, forKey: .cookTimeMinutes)
        externalRecipeId = try container.decodeIfPresent(String.self, forKey: .externalRecipeId)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        steps = try container.decodeIfPresent([String].self, forKey: .steps) ?? []
        mealType = try container.decodeIfPresent(MealType.self, forKey: .mealType)
        portionGrams = try container.decodeIfPresent(Double.self, forKey: .portionGrams)
        portionMilliliters = try container.decodeIfPresent(Double.self, forKey: .portionMilliliters)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(fats, forKey: .fats)
        try container.encodeIfPresent(cookTimeMinutes, forKey: .cookTimeMinutes)
        try container.encodeIfPresent(externalRecipeId, forKey: .externalRecipeId)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(steps, forKey: .steps)
        try container.encodeIfPresent(mealType, forKey: .mealType)
        try container.encodeIfPresent(portionGrams, forKey: .portionGrams)
        try container.encodeIfPresent(portionMilliliters, forKey: .portionMilliliters)
    }
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
    var imageURL: URL? = nil
    var ingredients: [String]
    var steps: [String]
    var fiber: Double? = nil
    var sugar: Double? = nil
    var sodium: Double? = nil

    func toRecipe() -> Recipe {
        Recipe(
            id: UUID(),
            externalId: externalRecipeId,
            title: title,
            summary: summary,
            imageURL: imageURL,
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
            sourceName: "AI",
            origin: (externalRecipeId ?? "").hasPrefix("ai-") || externalRecipeId == nil ? .openAI : .spoonacular,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
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
    case swapMealPlanMeal(MealPlanSwapProposal)
    case logWater(WaterLogProposal)
    case savePreference(PreferenceSaveProposal)
}
