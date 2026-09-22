import Foundation
import UIKit

final class FoodRecipeViewModel {
    let nameText = Observable("")
    let subtitleText = Observable("")
    let ingredients = Observable<[FoodIngredient]>([])
    let steps = Observable<[String]>([])
    let ingredientsVisible = Observable(false)
    let stepsVisible = Observable(false)
    let heroImage = Observable<UIImage?>(nil)
    let savedAlertVisible = Observable(false)

    var onClose: (() -> Void)?

    private let recipeRepository: RecipeRepositoryProtocol
    private var draft: ProductDetailsDraft?

    init(recipeRepository: RecipeRepositoryProtocol) {
        self.recipeRepository = recipeRepository
    }

    func configure(_ draft: ProductDetailsDraft) {
        self.draft = draft
        nameText.value = draft.name
        var reference = draft
        reference.servings = 1
        subtitleText.value = Self.subtitle(for: reference)
        ingredients.value = draft.ingredients
        ingredientsVisible.value = !draft.ingredients.isEmpty
        steps.value = draft.recipeSteps
        stepsVisible.value = !draft.recipeSteps.isEmpty
        loadHeroImage()
    }

    func closeTapped() {
        onClose?()
    }

    func saveTapped() {
        guard let draft else { return }
        let recipe = Recipe(
            id: UUID(),
            externalId: draft.catalogExternalId,
            title: draft.name,
            summary: draft.notes.isEmpty ? nil : draft.notes,
            imageURL: draft.imageURL,
            readyInMinutes: nil,
            servings: 1,
            calories: draft.calories,
            protein: draft.protein,
            carbs: draft.carbs,
            fats: draft.fats,
            ingredients: draft.ingredients.map { item in
                RecipeIngredient(
                    id: item.id.uuidString,
                    name: item.name,
                    amount: item.grams ?? item.milliliters,
                    unit: item.grams != nil ? "g" : (item.milliliters != nil ? "ml" : nil),
                    originalText: item.name
                )
            },
            steps: draft.recipeSteps,
            sourceName: draft.source.isEmpty ? nil : draft.source,
            origin: FoodProductSource(apiValue: draft.source),
            weightGrams: draft.portionGrams,
            volumeMilliliters: draft.portionMilliliters
        )
        do {
            try recipeRepository.save(recipe)
            savedAlertVisible.value = true
        } catch {
            savedAlertVisible.value = false
        }
    }

    func dismissSavedAlert() {
        savedAlertVisible.value = false
    }

    private func loadHeroImage() {
        guard let draft else {
            heroImage.value = nil
            return
        }
        if let data = draft.imageData, let image = StoredPhoto.image(from: data, maxPixelSize: StoredPhoto.maxDimension) {
            heroImage.value = image
            return
        }
        heroImage.value = nil
        guard let url = draft.imageURL else { return }
        Task { @MainActor [weak self] in
            guard let image = await RemoteImageLoader.shared.fetch(url) else { return }
            guard self?.draft?.imageURL == url else { return }
            self?.heroImage.value = image
        }
    }

    private static func subtitle(for draft: ProductDetailsDraft) -> String {
        var parts: [String] = []
        if draft.calories > 0 {
            parts.append(L10n.format("recipes.kcal", Int(draft.calories.rounded())))
        }
        let servingKey = draft.servings == 1
            ? "product.details.servingCountOne"
            : "product.details.servingCountMany"
        var serving = L10n.format(servingKey, draft.servings)
        let portion = ProductDetailsMath.formatPortion(
            grams: draft.portionGrams,
            milliliters: draft.portionMilliliters
        )
        if !portion.isEmpty {
            serving = "\(serving) (\(portion))"
        }
        parts.append(serving)
        return parts.joined(separator: " · ")
    }
}
