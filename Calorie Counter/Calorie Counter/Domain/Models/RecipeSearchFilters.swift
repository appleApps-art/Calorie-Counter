import Foundation

struct RecipeSearchFilters: Equatable {
    var mealTypes: [String]
    var cuisines: [String]
    var diets: [String]
    var maxReadyMinutes: Int?
    var maxCalories: Int
    var difficulties: [String]
    var excludedIngredients: [String]

    static let calorieCeiling = 650

    static let empty = RecipeSearchFilters(
        mealTypes: [],
        cuisines: [],
        diets: [],
        maxReadyMinutes: nil,
        maxCalories: calorieCeiling,
        difficulties: [],
        excludedIngredients: []
    )

    var hasActiveConstraints: Bool {
        !mealTypes.isEmpty
            || !cuisines.isEmpty
            || !diets.isEmpty
            || maxReadyMinutes != nil
            || maxCalories < Self.calorieCeiling
            || !difficulties.isEmpty
            || !excludedIngredients.isEmpty
    }

    var searchParameters: RecipeSearchParameters {
        RecipeSearchParameters(
            type: Self.catalogValues(for: mealTypes, in: Self.mealTypeValues),
            cuisine: Self.catalogValues(for: cuisines, in: Self.cuisineValues),
            diet: Self.catalogValues(for: diets, in: Self.dietValues),
            maxReadyTime: maxReadyMinutes,
            maxCalories: maxCalories < Self.calorieCeiling ? maxCalories : nil,
            excludeIngredients: excludedIngredients.isEmpty ? nil : excludedIngredients.joined(separator: ",")
        )
    }

    private static let mealTypeValues = [
        "recipes.filters.breakfast": "breakfast",
        "recipes.filters.lunch": "main course",
        "recipes.filters.dinner": "main course",
        "recipes.filters.snack": "snack"
    ]

    private static let cuisineValues = [
        "recipes.filters.italian": "italian",
        "recipes.filters.asian": "asian",
        "recipes.filters.mexican": "mexican",
        "recipes.filters.greek": "greek"
    ]

    private static let dietValues = [
        "recipes.filters.vegetarian": "vegetarian",
        "recipes.filters.vegan": "vegan",
        "recipes.filters.lean": "vegan"
    ]

    /// The create-recipe form speaks diary meal names and localized titles; the catalog only
    /// understands its own vocabulary, where lunch and dinner are both a main course.
    static func catalogMealType(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case MealType.breakfast.rawValue: return "breakfast"
        case MealType.lunch.rawValue, MealType.dinner.rawValue: return "main course"
        case MealType.snacks.rawValue: return "snack"
        default: return catalogValue(trimmed, in: mealTypeValues)
        }
    }

    static func catalogCuisine(_ value: String) -> String? {
        catalogValue(value, in: cuisineValues)
    }

    static func catalogDiet(_ value: String) -> String? {
        catalogValue(value, in: dietValues)
    }

    private static func catalogValue(_ value: String, in values: [String: String]) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = values[trimmed] { return direct }
        return values.first { L10n.tr($0.key).caseInsensitiveCompare(trimmed) == .orderedSame }?.value
    }

    private static func catalogValues(for titles: [String], in values: [String: String]) -> String? {
        var result: [String] = []
        for title in titles {
            guard let value = values.first(where: { L10n.tr($0.key).caseInsensitiveCompare(title) == .orderedSame })?.value,
                  !result.contains(value) else { continue }
            result.append(value)
        }
        return result.isEmpty ? nil : result.joined(separator: ",")
    }

    func matches(_ recipe: Recipe) -> Bool {
        if let maxReadyMinutes, let minutes = recipe.readyInMinutes, minutes > maxReadyMinutes {
            return false
        }
        if let calories = recipe.calories, calories > Double(maxCalories) {
            return false
        }
        if excludedIngredients.isEmpty { return true }
        let haystack = (
            [recipe.title] + recipe.ingredients.map(\.name) + (recipe.summary.map { [$0] } ?? [])
        )
        .joined(separator: " ")
        .lowercased()
        return !excludedIngredients.contains { ingredient in
            haystack.contains(ingredient.lowercased())
        }
    }

    var resultChips: [RecipeFilterChip] {
        var chips: [RecipeFilterChip] = []
        mealTypes.forEach { title in
            chips.append(RecipeFilterChip(id: "meal-\(title)", title: title, kind: .mealType(title)))
        }
        cuisines.forEach { title in
            chips.append(RecipeFilterChip(id: "cuisine-\(title)", title: title, kind: .cuisine(title)))
        }
        diets.forEach { title in
            chips.append(RecipeFilterChip(id: "diet-\(title)", title: title, kind: .diet(title)))
        }
        if let maxReadyMinutes {
            chips.append(
                RecipeFilterChip(
                    id: "time",
                    title: L10n.format("recipes.filters.underMin", maxReadyMinutes),
                    kind: .cookTime
                )
            )
        }
        if maxCalories < Self.calorieCeiling {
            chips.append(
                RecipeFilterChip(
                    id: "cal",
                    title: L10n.format("recipes.filters.caloriesValue", 0, maxCalories),
                    kind: .calories
                )
            )
        }
        difficulties.forEach { title in
            chips.append(RecipeFilterChip(id: "diff-\(title)", title: title, kind: .difficulty(title)))
        }
        excludedIngredients.forEach { ingredient in
            chips.append(RecipeFilterChip(id: "ex-\(ingredient)", title: ingredient, kind: .excluded(ingredient)))
        }
        return chips
    }

    mutating func remove(chip: RecipeFilterChip) {
        switch chip.kind {
        case .mealType(let value):
            mealTypes.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        case .cuisine(let value):
            cuisines.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        case .diet(let value):
            diets.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        case .cookTime: maxReadyMinutes = nil
        case .calories: maxCalories = Self.calorieCeiling
        case .difficulty(let value):
            difficulties.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        case .excluded(let value):
            excludedIngredients.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        }
    }

    func contains(_ title: String, in values: [String]) -> Bool {
        values.contains { $0.caseInsensitiveCompare(title) == .orderedSame }
    }
}

struct RecipeSearchParameters: Equatable, Encodable {
    var type: String?
    var cuisine: String?
    var diet: String?
    var maxReadyTime: Int?
    var maxCalories: Int?
    var excludeIngredients: String?

    var isEmpty: Bool {
        self == RecipeSearchParameters()
    }
}

struct RecipeFilterChip: Equatable, Identifiable {
    enum Kind: Equatable {
        case mealType(String)
        case cuisine(String)
        case diet(String)
        case cookTime
        case calories
        case difficulty(String)
        case excluded(String)
    }

    let id: String
    let title: String
    let kind: Kind
}

enum RecipeHubTab: Int, CaseIterable, Equatable {
    case all
    case saved
    case mealPlans
}

enum RecipeBrowseSectionKind: String, CaseIterable, Equatable {
    case chosenForYou
    case healthyBreakfast
    case quickLunch
    case dinnerTime
    case mainMeal
    case mexican
    case italian
    case greek
    case asian
    case localCuisine

    static var catalogSections: [RecipeBrowseSectionKind] { allCases.filter { $0 != .localCuisine } }

    var titleKey: String { "recipes.section.\(rawValue)" }

    var query: String {
        switch self {
        case .chosenForYou: return "healthy recipes"
        case .healthyBreakfast: return "healthy breakfast"
        case .quickLunch: return "quick lunch"
        case .dinnerTime: return "dinner"
        case .mainMeal: return "main course"
        case .mexican: return "mexican"
        case .italian: return "italian"
        case .greek: return "greek"
        case .asian: return "asian"
        case .localCuisine: return "local cuisine"
        }
    }

    func searchQuery(using preferences: UserPreferenceProfile) -> String {
        guard self == .chosenForYou else { return query }
        var parts: [String] = []
        if let goal = preferences.goalType, !goal.isEmpty { parts.append(goal) }
        if let diet = preferences.diet, !diet.isEmpty { parts.append(diet) }
        return parts.isEmpty ? query : parts.joined(separator: " ")
    }
}

struct RecipeBrowseSection: Equatable, Identifiable {
    var id: RecipeBrowseSectionKind
    var recipes: [Recipe]
}

struct RecipeSectionPage: Equatable {
    var recipes: [Recipe]
    var nextOffset: Int
    var hasMore: Bool
    var isRetryableFailure = false
}
