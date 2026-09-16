import Foundation

final class RecipeSectionViewModel {
    let titleText: String
    let recipes = Observable<[Recipe]>([])
    let isLoading = Observable(false)
    let isLoadingMore = Observable(false)

    var onBack: (() -> Void)?
    var onSelectRecipe: ((Recipe) -> Void)?

    private let kind: RecipeBrowseSectionKind
    private let fetchBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase
    private var nextOffset = 0
    private var hasMore = true

    init(
        kind: RecipeBrowseSectionKind,
        title: String,
        fetchBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase
    ) {
        self.kind = kind
        titleText = title
        self.fetchBrowseSectionsUseCase = fetchBrowseSectionsUseCase
    }

    func viewDidLoad() {
        isLoading.value = true
        Task { @MainActor in
            let page = await fetchBrowseSectionsUseCase.recipesPage(in: kind, offset: 0)
            recipes.value = page.recipes
            nextOffset = page.nextOffset
            hasMore = page.hasMore
            isLoading.value = false
        }
    }

    func loadMoreIfNeeded() {
        guard hasMore, !isLoading.value, !isLoadingMore.value else { return }
        isLoadingMore.value = true
        Task { @MainActor in
            let page = await fetchBrowseSectionsUseCase.recipesPage(in: kind, offset: nextOffset)
            let existing = Set(recipes.value.compactMap(\.externalId))
            let appended = page.recipes.filter { recipe in
                guard let id = recipe.externalId else { return true }
                return !existing.contains(id)
            }
            nextOffset = page.nextOffset
            hasMore = page.hasMore
            isLoadingMore.value = false
            if !appended.isEmpty {
                recipes.value += appended
            }
        }
    }

    func backTapped() { onBack?() }
    func select(_ recipe: Recipe) { onSelectRecipe?(recipe) }
}
