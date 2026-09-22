import Foundation

enum BarcodeNormalization {
    static func normalize(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard (8...14).contains(digits.count) else { return nil }
        return digits
    }

    /// A code as printed on a pack: EAN-8, UPC-A, EAN-13 or GTIN-14 with a correct check digit,
    /// or an 8-digit UPC-E. Anything else read by the camera is some other code on the pack.
    static func isProductCode(_ raw: String) -> Bool {
        guard raw.allSatisfy(\.isNumber), let digits = normalize(raw) else { return false }
        switch digits.count {
        case 8:
            // UPC-E checks against its expanded UPC-A form; EAN-8 against itself.
            return hasValidCheckDigit(digits) || hasValidCheckDigit(expandUPCE(digits) ?? "")
        case 12, 13, 14:
            return hasValidCheckDigit(digits)
        default:
            return false
        }
    }

    /// GS1 check digit: weights 3 and 1 alternate from the digit next to the check digit.
    static func hasValidCheckDigit(_ digits: String) -> Bool {
        let values = digits.compactMap(\.wholeNumberValue)
        guard values.count >= 8, values.count == digits.count, let check = values.last else { return false }
        let sum = values.dropLast().reversed().enumerated().reduce(0) { total, item in
            total + item.element * (item.offset.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - sum % 10) % 10 == check
    }

    private static func expandUPCE(_ code: String) -> String? {
        let d = code.compactMap(\.wholeNumberValue)
        guard d.count == 8, d[0] == 0 || d[0] == 1 else { return nil }
        let (m1, m2, m3, m4, m5, m6) = (d[1], d[2], d[3], d[4], d[5], d[6])
        let body: [Int]
        switch m6 {
        case 0, 1, 2: body = [m1, m2, m6, 0, 0, 0, 0, m3, m4, m5]
        case 3: body = [m1, m2, m3, 0, 0, 0, 0, 0, m4, m5]
        case 4: body = [m1, m2, m3, m4, 0, 0, 0, 0, 0, m5]
        default: body = [m1, m2, m3, m4, m5, 0, 0, 0, 0, m6]
        }
        return ([d[0]] + body + [d[7]]).map(String.init).joined()
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
