import Foundation

final class FoodProductDetailViewModel {
    let titleText = Observable("")
    let detailsText = Observable("")
    let statusText = Observable("")
    let isLoading = Observable(false)
    let canLog = Observable(false)

    var onLogged: (() -> Void)?

    private var product: FoodProduct
    private let searchFoodProductsUseCase: SearchFoodProductsUseCase
    private let logFoodUseCase: LogFoodUseCase

    init(
        product: FoodProduct,
        searchFoodProductsUseCase: SearchFoodProductsUseCase,
        logFoodUseCase: LogFoodUseCase
    ) {
        self.product = product
        self.searchFoodProductsUseCase = searchFoodProductsUseCase
        self.logFoodUseCase = logFoodUseCase
        publish()
    }

    func viewDidLoad() {
        guard product.kind == .ingredient, product.calories == nil else { return }
        isLoading.value = true
        statusText.value = L10n.tr("recipes.loadingNutrition")
        Task { @MainActor in
            do {
                product = try await searchFoodProductsUseCase.ingredientDetails(id: product.externalId)
                publish()
                statusText.value = L10n.tr("common.ready")
            } catch {
                statusText.value = error.localizedDescription
            }
            isLoading.value = false
        }
    }

    func logTapped(mealType: MealType = .snacks) {
        do {
            _ = try logFoodUseCase.execute(from: product, mealType: mealType)
            statusText.value = L10n.format("recipes.loggedAs", mealType.localizedTitle)
            onLogged?()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    private func publish() {
        titleText.value = product.name
        var lines: [String] = []
        lines.append(product.kind == .ingredient ? L10n.tr("recipes.kindIngredient") : L10n.tr("recipes.kindProduct"))
        if let brand = product.brand, !brand.isEmpty {
            lines.append(L10n.format("barcode.brand", brand))
        }
        if let amount = product.amount, let unit = product.unit {
            lines.append(L10n.format("recipes.portionLine", amount, unit))
        }
        if let calories = product.calories {
            lines.append(L10n.format("textLog.caloriesLine", Int(calories.rounded())))
        }
        if let protein = product.protein {
            lines.append(L10n.format("recipes.proteinLine", Int(protein.rounded())))
        }
        if let carbs = product.carbs {
            lines.append(L10n.format("recipes.carbsLine", Int(carbs.rounded())))
        }
        if let fats = product.fats {
            lines.append(L10n.format("recipes.fatsLine", Int(fats.rounded())))
        }
        if lines.count <= 1 {
            lines.append(L10n.tr("recipes.nutritionHint"))
        }
        detailsText.value = lines.joined(separator: "\n")
        canLog.value = product.calories != nil
    }
}
