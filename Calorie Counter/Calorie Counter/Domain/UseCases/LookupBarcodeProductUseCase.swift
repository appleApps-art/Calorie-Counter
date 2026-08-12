import Foundation

final class LookupBarcodeProductUseCase {
    private let primary: BarcodeProductLookingUp
    private let fallback: BarcodeProductLookingUp?

    init(primary: BarcodeProductLookingUp, fallback: BarcodeProductLookingUp? = nil) {
        self.primary = primary
        self.fallback = fallback
    }

    func execute(barcode: String) async throws -> BarcodeProduct {
        guard let normalized = BarcodeNormalization.normalize(barcode) else {
            throw BarcodeLookupError.invalidBarcode
        }

        do {
            return try await primary.lookup(barcode: normalized)
        } catch BarcodeLookupError.notFound {
            guard let fallback else { throw BarcodeLookupError.notFound }
            return try await fallback.lookup(barcode: normalized)
        } catch {
            guard let fallback else { throw error }
            do {
                return try await fallback.lookup(barcode: normalized)
            } catch {
                throw BarcodeLookupError.notFound
            }
        }
    }
}
