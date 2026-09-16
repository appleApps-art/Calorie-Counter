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

    var searchQuery: String {
        var parts: [String] = []
        parts.append(contentsOf: mealTypes)
        parts.append(contentsOf: cuisines)
        parts.append(contentsOf: diets)
        parts.append(contentsOf: difficulties)
        if let maxReadyMinutes {
            parts.append(L10n.format("recipes.filters.underMin", maxReadyMinutes))
        }
        if !excludedIngredients.isEmpty {
            parts.append(excludedIngredients.joined(separator: ", "))
        }
        return parts.joined(separator: " ")
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
