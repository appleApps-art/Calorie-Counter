import Foundation

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
        let types = orderedMealTypes(mealTypes).filter { !(pools[$0] ?? []).isEmpty }
        guard !types.isEmpty else { return ([], []) }
        let targets = slotTargets(
            mealTypes: types,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal
        )
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
                    targetCalories: targets[meal]?.calories ?? estimatedCalories(for: meal),
                    targetProtein: targets[meal]?.protein ?? 0,
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
                calorieGoal: calorieGoal,
                targets: targets
            )
            day.forEach { used[recipeKey($0), default: 0] += 1 }
            guard !day.isEmpty else { return }
            layouts.append(day.count)
            recipes.append(contentsOf: day)
        }
        return (recipes, layouts)
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
        targetCalories: Double,
        targetProtein: Double,
        used: [String: Int],
        todayKeys: Set<String>,
        todayTitles: [String]
    ) -> Recipe? {
        guard !pool.isEmpty else { return nil }
        let unusedToday = pool.filter { !todayKeys.contains(recipeKey($0)) }
        let source = unusedToday.isEmpty ? pool : unusedToday
        let estimated = estimatedCalories(for: meal)
        let ranked = source.enumerated().map { index, recipe -> (Int, Double) in
            (index, score(
                recipe,
                targetCalories: targetCalories,
                targetProtein: targetProtein,
                estimatedCalories: estimated,
                timesUsed: used[recipeKey(recipe), default: 0],
                todayTitles: todayTitles
            ))
        }
        guard let best = ranked.min(by: { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.0 < rhs.0
        }) else {
            return nil
        }
        return source[best.0]
    }

    private static func score(
        _ recipe: Recipe,
        targetCalories: Double,
        targetProtein: Double,
        estimatedCalories: Double,
        timesUsed: Int,
        todayTitles: [String]
    ) -> Double {
        let calories = recipe.calories ?? estimatedCalories
        let calorieGap = abs(calories - targetCalories) / max(targetCalories, 1)
        let proteinGap: Double
        if let protein = recipe.protein, targetProtein > 0 {
            proteinGap = abs(protein - targetProtein) / max(targetProtein, 1)
        } else {
            proteinGap = 0
        }
        let similar = todayTitles.contains { titleSimilarity($0, recipe.title) > 0.45 } ? 0.28 : 0
        return calorieGap + proteinGap * 0.22 + Double(timesUsed) * 0.6 + similar
    }

    private static func refineDay(
        day: inout [Recipe],
        types: [MealType],
        pools: [MealType: [Recipe]],
        calorieGoal: Double,
        targets: [MealType: (calories: Double, protein: Double)]
    ) {
        guard day.count == types.count, !day.isEmpty else { return }
        let goal = max(calorieGoal, 1)
        func total() -> Double {
            zip(day, types).reduce(0) { sum, pair in
                sum + (pair.0.calories ?? estimatedCalories(for: pair.1))
            }
        }
        var current = total()
        guard current < goal * 0.90 || current > goal * 1.12 else { return }
        var improved = true
        var passes = 0
        while improved, passes < 5 {
            improved = false
            passes += 1
            current = total()
            let oldGap = abs(current - goal)
            var best: (index: Int, recipe: Recipe, gap: Double)?
            types.enumerated().forEach { index, meal in
                let slotTarget = targets[meal]?.calories ?? estimatedCalories(for: meal)
                let others = Set(
                    day.enumerated().compactMap { slot, recipe in
                        slot == index ? nil : recipeKey(recipe)
                    }
                )
                (pools[meal] ?? []).forEach { candidate in
                    let key = recipeKey(candidate)
                    if others.contains(key) { return }
                    if key == recipeKey(day[index]) { return }
                    let candidateCalories = candidate.calories ?? estimatedCalories(for: meal)
                    if candidateCalories < slotTarget * 0.45 || candidateCalories > slotTarget * 1.7 {
                        return
                    }
                    let newTotal = current
                        - (day[index].calories ?? estimatedCalories(for: meal))
                        + candidateCalories
                    let newGap = abs(newTotal - goal)
                    guard newGap + 12 < oldGap else { return }
                    if let best, newGap >= best.gap { return }
                    best = (index, candidate, newGap)
                }
            }
            if let best {
                day[best.index] = cloned(best.recipe)
                improved = true
            }
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
