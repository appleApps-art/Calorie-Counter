import Foundation

enum BarcodeNormalization {
    static func normalize(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard (8...14).contains(digits.count) else { return nil }
        return digits
    }

    static func groupedDisplay(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(14))
        guard digits.count > 1 else { return digits }
        if digits.count <= 7 {
            return "\(digits.prefix(1)) \(digits.dropFirst())"
        }
        let head = digits.prefix(1)
        let middle = digits.dropFirst().prefix(6)
        let tail = digits.dropFirst(7)
        return "\(head) \(middle) \(tail)"
    }
}

enum BarcodeLookupError: LocalizedError, Equatable {
    case invalidBarcode
    case notFound
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return L10n.tr("barcode.error.invalid")
        case .notFound:
            return L10n.tr("barcode.error.notFound")
        case .unavailable:
            return L10n.tr("barcode.error.unavailable")
        }
    }
}

protocol BarcodeProductLookingUp {
    func lookup(barcode: String) async throws -> BarcodeProduct
}
