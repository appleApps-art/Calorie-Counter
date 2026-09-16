import Foundation

final class PantryItemEditViewModel {
    let nameText = Observable("")
    let quantityText = Observable("")
    let expiry = Observable<Date?>(nil)

    var onClose: (() -> Void)?
    var onSave: ((PantryItem) -> Void)?

    private var item: PantryItem

    var imageURL: URL? { item.imageURL }
    var imageData: Data? { item.imageData }

    init(item: PantryItem) {
        self.item = item
        nameText.value = item.name
        quantityText.value = item.quantityText
        expiry.value = item.useBy
    }

    func closeTapped() { onClose?() }

    func displayedQuantity() -> String {
        if let amount = item.amount, let unit = item.unit, let display = AppUnits.current.quantity(amount, unit: unit) { return display }
        let text = quantityText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        if let amount = item.amount, let unit = item.unit, !unit.isEmpty {
            return PantryItem.amountText(amount, unit: unit)
        }
        return ""
    }

    func numericQuantityText() -> String {
        if let amount = item.amount {
            if !AppUnits.current.usesMetric, let unit = item.unit, AppUnits.current.quantity(amount, unit: unit) != nil {
                return AppUnits.current.number(unit.lowercased().hasPrefix("m") ? AppUnits.current.volume(amount) : AppUnits.current.mass(amount))
            }
            return ProductDetailsMath.formatNumber(amount)
        }
        if let parsed = ProductDetailsMath.parsePortion(quantityText.value) {
            return ProductDetailsMath.formatNumber(parsed.value)
        }
        return ""
    }

    func commitQuantity(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            item.amount = nil
            item.quantityText = ""
            quantityText.value = ""
            return
        }
        if trimmed == numericQuantityText() { return }
        var input = trimmed
        if !AppUnits.current.usesMetric, let unit = item.unit, AppUnits.current.quantity(1, unit: unit) != nil,
           Double(trimmed.replacingOccurrences(of: ",", with: ".")) != nil {
            input += " " + (unit.lowercased().hasPrefix("m") ? "fl oz" : "oz")
        }
        guard let parsed = ProductDetailsMath.parsePortion(input) else { return }
        let unit = resolvedUnit(parsedIsMilliliters: parsed.isMilliliters)
        item.amount = parsed.value
        item.unit = unit
        item.quantityText = PantryItem.amountText(parsed.value, unit: unit)
        quantityText.value = item.quantityText
    }

    func updateExpiry(_ date: Date) {
        expiry.value = date
    }

    func saveTapped() {
        item.quantityText = quantityText.value
        item.useBy = expiry.value
        item.updatedAt = Date()
        onSave?(item)
    }

    private func resolvedUnit(parsedIsMilliliters: Bool) -> String {
        if parsedIsMilliliters {
            let existing = item.unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return existing.isEmpty ? "ml" : existing
        }
        let existing = item.unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if existing.isEmpty { return "g" }
        return existing
    }
}
