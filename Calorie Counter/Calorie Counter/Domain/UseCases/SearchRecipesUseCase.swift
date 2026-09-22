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
        await page(query: query, filters: filters, offset: 0, maxCalories: maxCalories).recipes
    }

    func page(
        query: String,
        filters: RecipeSearchFilters,
        offset: Int,
        maxCalories: Int? = nil
    ) async -> RecipeSectionPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let parameters = filters.searchParameters
        guard !trimmed.isEmpty || !parameters.isEmpty else {
            return RecipeSectionPage(recipes: [], nextOffset: offset, hasMore: false)
        }
        let ceiling = maxCalories ?? calorieCeiling(from: filters)
        do {
            var page = try await aiFoodSearchService.searchRecipePage(query: trimmed, parameters: parameters, offset: offset)
            page.recipes = Self.matching(page.recipes, filters: filters, calorieCeiling: ceiling, requiringPhoto: true)
            return page
        } catch {
            return RecipeSectionPage(recipes: [], nextOffset: offset, hasMore: false, isRetryableFailure: true)
        }
    }

    /// Creates a recipe from the user's own products only. The server returns a catalog recipe that
    /// needs nothing else, or has the AI write one from the same list, always with a photo and full
    /// nutrition, and caches the answer.
    func generateRecipe(from input: RecipeGenerationInput) async -> Recipe? {
        let request = Self.creationRequest(from: input)
        guard !request.ingredients.isEmpty else { return nil }
        if let created = try? await aiFoodSearchService.createRecipe(request),
           created.hasPhoto, Self.hasCompleteDetails(created) {
            return created
        }
        // A server without the endpoint (or one that failed) still gets the catalog search.
        return await catalogRecipe(from: input)
    }

    static func creationRequest(from input: RecipeGenerationInput) -> RecipeCreationRequest {
        let details = input.details.trimmingCharacters(in: .whitespacesAndNewlines)
        return RecipeCreationRequest(
            ingredients: generationIngredients(input.ingredients),
            type: catalogList(input.mealTypes, RecipeSearchFilters.catalogMealType),
            cuisine: input.cuisine.flatMap(RecipeSearchFilters.catalogCuisine),
            diet: input.diet.flatMap(RecipeSearchFilters.catalogDiet),
            maxReadyTime: input.maxReadyMinutes,
            maxCalories: input.maxCalories,
            details: details.isEmpty ? nil : details,
            locale: Locale.deviceIdentifier
        )
    }

    /// Without the server endpoint, only a catalog recipe that needs none of the products the user
    /// lacks is acceptable; a title search would bring back dishes built on other shopping.
    private func catalogRecipe(from input: RecipeGenerationInput) async -> Recipe? {
        let ingredients = Self.generationIngredients(input.ingredients)
        let matches = ((try? await spoonacularService.pantryRecipeMatches(ingredients: ingredients, number: 30)) ?? [])
            .filter { $0.missedIngredientCount == 0 }
            .prefix(Self.catalogCandidateLimit)
        let type = Self.catalogList(input.mealTypes, RecipeSearchFilters.catalogMealType)
        // Load the candidates side by side, then keep the catalog's ranking when picking one.
        let service = spoonacularService
        let loaded = await withTaskGroup(of: (Int, Recipe?).self) { group in
            for (rank, match) in matches.enumerated() {
                group.addTask { (rank, try? await service.recipeDetails(id: match.id)) }
            }
            var byRank: [Int: Recipe] = [:]
            for await (rank, recipe) in group {
                if let recipe { byRank[rank] = recipe }
            }
            return byRank.sorted { $0.key < $1.key }.map(\.value)
        }
        return loaded.first { recipe in
            guard recipe.hasPhoto, !recipe.looksLikeListingPage, Self.hasCompleteDetails(recipe) else { return false }
            if let maxCalories = input.maxCalories, let calories = recipe.calories, calories > Double(maxCalories) {
                return false
            }
            if let maxMinutes = input.maxReadyMinutes, let minutes = recipe.readyInMinutes, minutes > maxMinutes {
                return false
            }
            guard let type else { return true }
            return type.split(separator: ",").contains { SuggestPantryRecipeUseCase.matches(recipe, type: String($0)) }
        }
    }

    private static let catalogCandidateLimit = 4

    static func generationIngredients(_ ingredients: [String]) -> [String] {
        var seen = Set<String>()
        return ingredients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private static func catalogList(_ values: [String], _ transform: (String) -> String?) -> String? {
        var result: [String] = []
        values.compactMap(transform).forEach { value in
            if !result.contains(value) { result.append(value) }
        }
        return result.isEmpty ? nil : result.joined(separator: ",")
    }

    /// A stand-in for one meal of a plan: the same kind of dish, close in calories, and never one
    /// the plan already holds. Searching by the dish's own name found nothing, so the arrow spun
    /// and left the plan as it was.
    func mealPlanReplacements(
        meal: MealType,
        calories: Double?,
        excluding keys: Set<String>,
        limit: Int = 5
    ) async -> [Recipe] {
        let target = calories ?? MealPlanPacker.estimatedCalories(for: meal)
        let search = SpoonacularRecipeSearch(
            query: "",
            number: 20,
            minCalories: max(80, Int((target * 0.7).rounded())),
            maxCalories: max(160, Int((target * 1.3).rounded())),
            type: CreateMealPlanUseCase.dishType(from: meal),
            sort: "popularity"
        )
        let results = (try? await spoonacularService.searchRecipes(search)) ?? []
        return Array(
            results
                .filter { candidate in
                    candidate.hasPhoto
                        && !candidate.looksLikeListingPage
                        && !keys.contains(MealPlanPacker.recipeKey(candidate))
                }
                .prefix(max(1, limit))
        )
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
    func recipes(containing product: String) async throws -> [Recipe] {
        let ingredient = Self.cookingIngredient(from: product)
        guard !ingredient.isEmpty else { return [] }
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

    /// What a packaged product is as an ingredient: "Чипси картопляні смак сиру" is cooked with as
    /// "чипси картопляні", "Greek yogurt, strawberry flavour (150 g)" as "greek yogurt". A flavour,
    /// pack size or brand note never appears in a recipe's ingredient list, so demanding it there
    /// meant no recipe could ever match.
    static func cookingIngredient(from product: String) -> String {
        var name = product.lowercased()
        name = name.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        let qualifiers = [
            ",", ";", " смак ", " зі смаком", " із смаком", " з смаком", " смаком ", " со вкусом", " вкус ",
            " with ", " flavour", " flavor", " taste", " style", " %"
        ]
        let padded = " " + name + " "
        let cut = qualifiers.compactMap { padded.range(of: $0)?.lowerBound }.min()
        if let cut {
            name = String(padded[padded.startIndex..<cut])
        }
        let words = name.split { !$0.isLetter && $0 != "-" }.map(String.init)
        return words.joined(separator: " ")
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
