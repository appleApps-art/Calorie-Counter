import Foundation

struct PantryRecipeMatch: Equatable {
    var id: String
    var missedIngredientCount: Int
}

struct PantryRecipeSuggestionPlan: Equatable {
    var ingredients: [String]
    var type: String
    var maxCalories: Int
}

final class SuggestPantryRecipeUseCase {
    static let snackCalorieLimit = 200
    static let maxIngredients = 30
    static let maxCandidates = 6

    private let spoonacularService: SpoonacularServiceProtocol
    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let now: () -> Date
    private let calendar: Calendar

    init(
        spoonacularService: SpoonacularServiceProtocol,
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.spoonacularService = spoonacularService
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.now = now
        self.calendar = calendar
    }

    func plan(for items: [PantryItem]) -> PantryRecipeSuggestionPlan? {
        let date = now()
        let remaining = (try? fetchDailyDiaryUseCase.execute(for: date))?.remainingCalories
            ?? UserGoals.default.calorieTarget
        return Self.plan(for: items, remainingCalories: remaining, date: date, calendar: calendar)
    }

    func execute(_ plan: PantryRecipeSuggestionPlan) async -> Recipe? {
        if let recipe = await closestPantryRecipe(plan) {
            return recipe
        }
        return await includedIngredientRecipe(plan)
    }

    private func closestPantryRecipe(_ plan: PantryRecipeSuggestionPlan) async -> Recipe? {
        let matches = ((try? await spoonacularService.pantryRecipeMatches(ingredients: plan.ingredients, number: 30)) ?? [])
            .enumerated()
            .sorted { ($0.element.missedIngredientCount, $0.offset) < ($1.element.missedIngredientCount, $1.offset) }
            .map(\.element)
        var checked = 0
        var index = matches.startIndex
        while index < matches.endIndex, checked < Self.maxCandidates {
            let missed = matches[index].missedIngredientCount
            var fitting: [Recipe] = []
            while index < matches.endIndex, matches[index].missedIngredientCount == missed, checked < Self.maxCandidates {
                guard !Task.isCancelled else { return nil }
                checked += 1
                if let recipe = try? await spoonacularService.recipeDetails(id: matches[index].id), fits(recipe, plan) {
                    if Self.matches(recipe, type: plan.type) { return recipe }
                    fitting.append(recipe)
                }
                index += 1
            }
            if let first = fitting.first { return first }
            while index < matches.endIndex, matches[index].missedIngredientCount == missed { index += 1 }
        }
        return nil
    }

    private func includedIngredientRecipe(_ plan: PantryRecipeSuggestionPlan) async -> Recipe? {
        for ingredients in Self.ingredientSets(from: plan.ingredients) {
            guard !Task.isCancelled else { return nil }
            let search = SpoonacularRecipeSearch(
                query: "",
                number: 5,
                maxCalories: plan.maxCalories,
                type: plan.type,
                includeIngredients: ingredients.joined(separator: ",")
            )
            let recipes = (try? await spoonacularService.searchRecipes(search)) ?? []
            for candidate in recipes where candidate.hasPhoto && !candidate.looksLikeListingPage {
                guard !Task.isCancelled else { return nil }
                guard let id = candidate.externalId,
                      let recipe = try? await spoonacularService.recipeDetails(id: id),
                      fits(recipe, plan) else { continue }
                return recipe
            }
        }
        return nil
    }

    private func fits(_ recipe: Recipe, _ plan: PantryRecipeSuggestionPlan) -> Bool {
        guard recipe.hasPhoto, !recipe.looksLikeListingPage,
              SearchRecipesUseCase.hasCompleteDetails(recipe) else { return false }
        if let calories = recipe.calories, calories > Double(plan.maxCalories) { return false }
        return true
    }

    static func ingredientSets(from names: [String]) -> [[String]] {
        let urgent = Array(names.prefix(3))
        var sets: [[String]] = []
        for first in urgent.indices {
            for second in urgent.indices where second > first {
                sets.append([urgent[first], urgent[second]])
            }
        }
        sets.append(contentsOf: urgent.prefix(2).map { [$0] })
        return sets
    }

    static func matches(_ recipe: Recipe, type: String) -> Bool {
        let accepted: Set<String>
        switch type {
        case "breakfast": accepted = ["breakfast", "morning meal", "brunch"]
        case "snack": accepted = ["snack", "appetizer", "fingerfood", "antipasti", "starter"]
        default: accepted = ["main course", "main dish", "lunch", "dinner"]
        }
        return recipe.dishTypes.contains { accepted.contains($0.lowercased()) }
    }

    static func plan(
        for items: [PantryItem],
        remainingCalories: Double,
        date: Date,
        calendar: Calendar
    ) -> PantryRecipeSuggestionPlan? {
        let names = rankedIngredientNames(items, date: date, calendar: calendar)
        guard !names.isEmpty else { return nil }
        let isOverBudget = remainingCalories <= Double(snackCalorieLimit)
        return PantryRecipeSuggestionPlan(
            ingredients: Array(names.prefix(maxIngredients)),
            type: isOverBudget ? "snack" : dishType(hour: calendar.component(.hour, from: date)),
            maxCalories: isOverBudget ? snackCalorieLimit : Int(remainingCalories.rounded(.down))
        )
    }

    static func rankedIngredientNames(_ items: [PantryItem], date: Date, calendar: Calendar) -> [String] {
        let today = calendar.startOfDay(for: date)
        var seen = Set<String>()
        return items
            .filter { item in
                guard let useBy = item.useBy else { return true }
                return calendar.startOfDay(for: useBy) >= today
            }
            .sorted { left, right in
                switch (left.useBy, right.useBy) {
                case let (leftDate?, rightDate?): return leftDate < rightDate
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return left.updatedAt > right.updatedAt
                }
            }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    static func dishType(hour: Int) -> String {
        switch hour {
        case 5..<11: return "breakfast"
        case 11..<21: return "main course"
        default: return "snack"
        }
    }
}
