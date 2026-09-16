import Foundation

struct PantryItem: Equatable, Identifiable {
    var id: UUID
    var name: String
    var quantityText: String
    var amount: Double?
    var unit: String?
    var useBy: Date?
    var imageURL: URL?
    var imageData: Data?
    var createdAt: Date
    var updatedAt: Date

    var subtitle: String {
        var parts: [String] = []
        let quantity = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let amount, let unit, let display = AppUnits.current.quantity(amount, unit: unit) {
            parts.append(display)
        } else if !quantity.isEmpty {
            parts.append(quantity)
        } else if let amount, let unit, !unit.isEmpty {
            parts.append(Self.amountText(amount, unit: unit))
        }
        if let useBy {
            parts.append(L10n.format("pantry.useBy", Self.useByFormatter.string(from: useBy)))
        }
        return parts.joined(separator: " · ")
    }

    static func amountText(_ amount: Double, unit: String) -> String {
        let value = amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(amount.rounded()))
            : String(format: "%g", amount)
        return "\(value) \(unit)"
    }

    static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        let left = matchKey(lhs)
        let right = matchKey(rhs)
        return !left.isEmpty && left == right
    }

    static func isSameProduct(_ lhs: PantryItem, _ rhs: PantryItem) -> Bool {
        if namesMatch(lhs.name, rhs.name) {
            return true
        }
        return imageURLsMatch(lhs.imageURL, rhs.imageURL)
    }

    static func excludingExisting(_ items: [PantryItem], in existing: [PantryItem]) -> [PantryItem] {
        var kept: [PantryItem] = []
        for item in items {
            let pool = existing + kept
            if pool.contains(where: { isSameProduct($0, item) }) {
                continue
            }
            kept.append(item)
        }
        return kept
    }

    static func matchKey(_ name: String) -> String {
        let folded = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
        let tokens = folded
            .split { $0.isWhitespace || $0.isPunctuation }
            .map { stripPlural(String($0)) }
            .filter { !$0.isEmpty }
        return tokens.joined(separator: " ")
    }

    private static func stripPlural(_ token: String) -> String {
        if token.count >= 5, token.hasSuffix("oes") {
            return String(token.dropLast(2))
        }
        if token.count >= 5, token.hasSuffix("ies") {
            return String(token.dropLast(3)) + "y"
        }
        if token.count >= 4, token.hasSuffix("s"), !token.hasSuffix("ss") {
            return String(token.dropLast())
        }
        if token.count >= 5, token.hasSuffix("и") || token.hasSuffix("і") {
            return String(token.dropLast())
        }
        return token
    }

    private static func imageURLsMatch(_ lhs: URL?, _ rhs: URL?) -> Bool {
        guard let lhs, let rhs else { return false }
        guard !FoodImageURL.isPlaceholder(lhs), !FoodImageURL.isPlaceholder(rhs) else { return false }
        func canonical(_ url: URL) -> String {
            url.absoluteString.replacingOccurrences(
                of: "/ingredients_250x250/",
                with: "/ingredients_100x100/"
            )
        }
        return canonical(lhs) == canonical(rhs)
    }

    func mergingIncoming(_ incoming: PantryItem) -> PantryItem {
        var result = self
        if result.imageURL == nil {
            result.imageURL = incoming.imageURL
        }
        if result.imageData == nil || result.imageData?.isEmpty == true {
            result.imageData = incoming.imageData
        }
        if result.useBy == nil {
            result.useBy = incoming.useBy
        }
        let existingUnit = Self.normalizedUnit(unit)
        let incomingUnit = Self.normalizedUnit(incoming.unit)
        if let existingAmount = amount,
           let incomingAmount = incoming.amount,
           !existingUnit.isEmpty,
           existingUnit == incomingUnit {
            let total = existingAmount + incomingAmount
            result.amount = total
            result.unit = unit ?? incoming.unit
            if let unit = result.unit, !unit.isEmpty {
                result.quantityText = Self.amountText(total, unit: unit)
            }
        } else if quantityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.quantityText = incoming.quantityText
            result.amount = incoming.amount ?? result.amount
            result.unit = incoming.unit ?? result.unit
        }
        return result
    }

    private static func normalizedUnit(_ unit: String?) -> String {
        unit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    static let useByFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    static let expiryDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter
    }()

    static func from(ingredient: FoodIngredient, imageData: Data? = nil, imageURL: URL? = nil) -> PantryItem {
        let now = Date()
        let quantity: String
        let amount: Double?
        let unit: String?
        if let grams = ingredient.grams {
            amount = grams
            unit = "g"
            quantity = amountText(grams, unit: "g")
        } else if let milliliters = ingredient.milliliters {
            amount = milliliters
            unit = "ml"
            quantity = amountText(milliliters, unit: "ml")
        } else {
            amount = nil
            unit = nil
            quantity = ""
        }
        return PantryItem(
            id: UUID(),
            name: ingredient.name,
            quantityText: quantity,
            amount: amount,
            unit: unit,
            useBy: nil,
            imageURL: imageURL,
            imageData: imageData,
            createdAt: now,
            updatedAt: now
        )
    }

    static func from(analysis: FoodPhotoAnalysis) -> [PantryItem] {
        if analysis.ingredients.isEmpty {
            let ingredient = FoodIngredient(
                name: analysis.name,
                grams: analysis.portionGrams,
                milliliters: analysis.portionMilliliters
            )
            return [from(ingredient: ingredient)]
        }
        return analysis.ingredients.map { from(ingredient: $0) }
    }

    static func from(product: FoodProduct) -> PantryItem {
        let now = Date()
        let quantity: String
        if let serving = product.servingSizeLabel, !serving.isEmpty {
            quantity = serving
        } else if let amount = product.amount, let unit = product.unit, !unit.isEmpty {
            quantity = amountText(amount, unit: unit)
        } else {
            quantity = ""
        }
        return PantryItem(
            id: UUID(),
            name: product.name,
            quantityText: quantity,
            amount: product.amount,
            unit: product.unit,
            useBy: nil,
            imageURL: product.imageURL,
            imageData: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    static func from(draft: ProductDetailsDraft) -> PantryItem {
        let now = Date()
        let quantity: String
        let amount: Double?
        let unit: String?
        if let grams = draft.portionGrams {
            amount = grams
            unit = "g"
            quantity = draft.servingLabel.isEmpty ? amountText(grams, unit: "g") : draft.servingLabel
        } else if let milliliters = draft.portionMilliliters {
            amount = milliliters
            unit = "ml"
            quantity = draft.servingLabel.isEmpty ? amountText(milliliters, unit: "ml") : draft.servingLabel
        } else {
            amount = nil
            unit = nil
            quantity = draft.servingLabel
        }
        return PantryItem(
            id: UUID(),
            name: draft.name,
            quantityText: quantity,
            amount: amount,
            unit: unit,
            useBy: nil,
            imageURL: draft.imageURL,
            imageData: draft.imageData,
            createdAt: now,
            updatedAt: now
        )
    }
}
