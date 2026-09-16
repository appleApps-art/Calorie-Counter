import Foundation

final class SearchRecipesUseCase {
    private let spoonacularService: SpoonacularServiceProtocol
    private let aiFoodSearchService: AIFoodSearching

    init(
        spoonacularService: SpoonacularServiceProtocol,
        aiFoodSearchService: AIFoodSearching
    ) {
        self.spoonacularService = spoonacularService
        self.aiFoodSearchService = aiFoodSearchService
    }

    func execute(query: String, maxCalories: Int? = nil) async throws -> [Recipe] {
        try await execute(query: query, filters: .empty, maxCalories: maxCalories)
    }

    func execute(
        query: String,
        filters: RecipeSearchFilters,
        maxCalories: Int? = nil
    ) async throws -> [Recipe] {
        guard let combined = combinedQuery(query: query, filters: filters) else { return [] }
        let ceiling = maxCalories ?? calorieCeiling(from: filters)
        do {
            let recipes = try await aiFoodSearchService.searchRecipes(query: combined)
            return Self.matching(recipes, filters: filters, calorieCeiling: ceiling, requiringPhoto: true)
        } catch {
            return []
        }
    }

    func generateRecipes(
        query: String,
        filters: RecipeSearchFilters,
        number: Int = 10
    ) async throws -> [Recipe] {
        let count = max(1, number)
        let shortQuery = Self.shortGenerationQuery(query)
        let ceiling = calorieCeiling(from: filters)
        var recipes: [Recipe] = []
        if !shortQuery.isEmpty {
            do {
                recipes = try await aiFoodSearchService.searchRecipes(query: shortQuery)
            } catch {
                recipes = []
            }
            if recipes.count < count {
                let extra = (try? await spoonacularService.searchRecipes(
                    query: shortQuery,
                    maxCalories: ceiling,
                    number: count
                )) ?? []
                recipes = Self.mergingUnique(recipes, extra)
            }
        }
        if recipes.isEmpty, let meal = filters.mealTypes.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !meal.isEmpty {
            recipes = (try? await spoonacularService.searchRecipes(
                query: meal,
                maxCalories: ceiling,
                number: count
            )) ?? []
        }
        let matched = Self.matching(
            recipes,
            filters: filters,
            calorieCeiling: ceiling,
            requiringPhoto: false
        )
        return matched.isEmpty ? recipes : matched
    }

    /// Search filters and AI titles are only candidate sources. The detail payload is authoritative.
    func recipes(containing ingredient: String) async throws -> [Recipe] {
        guard !ingredient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let catalog = (try? await spoonacularService.searchRecipes(
            SpoonacularRecipeSearch(query: "", number: 5, includeIngredients: ingredient)
        )) ?? []
        let verifiedCatalog = await verifiedRecipes(catalog, containing: ingredient)
        if !verifiedCatalog.isEmpty { return verifiedCatalog }
        try Task.checkCancellation()
        let alternatives = try await aiFoodSearchService.searchRecipes(
            query: L10n.format("product.insight.recipeQuery", ingredient)
        )
        return await verifiedRecipes(alternatives, containing: ingredient)
    }

    private func verifiedRecipes(_ candidates: [Recipe], containing ingredient: String) async -> [Recipe] {
        var matches: [Recipe] = []
        for candidate in candidates.prefix(5) {
            guard !Task.isCancelled else { return [] }
            // Numeric catalog IDs always resolve through recipeDetails, even if the search preview
            // already contains an ingredient list. Never fall back to an unverified preview on error.
            guard let fullRecipe = try? await details(for: candidate),
                  Self.containsIngredient(ingredient, in: fullRecipe) else { continue }
            matches.append(fullRecipe)
        }
        return matches
    }

    static func containsIngredient(_ ingredient: String, in recipe: Recipe) -> Bool {
        func words(_ value: String) -> [String] {
            value.lowercased().split { !$0.isLetter }.map(String.init)
        }
        let requested = words(ingredient)
        guard !requested.isEmpty else { return false }
        func sameWord(_ requested: String, _ actual: String) -> Bool {
            if requested == actual { return true }
            let eggForms: Set<String> = ["яйце", "яйця", "яєць", "яйцем"]
            if eggForms.contains(requested), eggForms.contains(actual) { return true }
            // Recognize simple inflections, without substring matching (egg != eggplant).
            if requested == "egg", actual == "eggs" { return true }
            let adjectiveEndings = ["ий", "ого", "ому", "им", "ій"]
            func adjectiveStem(_ word: String) -> String? {
                guard let ending = adjectiveEndings.first(where: { word.hasSuffix($0) }),
                      word.count - ending.count >= 4 else { return nil }
                return String(word.dropLast(ending.count))
            }
            if let stem = adjectiveStem(requested), stem == adjectiveStem(actual) { return true }
            let endings = ["s", "es", "а", "у", "ом", "і", "ів", "ою"]
            return endings.contains { ending in
                (requested.count >= 4 && actual == requested + ending)
                    || (actual.count >= 4 && requested == actual + ending)
            }
        }
        return recipe.ingredients.contains { item in
            let tokens = words(item.name + " " + (item.originalText ?? ""))
            // Require all qualifiers within one ingredient; a title/summary/step is not evidence.
            let included = tokens.prefix { $0 != "без" && $0 != "without" }
            return requested.allSatisfy { word in included.contains { sameWord(word, $0) } }
        }
    }

    func details(externalId: String) async throws -> Recipe {
        let recipe = try await spoonacularService.recipeDetails(id: externalId)
        guard recipe.externalId == externalId, Self.hasCompleteDetails(recipe) else {
            throw PreparedDishDetailsError.unavailable
        }
        return recipe
    }

    func details(for recipe: Recipe) async throws -> Recipe {
        if recipe.catalogFoodID != nil {
            return try await resolvePreparedDish(recipe)
        }
        if Self.hasCatalogRecipeIdentity(recipe), let id = recipe.externalId {
            var details = try await self.details(externalId: id)
            // A translated preview label belongs to this same verified catalog recipe.
            // A semantically matched replacement below keeps its own title instead.
            if FoodProduct.prefersLocalizedDisplayName(recipe.title, over: details.title) {
                details.title = recipe.title
            }
            details.id = recipe.id
            return details
        }
        if Self.hasCompleteDetails(recipe) { return recipe }
        return try await generateCompleteRecipe(named: recipe.title)
    }

    static func hasCatalogRecipeIdentity(_ recipe: Recipe) -> Bool {
        guard recipe.catalogFoodID == nil,
              recipe.origin == .spoonacular,
              let id = recipe.externalId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty else { return false }
        return id.allSatisfy(\.isNumber)
    }

    private func resolvePreparedDish(_ original: Recipe) async throws -> Recipe {
        let candidates = (try? await spoonacularService.searchRecipes(
            query: original.title, maxCalories: nil, number: 5
        )) ?? []
        var completeCandidates: [Recipe] = []
        var seenIDs = Set<String>()
        for candidate in candidates.prefix(5) {
            try Task.checkCancellation()
            // A result is only a candidate. Hydrate the actual recipe before comparing its
            // composition, and never generate an AI replacement inside a catalog candidate.
            guard Self.hasCatalogRecipeIdentity(candidate), let id = candidate.externalId,
                  seenIDs.insert(id).inserted,
                  let full = try? await details(externalId: id) else { continue }
            completeCandidates.append(full)
        }
        try Task.checkCancellation()
        if !completeCandidates.isEmpty,
           let matched = try? await aiFoodSearchService.matchingRecipe(
               title: original.title, candidates: completeCandidates
           ),
           let verified = completeCandidates.first(where: { $0.externalId == matched.externalId }) {
            return verified
        }
        try Task.checkCancellation()
        // A generic nutrition record has no recipe. A generated alternative has its own
        // identity and source; no catalog nutrition, photo or portion is copied onto it.
        return try await generateCompleteRecipe(named: original.title)
    }

    private func generateCompleteRecipe(named title: String) async throws -> Recipe {
        guard var product = try await aiFoodSearchService.enrichDetails(
            title: title, imageURL: nil, source: FoodProductSource.openAI.rawValue, kind: "recipe"
        ), product.foodType != .product,
           [product.calories, product.protein, product.carbs, product.fats].allSatisfy({ $0 != nil }) else {
            throw PreparedDishDetailsError.unavailable
        }
        product.kind = .recipe
        product.foodType = .dish
        product.source = .openAI
        product.id = UUID()
        product.externalId = AIFoodSearchService.idPrefix + "recipe-" + UUID().uuidString
        var draft = ProductDetailsMath.draft(from: product, imageData: nil, mealType: .lunch, date: Date())
        draft.servings = 1
        let generated = draft.toFoodEntry().asRecipe()
        guard Self.hasCompleteDetails(generated) else { throw PreparedDishDetailsError.unavailable }
        return generated
    }

    static func hasCompleteDetails(_ recipe: Recipe) -> Bool {
        guard recipe.hasCompleteNutrition != false,
              !recipe.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let calories = recipe.calories, calories.isFinite, calories > 0,
              [recipe.protein, recipe.carbs, recipe.fats].allSatisfy({ value in
                  guard let value else { return false }; return value.isFinite && value >= 0
              }) else { return false }
        return recipe.ingredients.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && recipe.steps.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func combinedQuery(query: String, filters: RecipeSearchFilters) -> String? {
        var parts: [String] = []
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { parts.append(trimmed) }
        let filterQuery = filters.searchQuery
        if !filterQuery.isEmpty { parts.append(filterQuery) }
        let combined = parts.joined(separator: " ")
        return combined.isEmpty ? nil : combined
    }

    private func calorieCeiling(from filters: RecipeSearchFilters) -> Int? {
        filters.maxCalories < RecipeSearchFilters.calorieCeiling ? filters.maxCalories : nil
    }

    private static func shortGenerationQuery(_ query: String) -> String {
        let parts = query
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.isEmpty {
            return query.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return Array(parts.prefix(6)).joined(separator: ", ")
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

    private static func matching(
        _ recipes: [Recipe],
        filters: RecipeSearchFilters,
        calorieCeiling: Int?,
        requiringPhoto: Bool
    ) -> [Recipe] {
        recipes.filter { recipe in
            if requiringPhoto, !recipe.isSearchableRecipe { return false }
            guard filters.matches(recipe) else { return false }
            guard let calorieCeiling, let calories = recipe.calories else { return true }
            return calories <= Double(calorieCeiling)
        }
    }

}

enum PreparedDishDetailsError: Error { case unavailable }
