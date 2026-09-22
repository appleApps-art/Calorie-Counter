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
        // A title search for the product list used to fill the gap with unrelated dishes that needed
        // other products; no recipe is better than one the user cannot cook.
        guard let recipe = await searchRecipesUseCase.generateRecipe(from: input) else { return nil }
        try? recipeRepository.save(recipe)
        return recipe
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
        // The whole of the user's goals, macros included: calories alone let a plan of pasta
        // and pastries pass as "on target".
        let targets = MealPlanTargets(goals: diary?.goals ?? .default)
        let calorieGoal = targets.calories
        let pools = await collectPools(
            input: input,
            mealTypes: mealTypes,
            dayCount: dayCount,
            calorieGoal: calorieGoal,
            proteinGoal: targets.protein
        )
        let available = mealTypes.filter { !(pools[$0] ?? []).isEmpty }
        guard !available.isEmpty else { return nil }
        let packed = MealPlanPacker.pack(
            pools: pools,
            dayCount: dayCount,
            mealTypes: available,
            targets: targets
        )
        guard !packed.recipes.isEmpty else { return nil }
        let preferences = (try? fetchUserPreferencesUseCase.execute()) ?? .empty
        let title = nextPlanTitle()
        let plan = MealPlan(
            id: UUID(),
            title: title,
            weeks: max(1, (dayCount + 6) / 7),
            imageURL: nil,
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
        calorieGoal: Double,
        proteinGoal: Double = 0
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
                        proteinGoal: proteinGoal,
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
        proteinGoal: Double,
        number: Int
    ) async -> [Recipe] {
        let hasIngredients = !input.ingredients.isEmpty
        var usedIngredients = hasIngredients
        var pool = await search(
            meal: meal,
            input: input,
            mealTypes: mealTypes,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal,
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
                proteinGoal: proteinGoal,
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
                    proteinGoal: proteinGoal,
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
                proteinGoal: proteinGoal,
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
        proteinGoal: Double,
        includeIngredients: Bool,
        applyCalorieWindow: Bool,
        number: Int
    ) async -> [Recipe] {
        let request = Self.spoonacularSearch(
            meal: meal,
            input: input,
            includeIngredients: includeIngredients,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal,
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
        proteinGoal: Double = 0,
        mealTypes: [MealType] = [.breakfast, .lunch, .dinner],
        applyCalorieWindow: Bool = true,
        number: Int = 24
    ) -> SpoonacularRecipeSearch {
        let ingredients = includeIngredients ? Self.includeIngredients(from: input.ingredients) : nil
        let window = applyCalorieWindow
            ? Self.calorieWindow(
                MealPlanPacker.calorieWindow(meal: meal, calorieGoal: calorieGoal, mealTypes: mealTypes),
                dietKey: input.diet
            )
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
            maxReadyTime: input.maxReadyMinutes,
            sort: "popularity",
            minProtein: applyCalorieWindow
                ? Self.proteinFloor(meal: meal, proteinGoal: proteinGoal, mealTypes: mealTypes)
                : nil
        )
    }

    /// A main meal brings at least about half of its share of the day's protein. Snacks are
    /// left free, and the fallback searches without a window drop the floor as well.
    static func proteinFloor(meal: MealType, proteinGoal: Double, mealTypes: [MealType]) -> Int? {
        guard meal != .snacks, proteinGoal > 0 else { return nil }
        let slot = MealPlanPacker.slotTargets(
            mealTypes: mealTypes,
            targets: MealPlanTargets(calories: 1, protein: proteinGoal)
        )[meal]?.protein ?? 0
        let floor = Int((slot * 0.5).rounded())
        return floor > 0 ? floor : nil
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
        // Without a dish type lunch used to come back as sauces, drinks and desserts.
        case .lunch, .dinner: return "main course"
        case .snacks: return "snack"
        }
    }

    /// Only what the user asked for in their own words. The dish type, diet, cuisine and the
    /// calorie window are proper filters; sending "lunch" or "Balance" as search text only pulled
    /// in recipes that happen to carry those words in their title.
    private static func query(for meal: MealType, details: String, dietKey: String?) -> String {
        details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "Lean" and "Weight gain" are not catalog diets; they move the calorie window instead.
    static func calorieWindow(
        _ window: (min: Int, max: Int),
        dietKey: String?
    ) -> (min: Int, max: Int) {
        switch dietKey {
        case "recipes.filters.lean":
            return (window.min, max(window.min + 60, Int((Double(window.max) * 0.8).rounded())))
        case "recipes.filters.weightGain":
            return (Int((Double(window.min) * 1.15).rounded()), Int((Double(window.max) * 1.25).rounded()))
        default:
            return window
        }
    }

    /// Plans are numbered in the order they were made. A name taken from the goal or from the
    /// dishes read either the same for every plan or like an advert, so the list says plainly
    /// which plan is which and the subtitle carries the days and meals.
    func nextPlanTitle() -> String {
        let taken = Set(((try? mealPlanRepository.fetchAll()) ?? []).map { $0.title.lowercased() })
        var number = taken.count + 1
        while taken.contains(Self.planTitle(number: number).lowercased()) {
            number += 1
        }
        return Self.planTitle(number: number)
    }

    static func planTitle(number: Int) -> String {
        L10n.format("recipes.mealPlan.numberedTitle", max(1, number))
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
