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
        let needsAIDetails = product.source.isAIRecipe
        guard needsAIDetails || product.calories == nil else { return }
        let shownImageURL = product.imageURL
        isLoading.value = true
        statusText.value = L10n.tr("recipes.loadingNutrition")
        Task { @MainActor in
            do {
                let shownAmount = product.amount
                let shownUnit = product.unit
                var details: FoodProduct
                if product.kind == .recipe {
                    if product.source.isAIRecipe || product.externalId.contains(where: { !$0.isNumber }) {
                        details = try await searchFoodProductsUseCase.enrichDetails(
                            title: product.name,
                            imageURL: product.imageURL,
                            source: product.source.rawValue,
                            kind: product.kind.rawValue
                        ) ?? product
                    } else {
                        details = try await searchFoodProductsUseCase.recipeDetails(id: product.externalId)
                    }
                } else if product.kind == .ingredient {
                    details = try await searchFoodProductsUseCase.ingredientDetails(id: product.externalId)
                } else {
                    isLoading.value = false
                    return
                }
                details.imageURL = shownImageURL ?? details.imageURL
                if !product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    details.name = product.name
                }
                if details.amount == nil {
                    details.amount = shownAmount
                }
                if details.unit == nil || details.unit?.isEmpty == true {
                    details.unit = shownUnit
                }
                product = details
                publish()
                statusText.value = L10n.tr("common.ready")
            } catch {
                statusText.value = error.localizedDescription
            }
            isLoading.value = false
        }
    }

    func logTapped(mealType: MealType = .snacks) {
        Task { @MainActor in
            do {
                let imageData = await Self.imageData(from: product.imageURL)
                _ = try logFoodUseCase.execute(from: product, mealType: mealType, imageData: imageData)
                statusText.value = L10n.format("recipes.loggedAs", mealType.localizedTitle)
                onLogged?()
            } catch {
                statusText.value = error.localizedDescription
            }
        }
    }

    private func publish() {
        titleText.value = product.name
        var lines: [String] = []
        lines.append(kindLabel(product.kind))
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

    private func kindLabel(_ kind: FoodProductKind) -> String {
        switch kind {
        case .ingredient:
            return L10n.tr("recipes.kindIngredient")
        case .product:
            return L10n.tr("recipes.kindProduct")
        case .recipe:
            return L10n.tr("recipes.generic")
        }
    }

    private static func imageData(from url: URL?) async -> Data? {
        guard let url else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            return data.isEmpty ? nil : data
        } catch {
            return nil
        }
    }
}
