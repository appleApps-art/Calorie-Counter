import Foundation

final class FridgePhotoResultViewModel {
    let items = Observable<[PantryItem]>([])
    let titleText = Observable("")
    let isSelecting = Observable(false)
    let selectedIDs = Observable<Set<UUID>>([])

    var onBack: (() -> Void)?
    var onEdit: ((PantryItem) -> Void)?
    var onAdded: (([PantryItem]) -> Void)?

    init(items: [PantryItem]) {
        self.items.value = items
        publishTitle()
    }

    func backTapped() {
        if isSelecting.value {
            isSelecting.value = false
            selectedIDs.value = []
            return
        }
        onBack?()
    }

    func selectTapped() {
        isSelecting.value = true
        selectedIDs.value = []
    }

    var selectAllButtonTitle: String {
        selectedIDs.value.count == items.value.count && !items.value.isEmpty
            ? L10n.tr("pantry.deselectAll")
            : L10n.tr("pantry.selectAll")
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

    func editTapped(_ item: PantryItem) { onEdit?(item) }

    func delete(_ item: PantryItem) {
        items.value.removeAll { $0.id == item.id }
        selectedIDs.value.remove(item.id)
        publishTitle()
        if items.value.isEmpty {
            onBack?()
        }
    }

    func deleteSelectedTapped() {
        let ids = selectedIDs.value
        guard !ids.isEmpty else { return }
        items.value.removeAll { ids.contains($0.id) }
        selectedIDs.value = []
        isSelecting.value = false
        publishTitle()
        if items.value.isEmpty {
            onBack?()
        }
    }

    func replace(_ item: PantryItem) {
        if let index = items.value.firstIndex(where: { $0.id == item.id }) {
            items.value[index] = item
        }
    }

    func addTapped() {
        onAdded?(items.value)
    }

    var addTitle: String {
        L10n.format("pantry.addItems", items.value.count)
    }

    private func publishTitle() {
        titleText.value = L10n.format("pantry.detectedTitle", items.value.count)
    }
}
