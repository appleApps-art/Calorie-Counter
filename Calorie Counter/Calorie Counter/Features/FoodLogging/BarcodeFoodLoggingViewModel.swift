import Foundation

final class BarcodeFoodLoggingViewModel {
    let statusText = Observable(L10n.tr("barcode.status"))
    let productTitleText = Observable("")
    let productDetailsText = Observable("")
    let isLoading = Observable(false)
    let foundProduct = Observable<BarcodeProduct?>(nil)
    let canLogProduct = Observable(false)

    var onLogged: (() -> Void)?

    private let lookupBarcodeProductUseCase: LookupBarcodeProductUseCase
    private let logFoodUseCase: LogFoodUseCase

    init(
        lookupBarcodeProductUseCase: LookupBarcodeProductUseCase,
        logFoodUseCase: LogFoodUseCase
    ) {
        self.lookupBarcodeProductUseCase = lookupBarcodeProductUseCase
        self.logFoodUseCase = logFoodUseCase
    }

    func lookup(barcode: String) {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText.value = L10n.tr("barcode.enter")
            return
        }

        isLoading.value = true
        canLogProduct.value = false
        statusText.value = L10n.tr("barcode.lookingUp")
        foundProduct.value = nil
        productTitleText.value = ""
        productDetailsText.value = ""

        Task { @MainActor in
            do {
                let product = try await lookupBarcodeProductUseCase.execute(barcode: trimmed)
                foundProduct.value = product
                productTitleText.value = product.name
                productDetailsText.value = details(for: product)
                canLogProduct.value = true
                statusText.value = L10n.format("barcode.found", sourceLabel(product.source))
            } catch {
                foundProduct.value = nil
                canLogProduct.value = false
                statusText.value = error.localizedDescription
            }
            isLoading.value = false
        }
    }

    func logAsSnackTapped() {
        logTapped(mealType: .snacks)
    }

    func logTapped(mealType: MealType) {
        guard let product = foundProduct.value else { return }
        let draft = product.toFoodProduct(preferServing: false)
        do {
            try logFoodUseCase.execute(from: draft, mealType: mealType)
            statusText.value = L10n.format("barcode.loggedAs", mealType.localizedTitle)
            onLogged?()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func foodEntryDraft() -> FoodProduct? {
        foundProduct.value?.toFoodProduct(preferServing: false)
    }

    private func sourceLabel(_ source: BarcodeProductSource) -> String {
        switch source {
        case .openFoodFacts:
            return L10n.tr("barcode.source.off")
        case .spoonacular:
            return L10n.tr("barcode.source.spoonacular")
        }
    }

    private func details(for product: BarcodeProduct) -> String {
        var lines: [String] = []
        lines.append(L10n.format("barcode.line", product.barcode))
        if let brand = product.brand, !brand.isEmpty {
            lines.append(L10n.format("barcode.brand", brand))
        }
        if let quantity = product.quantityLabel, !quantity.isEmpty {
            lines.append(L10n.format("barcode.quantity", quantity))
        }
        if let calories = product.caloriesPer100g {
            lines.append(L10n.format("barcode.calories100", Int(calories.rounded())))
        }
        if let protein = product.proteinPer100g {
            lines.append(L10n.format("barcode.protein100", Int(protein.rounded())))
        }
        if let carbs = product.carbsPer100g {
            lines.append(L10n.format("barcode.carbs100", Int(carbs.rounded())))
        }
        if let fats = product.fatsPer100g {
            lines.append(L10n.format("barcode.fats100", Int(fats.rounded())))
        }
        if lines.count <= 1 {
            lines.append(L10n.tr("barcode.noNutrition"))
        }
        return lines.joined(separator: "\n")
    }
}
