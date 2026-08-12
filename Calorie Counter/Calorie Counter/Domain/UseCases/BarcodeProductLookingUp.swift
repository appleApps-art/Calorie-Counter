import Foundation

enum BarcodeNormalization {
    static func normalize(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard (8...14).contains(digits.count) else { return nil }
        return digits
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
