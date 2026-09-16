import Foundation

final class MyPantryViewModel {
    let items = Observable<[PantryItem]>([])
    let suggestion = Observable<Recipe?>(nil)
    let isSelecting = Observable(false)
    let selectedIDs = Observable<Set<UUID>>([])
    let showsDeleteAlert = Observable(false)
    let isLoading = Observable(false)

    var onBack: (() -> Void)?
    var onAdd: (() -> Void)?
    var onEdit: ((PantryItem) -> Void)?
    var onOpenDetails: ((PantryItem) -> Void)?
    var onOpenRecipe: ((Recipe) -> Void)?
    var onCreateRecipe: (() -> Void)?

    private let fetchPantryItemsUseCase: FetchPantryItemsUseCase
    private let savePantryItemUseCase: SavePantryItemUseCase
    private let deletePantryItemsUseCase: DeletePantryItemsUseCase
    private let searchRecipesUseCase: SearchRecipesUseCase

    init(
        fetchPantryItemsUseCase: FetchPantryItemsUseCase,
        savePantryItemUseCase: SavePantryItemUseCase,
        deletePantryItemsUseCase: DeletePantryItemsUseCase,
        searchRecipesUseCase: SearchRecipesUseCase
    ) {
        self.fetchPantryItemsUseCase = fetchPantryItemsUseCase
        self.savePantryItemUseCase = savePantryItemUseCase
        self.deletePantryItemsUseCase = deletePantryItemsUseCase
        self.searchRecipesUseCase = searchRecipesUseCase
    }

    var navTitle: String {
        if isSelecting.value {
            let count = selectedIDs.value.count
            return count == 0 ? L10n.tr("pantry.selectIngredients") : L10n.format("pantry.selectedCount", count)
        }
        return L10n.tr("pantry.title")
    }

    var selectAllButtonTitle: String {
        selectedIDs.value.count == items.value.count && !items.value.isEmpty
            ? L10n.tr("pantry.deselectAll")
            : L10n.tr("pantry.selectAll")
    }

    func viewDidLoad() {
        reload()
    }

    func reload() {
        items.value = (try? fetchPantryItemsUseCase.execute()) ?? []
        loadSuggestion()
    }

    func backTapped() {
        if isSelecting.value {
            isSelecting.value = false
            selectedIDs.value = []
            showsDeleteAlert.value = false
            return
        }
        onBack?()
    }

    func addTapped() { onAdd?() }

    func createRecipeTapped() { onCreateRecipe?() }

    func selectModeTapped() {
        isSelecting.value = true
    }

    func selectAllTapped() {
        if selectedIDs.value.count == items.value.count {
            selectedIDs.value = []
        } else {
            selectedIDs.value = Set(items.value.map(\.id))
        }
    }

    func toggleItem(_ id: UUID) {
        var next = selectedIDs.value
        if next.contains(id) {
            next.remove(id)
        } else {
            next.insert(id)
        }
        selectedIDs.value = next
    }

    func itemTapped(_ item: PantryItem) {
        onOpenDetails?(item)
    }

    func editTapped(_ item: PantryItem) {
        onEdit?(item)
    }

    func deleteTapped(_ item: PantryItem) {
        selectedIDs.value = [item.id]
        showsDeleteAlert.value = true
    }

    func deleteSelectedTapped() {
        guard !selectedIDs.value.isEmpty else { return }
        showsDeleteAlert.value = true
    }

    func cancelDelete() {
        showsDeleteAlert.value = false
    }

    func confirmDelete() {
        let ids = Array(selectedIDs.value)
        try? deletePantryItemsUseCase.execute(ids: ids)
        showsDeleteAlert.value = false
        isSelecting.value = false
        selectedIDs.value = []
        reload()
    }

    func suggestionTapped() {
        if let recipe = suggestion.value {
            onOpenRecipe?(recipe)
        }
    }

    func save(_ item: PantryItem) {
        try? savePantryItemUseCase.execute(item)
        reload()
    }

    func save(items: [PantryItem]) {
        try? savePantryItemUseCase.execute(items: items)
        reload()
    }

    private func loadSuggestion() {
        let names = items.value.prefix(6).map(\.name)
        guard !names.isEmpty else {
            suggestion.value = nil
            return
        }
        Task { @MainActor in
            let recipes = (try? await searchRecipesUseCase.execute(query: names.joined(separator: " "))) ?? []
            suggestion.value = recipes.first
        }
    }
}
