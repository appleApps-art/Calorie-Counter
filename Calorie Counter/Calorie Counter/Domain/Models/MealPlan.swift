import Foundation

struct MealPlanSlot: Equatable {
    var mealType: MealType
    var recipeIndex: Int
    var recipe: Recipe
}

struct MealPlanDay: Equatable {
    var index: Int
    var slots: [MealPlanSlot]

    var title: String {
        L10n.format("recipes.mealPlan.day", index + 1)
    }
}

struct MealPlan: Equatable, Identifiable {
    var id: UUID
    var title: String
    var weeks: Int
    var imageURL: URL?
    var recipes: [Recipe]
    var createdAt: Date
    var dayLayouts: [Int] = []
    var mealTypeKeys: [String] = []

    var mealCount: Int { recipes.count }

    var dayCount: Int {
        let layouts = resolvedLayouts()
        if !layouts.isEmpty { return layouts.count }
        return max(1, Int(ceil(Double(max(recipes.count, 1)) / Double(Self.fallbackMealsPerDay))))
    }

    var subtitle: String {
        if dayCount == 1 {
            return L10n.format("recipes.mealPlan.subtitleOneDay", mealCount)
        }
        return L10n.format("recipes.mealPlan.subtitleDays", dayCount, mealCount)
    }

    func days() -> [MealPlanDay] {
        guard !recipes.isEmpty else {
            return [MealPlanDay(index: 0, slots: [])]
        }
        let mealTypes = resolvedMealTypes()
        var result: [MealPlanDay] = []
        var start = 0
        resolvedLayouts().forEach { count in
            let end = min(start + max(count, 0), recipes.count)
            guard end > start else { return }
            let slots = (start..<end).map { index in
                MealPlanSlot(
                    mealType: Self.mealType(at: index - start, types: mealTypes),
                    recipeIndex: index,
                    recipe: recipes[index]
                )
            }
            result.append(MealPlanDay(index: result.count, slots: slots))
            start = end
        }
        return result.isEmpty ? [MealPlanDay(index: 0, slots: [])] : result
    }

    mutating func replacingRecipe(at index: Int, with recipe: Recipe) {
        guard recipes.indices.contains(index) else { return }
        recipes[index] = recipe
        if index == 0 {
            imageURL = recipe.imageURL
        }
    }

    private func resolvedMealTypes() -> [MealType] {
        let mapped = mealTypeKeys.compactMap(MealType.init(rawValue:))
        return mapped.isEmpty ? Self.fallbackMealTypes : mapped
    }

    private func resolvedLayouts() -> [Int] {
        let trimmed = dayLayouts.filter { $0 > 0 }
        let total = trimmed.reduce(0, +)
        if !trimmed.isEmpty, total == recipes.count {
            return trimmed
        }
        var result: [Int] = []
        stride(from: 0, to: recipes.count, by: Self.fallbackMealsPerDay).forEach { start in
            result.append(min(Self.fallbackMealsPerDay, recipes.count - start))
        }
        return result
    }

    private static func mealType(at offset: Int, types: [MealType]) -> MealType {
        if types.indices.contains(offset) { return types[offset] }
        return types.last ?? .dinner
    }

    private static let fallbackMealsPerDay = 3
    private static let fallbackMealTypes: [MealType] = [.breakfast, .lunch, .dinner]
}
