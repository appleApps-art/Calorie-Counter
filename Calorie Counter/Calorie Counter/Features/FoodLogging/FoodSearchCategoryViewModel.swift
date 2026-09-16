import Foundation

final class FoodSearchCategoryViewModel {
    let titleText: String
    let items = Observable<[FoodSearchItem]>([])
    let isLoading = Observable(false)
    let isLoadingMore = Observable(false)
    let loadFailed = Observable(false)

    var onBack: (() -> Void)?
    var onOpenDetails: ((ProductDetailsDraft) -> Void)?

    private let category: FoodSearchCategory
    private let mealType: MealType
    private let date: Date
    private let searchFoodProductsUseCase: SearchFoodProductsUseCase
    private let fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase
    private var productsByID: [UUID: FoodProduct] = [:]
    private var nextOffset = 0
    private var hasMore = true
    private var didStartLoading = false
    private var hasLoadedFirstPage = false

    init(
        category: FoodSearchCategory,
        mealType: MealType,
        date: Date,
        searchFoodProductsUseCase: SearchFoodProductsUseCase,
        fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase,
        previewItems: [FoodSearchItem] = []
    ) {
        self.category = category
        self.mealType = mealType
        self.date = date
        self.searchFoodProductsUseCase = searchFoodProductsUseCase
        self.fetchRecipeBrowseSectionsUseCase = fetchRecipeBrowseSectionsUseCase
        titleText = L10n.tr(category.titleKey)
        if !previewItems.isEmpty {
            apply(previewItems, nextOffset: previewItems.count, hasMore: true)
        }
    }

    func viewDidLoad() {
        guard !didStartLoading else { return }
        didStartLoading = true
        let seeded = !items.value.isEmpty
        isLoading.value = !seeded
        isLoadingMore.value = seeded
        Task { @MainActor in
            await loadPage(offset: 0, replacing: true)
            hasLoadedFirstPage = true
            isLoading.value = false
            isLoadingMore.value = false
        }
    }

    func loadMoreIfNeeded() {
        guard hasLoadedFirstPage, hasMore, !loadFailed.value, !isLoading.value, !isLoadingMore.value else { return }
        isLoadingMore.value = true
        Task { @MainActor in
            await loadPage(offset: nextOffset, replacing: nextOffset == 0)
            isLoadingMore.value = false
        }
    }

    func retryLoading() {
        loadFailed.value = false
        loadMoreIfNeeded()
    }

    func backTapped() {
        onBack?()
    }

    func selectItem(id: UUID) {
        guard let product = productsByID[id] else { return }
        onOpenDetails?(
            ProductDetailsMath.draft(
                from: product,
                imageData: nil,
                mealType: mealType,
                date: date
            )
        )
    }

    private func loadPage(offset: Int, replacing: Bool) async {
        let page: FoodSearchCatalogPage
        if let kind = category.recipeSection {
            let recipesPage = await fetchRecipeBrowseSectionsUseCase.recipesPage(in: kind, offset: offset)
            page = FoodSearchCatalogPage(products: recipesPage.recipes.map(FoodProduct.init(recipe:)),
                nextOffset: recipesPage.nextOffset, hasMore: recipesPage.hasMore, isRetryableFailure: recipesPage.isRetryableFailure)
        } else {
            page = await searchFoodProductsUseCase.executeCategoryCatalogPage(sectionID: category.rawValue, offset: offset)
        }
        if page.isRetryableFailure {
            loadFailed.value = true
            nextOffset = offset
            return
        }
        let mapped = page.products.filter(\.hasPhoto).map(Self.makeItem)
        nextOffset = page.nextOffset
        hasMore = page.hasMore
        if replacing || items.value.isEmpty {
            apply(mapped, nextOffset: page.nextOffset, hasMore: page.hasMore)
            return
        }
        var existing = Set(items.value.map { Self.identity($0.product) })
        let appended = mapped.filter { existing.insert(Self.identity($0.product)).inserted }
        guard !appended.isEmpty else { return }
        for item in appended {
            productsByID[item.id] = item.product
        }
        items.value += appended
    }

    private func apply(_ mapped: [FoodSearchItem], nextOffset: Int, hasMore: Bool) {
        productsByID = Dictionary(uniqueKeysWithValues: mapped.map { ($0.id, $0.product) })
        self.nextOffset = nextOffset
        self.hasMore = hasMore
        items.value = mapped
    }

    private static func identity(_ product: FoodProduct) -> String {
        let externalID = product.externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        let identifier = externalID.isEmpty ? product.name.lowercased() : externalID
        return "\(product.source.rawValue):\(product.kind.rawValue):\(identifier)"
    }

    private static func makeItem(_ product: FoodProduct) -> FoodSearchItem {
        FoodSearchItem(
            id: product.id,
            title: product.name,
            subtitle: FoodSearchItem.detailLine(for: product),
            imageURL: product.imageURL,
            imageData: nil,
            product: product
        )
    }
}
