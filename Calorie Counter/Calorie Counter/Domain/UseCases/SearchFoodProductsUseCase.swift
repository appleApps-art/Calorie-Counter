import Foundation

final class SearchFoodProductsUseCase {
    private let spoonacularService: SpoonacularServiceProtocol
    private let aiFoodSearchService: AIFoodSearching
    private let openFoodFactsService: OpenFoodFactsSearching
    private let textFoodAnalysisService: TextFoodAnalysisServiceProtocol
    private var browsedProducts: [FoodProduct] = []
    private var foodTypes: [String: FoodType] = [:]
    private var catalogTask: Task<[String: [FoodProduct]], Never>?

    init(
        spoonacularService: SpoonacularServiceProtocol,
        aiFoodSearchService: AIFoodSearching,
        openFoodFactsService: OpenFoodFactsSearching,
        textFoodAnalysisService: TextFoodAnalysisServiceProtocol
    ) {
        self.spoonacularService = spoonacularService
        self.aiFoodSearchService = aiFoodSearchService
        self.openFoodFactsService = openFoodFactsService
        self.textFoodAnalysisService = textFoodAnalysisService
    }

    /// Resolves semantic type without changing the provider namespace or food data.
    func classifyFoods(_ products: [FoodProduct]) async throws -> [FoodProduct] {
        func key(_ product: FoodProduct) -> String {
            "\(product.source.rawValue):\(product.kind.rawValue):\(product.externalId):\(product.name)"
        }
        var result = products.map { product in
            var next = product
            next.foodType = product.resolvedFoodType ?? foodTypes[key(product)]
            return next
        }
        let unknown = result.indices.filter { result[$0].foodType == nil }
        for start in stride(from: 0, to: unknown.count, by: 20) {
            try Task.checkCancellation()
            let indices = Array(unknown[start..<min(start + 20, unknown.count)])
            let classified = try await aiFoodSearchService.classifyFoods(indices.map { result[$0] })
            guard classified.count == indices.count else { throw FoodPhotoAnalysisError.invalidResponse }
            for (index, item) in zip(indices, classified) {
                guard let type = item.resolvedFoodType, item.id == result[index].id else {
                    throw FoodPhotoAnalysisError.invalidResponse
                }
                result[index].foodType = type
                foodTypes[key(result[index])] = type
            }
        }
        return result
    }

    func classifiedDraft(_ draft: ProductDetailsDraft) async throws -> ProductDetailsDraft {
        guard draft.resolvedFoodType == nil else { return draft }
        let product = FoodProduct(
            id: UUID(), externalId: draft.catalogExternalId ?? "", name: draft.name, brand: nil,
            kind: draft.catalogKind ?? .ingredient, imageURL: draft.imageURL,
            calories: draft.calories, protein: draft.protein, carbs: draft.carbs, fats: draft.fats,
            amount: draft.portionGrams ?? draft.portionMilliliters,
            unit: draft.portionMilliliters == nil ? "g" : "ml",
            source: FoodProductSource(apiValue: draft.source),
            ingredients: draft.ingredients.map(ProductDetailsMath.formatIngredient), steps: draft.recipeSteps,
            hasCompleteNutrition: draft.hasCompleteNutrition
        )
        let classified = try await classifyFoods([product])
        var next = draft
        next.foodType = classified.first?.foodType
        // A legacy catalog food ID is not a recipe ID, even after semantic classification.
        if next.catalogKind == nil { next.catalogKind = .ingredient }
        return next
    }

    func matchingBrowsedProducts(query: String) -> [FoodProduct] {
        Self.ranked(browsedProducts.filter { Self.nameRank($0.name, query: query) < 4 }, query: query)
    }

    private func remember(_ products: [FoodProduct]) {
        browsedProducts = Self.mergeCatalog(primary: products, extras: browsedProducts)
    }

    private func searchBrowseCatalog(query: String) async -> [FoodProduct] {
        let catalog = await loadDefaultCatalog()
        remember(catalog.keys.sorted().flatMap { catalog[$0] ?? [] })
        return matchingBrowsedProducts(query: query)
    }

    static func normalizedName(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "uk_UA"))
            .split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    static func nameRank(_ name: String, query: String) -> Int {
        let name = normalizedName(name)
        let query = normalizedName(query)
        guard !query.isEmpty else { return 4 }
        if name == query { return 0 }
        if name.hasPrefix(query) { return 1 }
        if (" " + name + " ").contains(" " + query + " ") { return 2 }
        if name.contains(query) { return 3 }
        return 4
    }

    static func ranked(_ products: [FoodProduct], query: String) -> [FoodProduct] {
        products.enumerated().sorted {
            let left = nameRank($0.element.name, query: query)
            let right = nameRank($1.element.name, query: query)
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
    }

    func executeDefaultCatalog() async -> [String: [FoodProduct]] {
        await loadDefaultCatalog()
    }

    func executeCatalog(query: String, number: Int = 20, includeRecipes: Bool = false) async throws -> [FoodProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let limit = min(max(number, 1), 20)
        async let browsed = searchBrowseCatalog(query: trimmed)
        async let products = spoonacularService.searchProducts(query: trimmed, number: limit)
        async let ingredients = spoonacularService.searchIngredients(query: trimmed, number: limit)
        async let recipes = recipeCatalog(query: trimmed, number: limit, enabled: includeRecipes)
        let groceries = await Self.mergeCatalog(
            primary: (try? products) ?? [],
            extras: (try? ingredients) ?? []
        )
        let remote = await Self.mergeCatalog(primary: recipes, extras: groceries)
        let local = await browsed
        let classified = try await classifyFoods(Self.mergeCatalog(primary: remote, extras: local))
        return Self.ranked(classified.filter { includeRecipes || $0.resolvedFoodType == .product }, query: trimmed)
    }

    private func recipeCatalog(query: String, number: Int, enabled: Bool) async -> [FoodProduct] {
        guard enabled else { return [] }
        let recipes = (try? await spoonacularService.searchRecipes(query: query, maxCalories: nil, number: number)) ?? []
        return recipes.map(FoodProduct.init(recipe:))
    }

    func executeCategoryCatalog(
        tag: String,
        query: String,
        number: Int = 20,
        sectionID: String? = nil
    ) async throws -> [FoodProduct] {
        var catalog: [String: [FoodProduct]] = [:]
        if let sectionID {
            let id = sectionID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !id.isEmpty {
                let expanded = try await classifyFoods(aiFoodSearchService.fetchCatalogSection(id: id))
                if !expanded.isEmpty {
                    remember(expanded)
                    return Array(expanded.prefix(number))
                }
            }
        }
        catalog = await loadDefaultCatalog()
        remember(catalog.keys.sorted().flatMap { catalog[$0] ?? [] })
        if let sectionID {
            let id = sectionID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !id.isEmpty, let items = catalog[id], !items.isEmpty {
                return Array(items.prefix(number))
            }
        }
        let tagged = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tagged.isEmpty, let items = catalog[tagged], !items.isEmpty {
            return Array(items.prefix(number))
        }
        return []
    }

    func executeCategoryCatalogPage(
        sectionID: String,
        offset: Int,
        limit: Int = 20
    ) async -> FoodSearchCatalogPage {
        let id = sectionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            return FoodSearchCatalogPage(products: [], nextOffset: offset, hasMore: false)
        }
        var page = (try? await aiFoodSearchService.fetchCatalogSectionPage(
            id: id,
            offset: offset,
            limit: limit
        )) ?? FoodSearchCatalogPage(products: [], nextOffset: offset, hasMore: true, isRetryableFailure: true)
        do {
            let products = try await classifyFoods(page.products)
            page = FoodSearchCatalogPage(products: products, nextOffset: page.nextOffset,
                                         hasMore: page.hasMore, isRetryableFailure: page.isRetryableFailure)
        } catch {
            return FoodSearchCatalogPage(products: [], nextOffset: offset, hasMore: true, isRetryableFailure: true)
        }
        remember(page.products)
        return page
    }

    private func loadDefaultCatalog() async -> [String: [FoodProduct]] {
        if let catalogTask {
            return await catalogTask.value
        }
        let task = Task { [self] in
            do {
                let catalog = try await aiFoodSearchService.fetchDefaultCatalog()
                let keys = catalog.keys.sorted()
                let products = try await classifyFoods(keys.flatMap { catalog[$0] ?? [] })
                var classified: [String: [FoodProduct]] = [:]
                var offset = 0
                for key in keys {
                    let count = catalog[key]?.count ?? 0
                    classified[key] = Array(products[offset..<offset + count])
                    offset += count
                }
                return classified
            } catch { return [:] }
        }
        catalogTask = task
        let value = await task.value
        if value.isEmpty {
            catalogTask = nil
        }
        return value
    }

    func execute(query: String, includeRecipes: Bool = true) async throws -> [FoodProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        async let browsed = searchBrowseCatalog(query: trimmed)
        var products = await raceSearch(trimmed)
        products = await Self.mergeCatalog(primary: products, extras: browsed)
        let openFoodFacts = (try? await openFoodFactsService.searchProducts(query: trimmed, number: 20)) ?? []
        if !openFoodFacts.isEmpty {
            products = Self.mergeCatalog(primary: products, extras: openFoodFacts)
        }
        if products.isEmpty {
            products = await analyzeAsFood(trimmed)
        }
        products = Self.ranked(try await classifyFoods(products), query: trimmed)
        if includeRecipes { return products }
        return products.filter { $0.resolvedFoodType == .product }
    }

    private func raceSearch(_ query: String) async -> [FoodProduct] {
        (try? await aiFoodSearchService.searchFoods(query: query)) ?? []
    }

    static func mergeCatalog(primary: [FoodProduct], extras: [FoodProduct]) -> [FoodProduct] {
        var seen = Set<String>()
        var merged: [FoodProduct] = []
        func token(_ product: FoodProduct) -> String {
            let id = product.externalId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !id.isEmpty {
                return "id:\(product.source.rawValue):\(product.kind.rawValue):\(id)"
            }
            return "name:\(product.source.rawValue):\(product.kind.rawValue):\(product.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        }
        for product in primary {
            if seen.insert(token(product)).inserted {
                merged.append(product)
            }
        }
        let uniqueExtras = extras.filter { seen.insert(token($0)).inserted }
        guard !uniqueExtras.isEmpty else { return merged }
        let aiCount = merged.prefix {
            $0.source.isAIRecipe || $0.externalId.hasPrefix(AIFoodSearchService.idPrefix)
        }.count
        merged.insert(contentsOf: uniqueExtras, at: min(aiCount, merged.count))
        return merged
    }

    private func analyzeAsFood(_ query: String) async -> [FoodProduct] {
        guard let analysis = try? await textFoodAnalysisService.analyze(
            text: query,
            mealType: .snacks,
            userContext: nil
        ) else {
            return []
        }
        let name = analysis.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return [] }
        let milliliters = analysis.portionMilliliters
        return [
            FoodProduct(
                id: UUID(),
                externalId: "\(AIFoodSearchService.idPrefix)\(UUID().uuidString)",
                name: name,
                brand: nil,
                kind: .ingredient,
                imageURL: nil,
                calories: analysis.calories,
                protein: analysis.protein,
                carbs: analysis.carbs,
                fats: analysis.fats,
                amount: milliliters ?? analysis.portionGrams,
                unit: milliliters == nil ? "g" : "ml",
                source: .textAnalysis,
                ingredients: analysis.ingredients.map(ProductDetailsMath.formatIngredient),
                foodType: analysis.foodType
            )
        ]
    }

    func ingredientDetails(id: String) async throws -> FoodProduct {
        try await spoonacularService.ingredientDetails(id: id, amount: 100, unit: "grams")
    }

    func productDetails(id: String) async throws -> FoodProduct {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if BarcodeNormalization.normalize(trimmed) != nil,
           let barcode = try? await openFoodFactsService.lookup(barcode: trimmed) {
            return barcode.toFoodProduct()
        }
        return try await spoonacularService.productDetails(id: trimmed)
    }

    func recipeDetails(id: String) async throws -> FoodProduct {
        FoodProduct(recipe: try await spoonacularService.recipeDetails(id: id))
    }

    func attachProductPhotos(to items: [PantryItem]) async -> [PantryItem] {
        var namesByKey: [String: String] = [:]
        for item in items {
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if namesByKey[key] == nil {
                namesByKey[key] = trimmed
            }
        }
        var matches: [String: FoodProduct] = [:]
        await withTaskGroup(of: (String, FoodProduct?).self) { group in
            for (key, name) in namesByKey {
                group.addTask {
                    (key, await self.catalogGroceryMatch(for: name))
                }
            }
            for await (key, match) in group {
                if let match {
                    matches[key] = match
                }
            }
        }
        return items.map { item in
            let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let match = matches[key] else { return item }
            var next = item
            if let url = displayablePhoto(match) {
                next.imageURL = url
                next.imageData = nil
            }
            if FoodProduct.prefersLocalizedDisplayName(match.name, over: item.name) {
                next.name = match.name
            }
            return next
        }
    }

    func productPhotoURL(for name: String) async -> URL? {
        displayablePhoto(await catalogGroceryMatch(for: name))
    }

    private func catalogGroceryMatch(for name: String) async -> FoodProduct? {
        for query in Self.searchQueries(for: name) {
            async let ingredients = spoonacularService.searchIngredients(query: query, number: 10)
            async let products = spoonacularService.searchProducts(query: query, number: 10)
            let grocery = ((try? await ingredients) ?? []) + ((try? await products) ?? [])
            if let match = Self.bestGroceryMatch(query: name, in: grocery) {
                return match
            }
        }
        return nil
    }

    private static func searchQueries(for name: String) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var queries = [trimmed]
        let tokens = trimmed.split { $0.isWhitespace || $0.isPunctuation }.map(String.init)
        if let last = tokens.last, last.count >= 3, last.caseInsensitiveCompare(trimmed) != .orderedSame {
            queries.append(last)
        }
        return queries
    }

    private static func bestGroceryMatch(query: String, in products: [FoodProduct]) -> FoodProduct? {
        let grocery = products.filter { $0.kind != .recipe }
        guard !grocery.isEmpty else { return nil }
        var best: (FoodProduct, Int)?
        for product in grocery {
            let score = groceryMatchScore(query: query, productName: product.name, hasPhoto: product.hasPhoto)
            guard score >= 20 else { continue }
            if let current = best, current.1 >= score { continue }
            best = (product, score)
        }
        if let best {
            return best.0
        }
        return grocery.first(where: \.hasPhoto) ?? grocery.first
    }

    private static func groceryMatchScore(query: String, productName: String, hasPhoto: Bool) -> Int {
        if PantryItem.namesMatch(query, productName) {
            return 100 + (hasPhoto ? 10 : 0)
        }
        let queryKey = PantryItem.matchKey(query)
        let productKey = PantryItem.matchKey(productName)
        guard !queryKey.isEmpty, !productKey.isEmpty else { return 0 }
        var score = 0
        if productKey.contains(queryKey) || queryKey.contains(productKey) {
            score = 50
        } else {
            let queryTokens = Set(queryKey.split(separator: " ").map(String.init).filter { $0.count >= 3 })
            let productTokens = Set(productKey.split(separator: " ").map(String.init).filter { $0.count >= 3 })
            if !queryTokens.isEmpty, !queryTokens.isDisjoint(with: productTokens) {
                score = 30
            }
        }
        guard score > 0 else { return 0 }
        return score + (hasPhoto ? 10 : 0)
    }

    private func displayablePhoto(_ product: FoodProduct?) -> URL? {
        guard let product, product.kind != .recipe, product.hasPhoto, let url = product.imageURL else {
            return nil
        }
        let upgraded = url.absoluteString.replacingOccurrences(
            of: "/ingredients_100x100/",
            with: "/ingredients_250x250/"
        )
        return URL(string: upgraded) ?? url
    }

    func enrichDetails(
        title: String,
        imageURL: URL?,
        source: String,
        kind: String
    ) async throws -> FoodProduct? {
        try await aiFoodSearchService.enrichDetails(
            title: title,
            imageURL: imageURL,
            source: source,
            kind: kind
        )
    }
}
