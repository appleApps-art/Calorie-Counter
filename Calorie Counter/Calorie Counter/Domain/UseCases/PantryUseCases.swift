import Foundation

final class FetchPantryItemsUseCase {
    private let pantryRepository: PantryRepositoryProtocol

    init(pantryRepository: PantryRepositoryProtocol) {
        self.pantryRepository = pantryRepository
    }

    func execute() throws -> [PantryItem] {
        try pantryRepository.fetchAll()
    }
}

final class SavePantryItemUseCase {
    private let pantryRepository: PantryRepositoryProtocol

    init(pantryRepository: PantryRepositoryProtocol) {
        self.pantryRepository = pantryRepository
    }

    func execute(_ item: PantryItem) throws {
        let existing = try pantryRepository.fetchAll()
        if existing.contains(where: { $0.id == item.id }) {
            var toSave = item
            toSave.updatedAt = Date()
            try pantryRepository.save(toSave)
            return
        }
        let matches = existing.filter { PantryItem.isSameProduct($0, item) }
        guard let primary = matches.first else {
            var toSave = item
            toSave.updatedAt = Date()
            try pantryRepository.save(toSave)
            return
        }
        var merged = matches.dropFirst().reduce(primary) { $0.mergingIncoming($1) }
        merged = merged.mergingIncoming(item)
        merged.updatedAt = Date()
        try pantryRepository.save(merged)
        let extraIDs = matches.dropFirst().map(\.id)
        if !extraIDs.isEmpty {
            try pantryRepository.delete(ids: extraIDs)
        }
    }

    func execute(items: [PantryItem]) throws {
        try items.forEach { try execute($0) }
    }
}

final class DeletePantryItemsUseCase {
    private let pantryRepository: PantryRepositoryProtocol

    init(pantryRepository: PantryRepositoryProtocol) {
        self.pantryRepository = pantryRepository
    }

    func execute(ids: [UUID]) throws {
        try pantryRepository.delete(ids: ids)
    }
}

final class FetchMealPlansUseCase {
    private let mealPlanRepository: MealPlanRepositoryProtocol

    init(mealPlanRepository: MealPlanRepositoryProtocol) {
        self.mealPlanRepository = mealPlanRepository
    }

    func execute() throws -> [MealPlan] {
        try mealPlanRepository.fetchAll()
    }
}

final class CreateRecipeUseCase {
    private let searchRecipesUseCase: SearchRecipesUseCase
    private let recipeRepository: RecipeRepositoryProtocol

    init(
        searchRecipesUseCase: SearchRecipesUseCase,
        recipeRepository: RecipeRepositoryProtocol
    ) {
        self.searchRecipesUseCase = searchRecipesUseCase
        self.recipeRepository = recipeRepository
    }

    func execute(_ input: RecipeGenerationInput) async throws -> Recipe? {
        let recipes = try await searchRecipesUseCase.generateRecipes(
            query: Self.query(from: input),
            filters: Self.filters(from: input)
        )
        guard let recipe = recipes.first else { return nil }
        try? recipeRepository.save(recipe)
        return recipe
    }

    static func query(from input: RecipeGenerationInput) -> String {
        var parts = input.ingredients
        let details = input.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !details.isEmpty {
            parts.append(details)
        }
        return parts.joined(separator: ", ")
    }

    static func filters(from input: RecipeGenerationInput) -> RecipeSearchFilters {
        var filters = RecipeSearchFilters.empty
        filters.mealTypes = input.mealTypes
        if let cuisine = input.cuisine { filters.cuisines = [cuisine] }
        if let diet = input.diet { filters.diets = [diet] }
        filters.maxReadyMinutes = input.maxReadyMinutes
        if let maxCalories = input.maxCalories {
            filters.maxCalories = maxCalories
        }
        return filters
    }
}

final class CreateMealPlanUseCase {
    private let mealPlanRepository: MealPlanRepositoryProtocol
    private let spoonacularService: SpoonacularServiceProtocol
    private let fetchUserPreferencesUseCase: FetchUserPreferencesUseCase
    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let pantryRepository: PantryRepositoryProtocol

    init(
        mealPlanRepository: MealPlanRepositoryProtocol,
        spoonacularService: SpoonacularServiceProtocol,
        fetchUserPreferencesUseCase: FetchUserPreferencesUseCase,
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        pantryRepository: PantryRepositoryProtocol
    ) {
        self.mealPlanRepository = mealPlanRepository
        self.spoonacularService = spoonacularService
        self.fetchUserPreferencesUseCase = fetchUserPreferencesUseCase
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.pantryRepository = pantryRepository
    }

    func execute(_ input: RecipeGenerationInput) async throws -> MealPlan? {
        let mealTypes = MealPlanPacker.orderedMealTypes(Self.mealTypes(from: input))
        let dayCount = Self.dayCount(from: input)
        let diary = try? fetchDailyDiaryUseCase.execute()
        let calorieGoal = diary?.goals.calorieTarget ?? UserGoals.default.calorieTarget
        let proteinGoal = diary?.goals.proteinTarget ?? UserGoals.default.proteinTarget
        let pools = await collectPools(
            input: input,
            mealTypes: mealTypes,
            dayCount: dayCount,
            calorieGoal: calorieGoal
        )
        let available = mealTypes.filter { !(pools[$0] ?? []).isEmpty }
        guard !available.isEmpty else { return nil }
        let packed = MealPlanPacker.pack(
            pools: pools,
            dayCount: dayCount,
            mealTypes: available,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal
        )
        guard !packed.recipes.isEmpty else { return nil }
        let preferences = (try? fetchUserPreferencesUseCase.execute()) ?? .empty
        let title = Self.planTitle(
            input: input,
            preferences: preferences,
            fallback: packed.recipes.first?.title
        )
        let plan = MealPlan(
            id: UUID(),
            title: title,
            weeks: max(1, (dayCount + 6) / 7),
            imageURL: packed.recipes.first?.imageURL,
            recipes: packed.recipes,
            createdAt: Date(),
            dayLayouts: packed.layouts,
            mealTypeKeys: available.map(\.rawValue)
        )
        try mealPlanRepository.save(plan)
        return plan
    }

    private func collectPools(
        input: RecipeGenerationInput,
        mealTypes: [MealType],
        dayCount: Int,
        calorieGoal: Double
    ) async -> [MealType: [Recipe]] {
        let number = Self.searchNumber(dayCount: dayCount)
        var result: [MealType: [Recipe]] = [:]
        await withTaskGroup(of: (MealType, [Recipe]).self) { group in
            mealTypes.forEach { meal in
                group.addTask {
                    let recipes = await self.recipes(
                        for: meal,
                        input: input,
                        mealTypes: mealTypes,
                        dayCount: dayCount,
                        calorieGoal: calorieGoal,
                        number: number
                    )
                    return (meal, recipes)
                }
            }
            for await (meal, recipes) in group {
                result[meal] = recipes
            }
        }
        return result
    }

    private func recipes(
        for meal: MealType,
        input: RecipeGenerationInput,
        mealTypes: [MealType],
        dayCount: Int,
        calorieGoal: Double,
        number: Int
    ) async -> [Recipe] {
        let hasIngredients = !input.ingredients.isEmpty
        var usedIngredients = hasIngredients
        var pool = await search(
            meal: meal,
            input: input,
            mealTypes: mealTypes,
            calorieGoal: calorieGoal,
            includeIngredients: usedIngredients,
            applyCalorieWindow: true,
            number: number
        )
        if pool.isEmpty, hasIngredients {
            usedIngredients = false
            pool = await search(
                meal: meal,
                input: input,
                mealTypes: mealTypes,
                calorieGoal: calorieGoal,
                includeIngredients: false,
                applyCalorieWindow: true,
                number: number
            )
        }
        if pool.count < max(1, dayCount) {
            pool = Self.mergingUnique(
                pool,
                await search(
                    meal: meal,
                    input: input,
                    mealTypes: mealTypes,
                    calorieGoal: calorieGoal,
                    includeIngredients: usedIngredients,
                    applyCalorieWindow: false,
                    number: number
                )
            )
        }
        if pool.isEmpty {
            pool = await search(
                meal: meal,
                input: input,
                mealTypes: mealTypes,
                calorieGoal: calorieGoal,
                includeIngredients: false,
                applyCalorieWindow: false,
                number: number
            )
        }
        return pool.filter { !$0.looksLikeListingPage }
    }

    private func search(
        meal: MealType,
        input: RecipeGenerationInput,
        mealTypes: [MealType],
        calorieGoal: Double,
        includeIngredients: Bool,
        applyCalorieWindow: Bool,
        number: Int
    ) async -> [Recipe] {
        let request = Self.spoonacularSearch(
            meal: meal,
            input: input,
            includeIngredients: includeIngredients,
            calorieGoal: calorieGoal,
            mealTypes: mealTypes,
            applyCalorieWindow: applyCalorieWindow,
            number: number
        )
        return (try? await spoonacularService.searchRecipes(request)) ?? []
    }

    static func searchNumber(dayCount: Int) -> Int {
        min(30, max(16, dayCount * 3))
    }

    static func spoonacularSearch(
        meal: MealType,
        input: RecipeGenerationInput,
        includeIngredients: Bool,
        calorieGoal: Double = UserGoals.default.calorieTarget,
        mealTypes: [MealType] = [.breakfast, .lunch, .dinner],
        applyCalorieWindow: Bool = true,
        number: Int = 24
    ) -> SpoonacularRecipeSearch {
        let ingredients = includeIngredients ? Self.includeIngredients(from: input.ingredients) : nil
        let window = applyCalorieWindow
            ? MealPlanPacker.calorieWindow(meal: meal, calorieGoal: calorieGoal, mealTypes: mealTypes)
            : nil
        return SpoonacularRecipeSearch(
            query: Self.query(for: meal, details: input.details, dietKey: input.diet),
            number: number,
            minCalories: window?.min,
            maxCalories: window?.max,
            cuisine: Self.cuisine(from: input.cuisine),
            diet: Self.diet(from: input.diet),
            type: Self.dishType(from: meal),
            includeIngredients: ingredients,
            maxReadyTime: input.maxReadyMinutes
        )
    }

    static func cuisine(from raw: String?) -> String? {
        switch raw {
        case "recipes.filters.italian": return "Italian"
        case "recipes.filters.asian": return "Asian"
        case "recipes.filters.mexican": return "Mexican"
        case "recipes.filters.greek": return "Greek"
        default: return nil
        }
    }

    static func diet(from raw: String?) -> String? {
        switch raw {
        case "recipes.filters.vegetarian": return "vegetarian"
        case "recipes.filters.vegan": return "vegan"
        default: return nil
        }
    }

    static func dishType(from meal: MealType) -> String? {
        switch meal {
        case .breakfast: return "breakfast"
        case .lunch: return nil
        case .dinner: return "main course"
        case .snacks: return "snack"
        }
    }

    private static func query(for meal: MealType, details: String, dietKey: String?) -> String {
        var parts: [String] = []
        switch meal {
        case .breakfast: parts.append("breakfast")
        case .lunch: parts.append("lunch")
        case .dinner: parts.append("dinner")
        case .snacks: parts.append("snack")
        }
        if let term = dietQueryTerm(from: dietKey) {
            parts.append(term)
        }
        let extra = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty {
            parts.append(extra)
        }
        return parts.joined(separator: " ")
    }

    private static func dietQueryTerm(from raw: String?) -> String? {
        switch raw {
        case "recipes.filters.lean": return "Lean"
        case "recipes.filters.weightGain": return "Weight Gain"
        case "recipes.filters.balance": return "Balance"
        default: return nil
        }
    }

    private static func planTitle(
        input: RecipeGenerationInput,
        preferences: UserPreferenceProfile,
        fallback: String?
    ) -> String {
        if let diet = input.diet?.trimmingCharacters(in: .whitespacesAndNewlines), !diet.isEmpty {
            return diet.hasPrefix("recipes.") ? L10n.tr(diet) : diet
        }
        if let goal = preferences.goalType?.trimmingCharacters(in: .whitespacesAndNewlines), !goal.isEmpty {
            return goal
        }
        if let diet = preferences.diet?.trimmingCharacters(in: .whitespacesAndNewlines), !diet.isEmpty {
            return diet
        }
        return fallback ?? L10n.tr("recipes.tab.mealPlans")
    }

    private static func includeIngredients(from names: [String]) -> String? {
        let parts = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let clipped = Array(parts.prefix(6))
        guard !clipped.isEmpty else { return nil }
        return clipped.joined(separator: ", ")
    }

    private static func mergingUnique(_ existing: [Recipe], _ extra: [Recipe]) -> [Recipe] {
        var result = existing
        extra.forEach { recipe in
            let duplicate = result.contains { candidate in
                if let left = candidate.externalId, let right = recipe.externalId, !left.isEmpty, left == right {
                    return true
                }
                return candidate.title.caseInsensitiveCompare(recipe.title) == .orderedSame
            }
            if !duplicate {
                result.append(recipe)
            }
        }
        return result
    }

    private static func mealTypes(from input: RecipeGenerationInput) -> [MealType] {
        var seen = Set<MealType>()
        var result: [MealType] = []
        input.mealTypes.forEach { raw in
            guard let match = mealType(from: raw), seen.insert(match).inserted else { return }
            result.append(match)
        }
        return result.isEmpty ? [.breakfast, .lunch, .dinner] : result
    }

    private static func mealType(from raw: String) -> MealType? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard !lower.isEmpty else { return nil }
        if let exact = MealType(rawValue: lower) {
            return exact
        }
        if lower == "snack" || lower.hasPrefix("snack") {
            return .snacks
        }
        return MealType.allCases.first { type in
            trimmed.caseInsensitiveCompare(type.localizedTitle) == .orderedSame
        }
    }

    private static func dayCount(from input: RecipeGenerationInput) -> Int {
        guard let start = input.startDate, let end = input.endDate else { return 3 }
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days + 1)
    }
}
