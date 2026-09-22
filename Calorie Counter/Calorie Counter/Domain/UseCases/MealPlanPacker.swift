import Foundation

/// What a day of the plan should add up to: the user's own calorie and macro goals.
struct MealPlanTargets: Equatable {
    var calories: Double
    var protein: Double
    /// Zero when unknown: that nutrient is then left out of the balance.
    var carbs: Double
    var fats: Double

    init(calories: Double, protein: Double, carbs: Double = 0, fats: Double = 0) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
    }

    init(goals: UserGoals) {
        self.init(
            calories: goals.calorieTarget,
            protein: goals.proteinTarget,
            carbs: goals.carbsTarget,
            fats: goals.fatsTarget
        )
    }

    func scaled(by share: Double) -> MealPlanTargets {
        MealPlanTargets(
            calories: calories * share,
            protein: protein * share,
            carbs: carbs * share,
            fats: fats * share
        )
    }
}

enum MealPlanPacker {
    static func calorieShare(for meal: MealType) -> Double {
        switch meal {
        case .breakfast: return 0.32
        case .lunch: return 0.30
        case .dinner: return 0.26
        case .snacks: return 0.12
        }
    }

    static func orderedMealTypes(_ mealTypes: [MealType]) -> [MealType] {
        let selected = Set(mealTypes)
        return MealType.allCases.filter { selected.contains($0) }
    }

    static func slotTargets(
        mealTypes: [MealType],
        calorieGoal: Double,
        proteinGoal: Double
    ) -> [MealType: (calories: Double, protein: Double)] {
        let types = orderedMealTypes(mealTypes)
        let weight = types.reduce(0) { $0 + calorieShare(for: $1) }
        let safe = max(weight, 0.01)
        var result: [MealType: (calories: Double, protein: Double)] = [:]
        types.forEach { meal in
            let share = calorieShare(for: meal) / safe
            result[meal] = (max(calorieGoal, 1) * share, max(proteinGoal, 0) * share)
        }
        return result
    }

    static func calorieWindow(
        meal: MealType,
        calorieGoal: Double,
        mealTypes: [MealType]
    ) -> (min: Int, max: Int) {
        let target = slotTargets(
            mealTypes: mealTypes,
            calorieGoal: calorieGoal,
            proteinGoal: 0
        )[meal]?.calories ?? estimatedCalories(for: meal)
        let minimum = max(80, Int((target * 0.55).rounded()))
        let maximum = max(minimum + 60, Int((target * 1.45).rounded()))
        return (minimum, maximum)
    }

    static func pack(
        pools: [MealType: [Recipe]],
        dayCount: Int,
        mealTypes: [MealType],
        calorieGoal: Double,
        proteinGoal: Double = UserGoals.default.proteinTarget
    ) -> (recipes: [Recipe], layouts: [Int]) {
        pack(
            pools: pools,
            dayCount: dayCount,
            mealTypes: mealTypes,
            targets: MealPlanTargets(calories: calorieGoal, protein: proteinGoal)
        )
    }

    /// Picks each day's dishes so the day lands on the user's calories *and* macros, not calories
    /// alone: a plan that hits 1,800 kcal on pasta and cake is exactly what Bity calls unbalanced.
    static func pack(
        pools: [MealType: [Recipe]],
        dayCount: Int,
        mealTypes: [MealType],
        targets: MealPlanTargets
    ) -> (recipes: [Recipe], layouts: [Int]) {
        let types = orderedMealTypes(mealTypes).filter { !(pools[$0] ?? []).isEmpty }
        guard !types.isEmpty else { return ([], []) }
        let slots = slotTargets(mealTypes: types, targets: targets)
        var used: [String: Int] = [:]
        var recipes: [Recipe] = []
        var layouts: [Int] = []
        (0..<max(1, dayCount)).forEach { _ in
            var day: [Recipe] = []
            var todayKeys = Set<String>()
            var todayTitles: [String] = []
            types.forEach { meal in
                guard let picked = pick(
                    from: pools[meal] ?? [],
                    meal: meal,
                    target: slots[meal] ?? targets.scaled(by: calorieShare(for: meal)),
                    used: used,
                    todayKeys: todayKeys,
                    todayTitles: todayTitles
                ) else { return }
                todayKeys.insert(recipeKey(picked))
                todayTitles.append(picked.title)
                day.append(cloned(picked))
            }
            refineDay(
                day: &day,
                types: Array(types.prefix(day.count)),
                pools: pools,
                targets: targets,
                slots: slots,
                used: used
            )
            day.forEach { used[recipeKey($0), default: 0] += 1 }
            guard !day.isEmpty else { return }
            layouts.append(day.count)
            recipes.append(contentsOf: day)
        }
        return (recipes, layouts)
    }

    static func slotTargets(mealTypes: [MealType], targets: MealPlanTargets) -> [MealType: MealPlanTargets] {
        let types = orderedMealTypes(mealTypes)
        let weight = max(types.reduce(0) { $0 + calorieShare(for: $1) }, 0.01)
        var result: [MealType: MealPlanTargets] = [:]
        types.forEach { result[$0] = targets.scaled(by: calorieShare(for: $0) / weight) }
        return result
    }

    /// How far a day is from the goals, as one number: calories first, then protein, which is
    /// what a lean plan most often misses, then fats and carbs.
    static func dayScore(_ day: [Recipe], types: [MealType], targets: MealPlanTargets) -> Double {
        balanceGap(dayTotals(day, types: types), against: targets, knowsMacros: day.contains { $0.protein != nil })
    }

    /// What a day of dishes adds up to, per nutrient.
    static func dayTotals(_ day: [Recipe], types: [MealType]) -> MealPlanTargets {
        var totals = MealPlanTargets(calories: 0, protein: 0, carbs: 0, fats: 0)
        zip(day, types).forEach { recipe, meal in
            totals.calories += recipe.calories ?? estimatedCalories(for: meal)
            totals.protein += recipe.protein ?? 0
            totals.carbs += recipe.carbs ?? 0
            totals.fats += recipe.fats ?? 0
        }
        return totals
    }

    private static func balanceGap(_ actual: MealPlanTargets, against target: MealPlanTargets, knowsMacros: Bool) -> Double {
        var gap = abs(actual.calories - target.calories) / max(target.calories, 1)
        guard knowsMacros else { return gap }
        if target.protein > 0 {
            // Short on protein is the real problem; a little over it is not.
            gap += max(0, target.protein - actual.protein) / target.protein * 0.8
            gap += max(0, actual.protein - target.protein * 1.25) / target.protein * 0.2
        }
        if target.fats > 0 {
            gap += abs(actual.fats - target.fats) / target.fats * 0.35
        }
        if target.carbs > 0 {
            gap += abs(actual.carbs - target.carbs) / target.carbs * 0.25
        }
        return gap
    }

    static func estimatedCalories(for meal: MealType) -> Double {
        switch meal {
        case .breakfast: return 560
        case .lunch: return 520
        case .dinner: return 450
        case .snacks: return 180
        }
    }

    static func recipeKey(_ recipe: Recipe) -> String {
        if let id = recipe.externalId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            return "id:\(id)"
        }
        return "title:\(recipe.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private static func pick(
        from pool: [Recipe],
        meal: MealType,
        target: MealPlanTargets,
        used: [String: Int],
        todayKeys: Set<String>,
        todayTitles: [String]
    ) -> Recipe? {
        guard !pool.isEmpty else { return nil }
        let unusedToday = pool.filter { !todayKeys.contains(recipeKey($0)) }
        let free = unusedToday.isEmpty ? pool : unusedToday
        // A dish the plan has not served yet always wins: repeats start only once the pool for
        // this meal runs out, so a week does not open with the same breakfast every morning.
        let fresh = free.filter { used[recipeKey($0), default: 0] == 0 }
        let source = fresh.isEmpty ? free : fresh
        let estimated = estimatedCalories(for: meal)
        let ranked = source.enumerated().map { index, recipe -> (Int, Double) in
            var nutrients = MealPlanTargets(
                calories: recipe.calories ?? estimated,
                protein: recipe.protein ?? 0,
                carbs: recipe.carbs ?? 0,
                fats: recipe.fats ?? 0
            )
            if recipe.protein == nil { nutrients.protein = target.protein }
            let similar = todayTitles.contains { titleSimilarity($0, recipe.title) > 0.45 } ? 0.28 : 0
            let score = balanceGap(nutrients, against: target, knowsMacros: recipe.protein != nil)
                + Double(used[recipeKey(recipe), default: 0]) * 0.6
                + similar
            return (index, score)
        }
        guard let best = ranked.min(by: { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.0 < rhs.0
        }) else {
            return nil
        }
        return source[best.0]
    }

    /// Swaps single dishes while that brings the whole day closer to the goals.
    private static func refineDay(
        day: inout [Recipe],
        types: [MealType],
        pools: [MealType: [Recipe]],
        targets: MealPlanTargets,
        slots: [MealType: MealPlanTargets],
        used: [String: Int]
    ) {
        guard day.count == types.count, !day.isEmpty else { return }
        var currentScore = dayScore(day, types: types, targets: targets)
        for _ in 0..<6 {
            var best: (index: Int, recipe: Recipe, score: Double)?
            types.enumerated().forEach { index, meal in
                let slotCalories = slots[meal]?.calories ?? estimatedCalories(for: meal)
                let others = day.enumerated().filter { $0.offset != index }
                let otherKeys = Set(others.map { recipeKey($0.element) })
                let otherTitles = others.map(\.element.title)
                let pool = pools[meal] ?? []
                let fresh = pool.filter { used[recipeKey($0), default: 0] == 0 }
                let candidates = fresh.isEmpty ? pool : fresh
                candidates.forEach { candidate in
                    let key = recipeKey(candidate)
                    guard !otherKeys.contains(key), key != recipeKey(day[index]),
                          !otherTitles.contains(where: { titleSimilarity($0, candidate.title) > 0.45 }) else { return }
                    // A breakfast the size of a snack, or of two dinners, does not read as a meal.
                    let calories = candidate.calories ?? estimatedCalories(for: meal)
                    guard calories >= slotCalories * 0.45, calories <= slotCalories * 1.7 else { return }
                    var trial = day
                    trial[index] = candidate
                    let score = dayScore(trial, types: types, targets: targets)
                    guard score + 0.01 < (best?.score ?? currentScore) else { return }
                    best = (index, candidate, score)
                }
            }
            guard let best else { return }
            day[best.index] = cloned(best.recipe)
            currentScore = best.score
        }
    }

    private static func titleSimilarity(_ left: String, _ right: String) -> Double {
        let a = tokens(left)
        let b = tokens(right)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    private static func tokens(_ title: String) -> Set<String> {
        Set(
            title.lowercased()
                .split { !$0.isLetter }
                .map(String.init)
                .filter { $0.count > 3 }
        )
    }

    private static func cloned(_ recipe: Recipe) -> Recipe {
        var copy = recipe
        copy.id = UUID()
        return copy
    }
}
