import Foundation

final class SpoonacularBarcodeLookupService: BarcodeProductLookingUp {
    private let spoonacularService: SpoonacularServiceProtocol

    init(spoonacularService: SpoonacularServiceProtocol) {
        self.spoonacularService = spoonacularService
    }

    func lookup(barcode: String) async throws -> BarcodeProduct {
        try await spoonacularService.productByBarcode(barcode)
    }
}
