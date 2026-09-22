import Foundation

struct FoodSearchItem: Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let imageURL: URL?
    let imageData: Data?
    let product: FoodProduct

    static func detailLine(for product: FoodProduct) -> String {
        var parts: [String] = []
        if !AppUnits.current.usesMetric, let amount = product.amount,
           let unit = product.unit?.lowercased(), ["g", "gram", "grams", "ml", "milliliter", "milliliters"].contains(unit) {
            parts.append(unit.hasPrefix("m") ? AppUnits.current.volumeText(amount) : AppUnits.current.massText(amount))
        } else if let serving = product.servingSizeLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !serving.isEmpty {
            parts.append(serving)
        } else if let amount = product.amount, let unit = product.unit, !unit.isEmpty {
            let amountText = amount.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(amount.rounded()))
                : String(amount)
            let displayUnit: String
            switch unit.lowercased() {
            case "g", "gram", "grams": displayUnit = L10n.tr("search.unit.grams")
            case "ml", "milliliter", "milliliters": displayUnit = L10n.tr("search.unit.milliliters")
            default: displayUnit = unit
            }
            parts.append("\(amountText) \(displayUnit)")
        }
        if let calories = product.calories {
            parts.append(L10n.format("recipes.kcal", Int(calories.rounded())))
        }
        return parts.joined(separator: " · ")
    }
}

final class FoodSearchViewModel {
    let queryText = Observable("")
    let suggestedItems = Observable<[FoodSearchItem]>([])
    let resultItems = Observable<[FoodSearchItem]>([])
    let resultsTitleText = Observable("")
    let showsEmptyResults = Observable(false)
    let browseSections = Observable<[FoodSearchBrowseSection]>([])
    let phase = Observable(FoodSearchPhase.browse)
    let isSearching = Observable(false)
    let isLoadingBrowse = Observable(true)
    let isRecording = Observable(false)
    let canConfirmQuery = Observable(false)
    let scope: Observable<FoodSearchScope>

    var showsScopeControl: Bool { includeRecipes }
    var titleText: String { L10n.tr(includeRecipes ? "search.addFood" : "search.title") }
    var placeholderText: String { L10n.tr(includeRecipes ? "search.unifiedPlaceholder" : "search.placeholder") }
    var visibleCatalogCategories: [FoodSearchCategory] {
        switch scope.value {
        case .all: return [.preparedMeals, .products]
        case .products: return FoodSearchCategory.productCategories
        case .meals: return FoodSearchCategory.mealCategories
        }
    }

    var onBack: (() -> Void)?
    var onOpenDetails: ((ProductDetailsDraft) -> Void)?
    var onOpenCategory: ((FoodSearchCategory) -> Void)?
    var onAskBity: ((String) -> Void)?

    private let mealType: MealType
    private let date: Date
    private let searchFoodProductsUseCase: SearchFoodProductsUseCase
    private let fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase
    private let fetchSavedFoodsUseCase: FetchSavedFoodsUseCase
    private let includeRecipes: Bool
    private var searchTask: Task<Void, Never>?
    private var productsByID: [UUID: FoodProduct] = [:]
    private var savedEntriesByID: [UUID: FoodEntry] = [:]
    private var savedItems: [FoodSearchItem] = []
    private var savedClassificationTask: Task<Void, Never>?
    private var catalogProducts: [FoodSearchCategory: [FoodProduct]] = [:]
    private var loadingCategories = Set<FoodSearchCategory>()
    private var failedCategories = Set<FoodSearchCategory>()
    private var loadedProductCategories = false
    private var latestSearchProducts: [FoodProduct] = []
    private let dictation: VoiceConfirmDictation

    init(
        mealType: MealType,
        date: Date,
        searchFoodProductsUseCase: SearchFoodProductsUseCase,
        fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase,
        fetchSavedFoodsUseCase: FetchSavedFoodsUseCase,
        voiceRecorder: VoiceFoodAudioRecording,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase,
        includeRecipes: Bool = true
    ) {
        self.mealType = mealType
        self.date = date
        self.searchFoodProductsUseCase = searchFoodProductsUseCase
        self.fetchRecipeBrowseSectionsUseCase = fetchRecipeBrowseSectionsUseCase
        self.fetchSavedFoodsUseCase = fetchSavedFoodsUseCase
        self.includeRecipes = includeRecipes
        scope = Observable(includeRecipes ? .all : .products)
        dictation = VoiceConfirmDictation(
            recorder: voiceRecorder,
            transcribeFoodVoiceUseCase: transcribeFoodVoiceUseCase
        )
        dictation.onText = { [weak self] text in
            self?.updateQuery(text)
        }
        dictation.isRecording.bind { [weak self] value in
            self?.isRecording.value = value
        }
        dictation.canConfirm.bind { [weak self] value in
            self?.canConfirmQuery.value = value
        }
    }

    func viewDidLoad() {
        loadSavedFoods()
        loadBrowseSections()
        if queryText.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            publishBrowse()
        }
    }

    func updateQuery(_ text: String) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines)
            != queryText.value.trimmingCharacters(in: .whitespacesAndNewlines) {
            cancelSearch()
        }
        queryText.value = text
        dictation.clearConfirmIfEmpty(text)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            publishBrowse()
            return
        }
    }

    func searchTapped() {
        dictation.cancel()
        dictation.consumeConfirm()
        cancelSearch()
        performSearch()
    }

    func seeMoreTapped(_ category: FoodSearchCategory) {
        guard category != .recent else { return }
        onOpenCategory?(category)
    }

    func selectScope(_ next: FoodSearchScope) {
        guard includeRecipes, scope.value != next else { return }
        scope.value = next
        if phase.value == .results {
            publish(latestSearchProducts, track: false)
        } else {
            loadBrowseSections()
        }
    }

    func refreshRecentFoods() {
        loadSavedFoods()
        if phase.value == .browse { renderBrowseSections() }
    }

    func retryBrowse(_ category: FoodSearchCategory) {
        catalogProducts[category] = nil
        failedCategories.remove(category)
        if FoodSearchCategory.productCategories.contains(category) {
            loadedProductCategories = false
        }
        loadBrowseSections()
    }

    /// Back online, every category that failed for lack of a connection loads again.
    func retryFailedBrowse() {
        guard !failedCategories.isEmpty else { return }
        for category in failedCategories {
            catalogProducts[category] = nil
            if FoodSearchCategory.productCategories.contains(category) {
                loadedProductCategories = false
            }
        }
        failedCategories.removeAll()
        loadBrowseSections()
    }

    func clearQuery() {
        dictation.cancel()
        dictation.consumeConfirm()
        cancelSearch()
        queryText.value = ""
        loadSavedFoods()
        publishBrowse()
    }

    func backTapped() {
        dictation.cancel()
        cancelSearch()
        onBack?()
    }

    func askBityTapped() {
        let query = queryText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        Analytics.tracker.track(.foodItemOpened(source: "ask_bity", foodType: nil))
        onAskBity?(query)
    }

    func selectItem(id: UUID) {
        if let entry = savedEntriesByID[id] {
            Analytics.tracker.track(.foodItemOpened(source: "recent", foodType: entry.resolvedFoodType?.rawValue))
            var draft = ProductDetailsMath.draft(from: entry)
            draft.mealType = mealType
            draft.date = date
            draft.foodType = entry.resolvedFoodType
            onOpenDetails?(draft)
            return
        }
        guard let product = productsByID[id] else { return }
        Analytics.tracker.track(.foodItemOpened(
            source: phase.value == .results ? "search_results" : "catalog",
            foodType: product.resolvedFoodType?.rawValue
        ))
        onOpenDetails?(
            ProductDetailsMath.draft(
                from: product,
                imageData: nil,
                mealType: mealType,
                date: date
            )
        )
    }

    func trailingActionTapped() {
        if canConfirmQuery.value {
            dictation.consumeConfirm()
            searchTapped()
            return
        }
        if isRecording.value {
            dictation.finish()
        } else {
            dictation.start()
        }
    }

    func toggleVoiceTapped() {
        trailingActionTapped()
    }

    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        isSearching.value = false
    }

    private func performSearch() {
        let query = queryText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            publishBrowse()
            return
        }
        latestSearchProducts = []
        phase.value = .results
        isSearching.value = true
        showsEmptyResults.value = false
        resultsTitleText.value = L10n.tr("search.results")
        suggestedItems.value = []
        resultItems.value = []
        let known = searchFoodProductsUseCase.matchingBrowsedProducts(query: query)
            .filter { includeRecipes || $0.resolvedFoodType == .product }
        if !known.isEmpty { publish(Self.keepingDisplayablePhotos(known), track: false) }
        searchTask = Task { @MainActor in
            async let catalog = (try? await searchFoodProductsUseCase.executeCatalog(query: query, includeRecipes: includeRecipes)) ?? []
            async let unified = (try? await searchFoodProductsUseCase.execute(
                query: query,
                includeRecipes: includeRecipes
            )) ?? []
            let catalogProducts = await catalog
            guard !Task.isCancelled else { return }
            if !catalogProducts.isEmpty {
                publish(Self.keepingDisplayablePhotos(catalogProducts), track: false)
            }
            let unifiedProducts = await unified
            guard !Task.isCancelled else { return }
            isSearching.value = false
            let products = Self.keepingDisplayablePhotos(
                SearchFoodProductsUseCase.mergeCatalog(
                    primary: unifiedProducts,
                    extras: catalogProducts
                )
            )
            publish(products)
            let enriched = await enrich(products)
            guard !Task.isCancelled else { return }
            if enriched != products {
                publish(Self.keepingDisplayablePhotos(enriched), track: false)
            }
        }
    }

    private func enrich(_ products: [FoodProduct]) async -> [FoodProduct] {
        await withTaskGroup(of: FoodProduct.self) { group in
            for product in products.prefix(8) {
                group.addTask {
                    guard product.calories == nil else { return product }
                    let details: FoodProduct?
                    if product.kind == .ingredient {
                        details = try? await self.searchFoodProductsUseCase.ingredientDetails(id: product.externalId)
                    } else if product.kind == .recipe {
                        if product.source.isAIRecipe
                            || product.externalId.hasPrefix(AIFoodSearchService.idPrefix)
                            || product.externalId.contains(where: { !$0.isNumber }) {
                            return product
                        }
                        details = try? await self.searchFoodProductsUseCase.recipeDetails(id: product.externalId)
                    } else if product.kind == .product {
                        details = try? await self.searchFoodProductsUseCase.productDetails(id: product.externalId)
                    } else {
                        details = nil
                    }
                    guard let details else { return product }
                    return product.mergingNutrition(from: details)
                }
            }
            var mapped: [String: FoodProduct] = [:]
            for await product in group {
                mapped[Self.identity(product)] = product
            }
            return products.map { mapped[Self.identity($0)] ?? $0 }
        }
    }

    private func loadSavedFoods() {
        let entries = (try? fetchSavedFoodsUseCase.executeRecent()) ?? []
        let items = entries.map(makeItem)
        savedItems = items
        savedEntriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        savedClassificationTask?.cancel()
        guard items.contains(where: { $0.product.resolvedFoodType == nil }) else { return }
        savedClassificationTask = Task { @MainActor in
            guard let classified = try? await searchFoodProductsUseCase.classifyFoods(items.map(\.product)),
                  !Task.isCancelled else { return }
            for product in classified {
                savedEntriesByID[product.id]?.foodType = product.foodType
            }
            savedItems = entries.compactMap { savedEntriesByID[$0.id] }.map(makeItem)
            if phase.value == .browse { renderBrowseSections() }
        }
    }

    private func publishBrowse() {
        phase.value = .browse
        suggestedItems.value = []
        resultItems.value = []
        resultsTitleText.value = ""
        showsEmptyResults.value = false
        isSearching.value = false
        mergeProducts(browseSections.value.flatMap(\.items))
        mergeProducts(savedItems)
        loadBrowseSections()
    }

    private func loadBrowseSections() {
        if scope.value == .products {
            loadProductCategories()
        } else if scope.value == .meals {
            loadRecipePreviews()
        } else {
            for category in visibleCatalogCategories {
                loadPreview(category)
            }
        }
        renderBrowseSections()
    }

    private func loadPreview(_ category: FoodSearchCategory) {
        guard catalogProducts[category] == nil, !loadingCategories.contains(category),
              !failedCategories.contains(category) else { return }
        loadingCategories.insert(category)
        Task { @MainActor in
            let page = await searchFoodProductsUseCase.executeCategoryCatalogPage(sectionID: category.rawValue, offset: 0, limit: 2)
            loadingCategories.remove(category)
            if page.isRetryableFailure {
                failedCategories.insert(category)
            } else {
                catalogProducts[category] = page.products.filter { product in
                    product.hasPhoto && (category == .preparedMeals ? product.resolvedFoodType == .dish : product.resolvedFoodType == .product)
                }
            }
            renderBrowseSections()
        }
    }

    private func loadRecipePreviews() {
        let categories = FoodSearchCategory.mealCategories.filter {
            catalogProducts[$0] == nil && !loadingCategories.contains($0) && !failedCategories.contains($0)
        }
        guard !categories.isEmpty else { return }
        loadingCategories.formUnion(categories)
        let useCase = fetchRecipeBrowseSectionsUseCase
        Task { @MainActor in
            for start in stride(from: 0, to: categories.count, by: 3) {
                let batch = categories[start..<min(start + 3, categories.count)]
                await withTaskGroup(of: (FoodSearchCategory, RecipeSectionPage).self) { group in
                    for category in batch {
                        guard let kind = category.recipeSection else { continue }
                        group.addTask { @MainActor in
                            (category, await useCase.recipesPage(in: kind, offset: 0, limit: 2))
                        }
                    }
                    for await (category, page) in group {
                        loadingCategories.remove(category)
                        if page.isRetryableFailure {
                            failedCategories.insert(category)
                        } else {
                            catalogProducts[category] = page.recipes.filter(\.hasPhoto).map(FoodProduct.init(recipe:))
                        }
                        renderBrowseSections()
                    }
                }
            }
        }
    }

    private func loadProductCategories() {
        guard !loadedProductCategories, !FoodSearchCategory.productCategories.contains(where: loadingCategories.contains) else { return }
        loadingCategories.formUnion(FoodSearchCategory.productCategories)
        Task { @MainActor in
            let catalog = await searchFoodProductsUseCase.executeDefaultCatalog()
            loadedProductCategories = !catalog.isEmpty
            for category in FoodSearchCategory.productCategories {
                loadingCategories.remove(category)
                if catalog.isEmpty {
                    failedCategories.insert(category)
                } else {
                    catalogProducts[category] = (catalog[category.rawValue] ?? []).filter { $0.hasPhoto && $0.resolvedFoodType == .product }
                    failedCategories.remove(category)
                }
            }
            renderBrowseSections()
        }
    }

    private func renderBrowseSections() {
        var sections: [FoodSearchBrowseSection] = []
        if includeRecipes {
            let recent = Array(savedItems.filter { scope.value.includes($0.product) }.prefix(2))
            if !recent.isEmpty { sections.append(FoodSearchBrowseSection(category: .recent, items: recent)) }
        }
        for category in visibleCatalogCategories {
            let items = (catalogProducts[category] ?? []).prefix(2).map(makeItem)
            let loading = loadingCategories.contains(category)
            let failed = failedCategories.contains(category)
            if FoodSearchCategory.productCategories.contains(category), items.isEmpty, !loading, !failed { continue }
            sections.append(FoodSearchBrowseSection(category: category, items: items, isLoading: loading, loadFailed: failed))
        }
        browseSections.value = sections
        mergeProducts(sections.flatMap(\.items))
        isLoadingBrowse.value = visibleCatalogCategories.contains(where: loadingCategories.contains)
    }

    private func mergeProducts(_ items: [FoodSearchItem]) {
        for item in items {
            productsByID[item.id] = item.product
        }
    }

    private func publish(_ products: [FoodProduct], track: Bool = true) {
        latestSearchProducts = products
        let ranked = SearchFoodProductsUseCase.ranked(products, query: queryText.value)
        let items = ranked.filter { scope.value.includes($0) }.map(makeItem)
        productsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.product) })
        let aiItems = items.filter { Self.isAISuggested($0.product) }
        let catalogItems = items.filter { !Self.isAISuggested($0.product) }
        let isEmpty = items.isEmpty
        showsEmptyResults.value = isEmpty && !isSearching.value
        suggestedItems.value = aiItems
        resultItems.value = catalogItems
        resultsTitleText.value = isEmpty ? L10n.tr("search.results") : (catalogItems.isEmpty ? "" : L10n.tr("search.results"))
        phase.value = .results
        guard track else { return }
        Analytics.tracker.track(.foodSearchPerformed(
            queryLength: queryText.value.trimmingCharacters(in: .whitespacesAndNewlines).count,
            resultCount: items.count
        ))
    }

    private static func identity(_ product: FoodProduct) -> String {
        "\(product.source.rawValue):\(product.kind.rawValue):\(product.externalId)"
    }

    private static func isAISuggested(_ product: FoodProduct) -> Bool {
        product.source.isAIRecipe || product.externalId.hasPrefix(AIFoodSearchService.idPrefix)
    }

    private static func keepingDisplayablePhotos(_ products: [FoodProduct]) -> [FoodProduct] {
        products.filter { $0.kind != .recipe || $0.hasPhoto }
    }

    private func kindLabel(_ product: FoodProduct) -> String {
        switch product.resolvedFoodType {
        case .dish: return L10n.tr("search.kind.meal")
        case .product: return L10n.tr("search.kind.product")
        case nil: return ""
        }
    }

    private func makeItem(_ product: FoodProduct) -> FoodSearchItem {
        FoodSearchItem(
            id: product.id,
            title: product.name,
            subtitle: includeRecipes
                ? [kindLabel(product), FoodSearchItem.detailLine(for: product)].filter { !$0.isEmpty }.joined(separator: " · ")
                : FoodSearchItem.detailLine(for: product),
            imageURL: product.imageURL,
            imageData: nil,
            product: product
        )
    }

    private func makeItem(_ entry: FoodEntry) -> FoodSearchItem {
        let product = FoodProduct(
            id: entry.id,
            externalId: entry.catalogExternalId ?? "saved-\(entry.id.uuidString)",
            name: entry.name,
            brand: nil,
            kind: entry.catalogKind ?? .ingredient,
            imageURL: entry.imageURL,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fats: entry.fats,
            amount: entry.portionGrams ?? entry.portionMilliliters,
            unit: entry.portionMilliliters != nil ? "ml" : "g",
            source: FoodProductSource(apiValue: entry.source),
            ingredients: entry.ingredientLines.isEmpty
                ? ProductDetailsMath.parseIngredientLines(entry.notes).map(ProductDetailsMath.formatIngredient)
                : entry.ingredientLines,
            steps: entry.recipeSteps,
            foodType: entry.resolvedFoodType,
            hasCompleteNutrition: entry.hasCompleteNutrition
        )
        return FoodSearchItem(
            id: entry.id,
            title: entry.name,
            subtitle: [kindLabel(product), subtitle(entry)].filter { !$0.isEmpty }.joined(separator: " · "),
            imageURL: entry.imageURL,
            imageData: entry.imageData,
            product: product
        )
    }

    private func subtitle(_ entry: FoodEntry) -> String {
        let kcal = Int(entry.calories.rounded())
        if let milliliters = entry.portionMilliliters {
            return "\(AppUnits.current.volumeText(milliliters)) • \(L10n.format("recipes.kcal", kcal))"
        }
        if let grams = entry.portionGrams {
            return "\(AppUnits.current.massText(grams)) • \(L10n.format("recipes.kcal", kcal))"
        }
        return L10n.format("recipes.kcal", kcal)
    }
}
