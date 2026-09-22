import Foundation
import UIKit

final class AddFoodEntryViewModel {
    enum Presentation {
        case foodPage
        case recipeSheet
    }

    let draft = Observable<ProductDetailsDraft?>(nil)
    let nameText = Observable("")
    let subtitleText = Observable("")
    let portionText = Observable("")
    let servingsText = Observable("1")
    let canDecrementServings = Observable(false)
    let canIncrementServings = Observable(true)
    let dateText = Observable("")
    let nutritionHeaderText = Observable("")
    let caloriesText = Observable("")
    let proteinText = Observable("")
    let fatText = Observable("")
    let carbsText = Observable("")
    let ingredients = Observable<[FoodIngredient]>([])
    let selectedMeal = Observable(MealType.lunch)
    let showsAddedAlert = Observable(false)
    let addedAlertText = Observable("")
    let heroImage = Observable<UIImage?>(nil)
    let errorText = Observable("")
    let isRecalculatingNutrition = Observable(false)
    let canAddEntry = Observable(true)
    let canEditPortion = Observable(false)
    let addButtonTitle = Observable(L10n.tr("product.entry.add"))
    private(set) var presentation: Presentation = .foodPage

    var onBack: (() -> Void)?
    var onChangeDate: (([Date]) -> Void)?
    var onFinished: (() -> Void)?

    private let logFoodUseCase: LogFoodUseCase
    private let stageEntries: (([FoodEntry]) throws -> Void)?
    private let analyzeIngredients: ((String, MealType) async throws -> FoodPhotoAnalysis)?
    private var loadedHeroKey: String?
    private var needsNutritionRecalculation = false
    private var recalculationID = UUID()
    private var recalculationTask: Task<Void, Never>?
    private struct IngredientClarification: Error {
        let message: String
    }

    init(
        logFoodUseCase: LogFoodUseCase,
        stageEntries: (([FoodEntry]) throws -> Void)? = nil,
        analyzeIngredients: ((String, MealType) async throws -> FoodPhotoAnalysis)? = nil
    ) {
        self.logFoodUseCase = logFoodUseCase
        self.stageEntries = stageEntries
        self.analyzeIngredients = analyzeIngredients
    }

    func configure(_ value: ProductDetailsDraft, presentation: Presentation? = nil) {
        recalculationTask?.cancel()
        recalculationID = UUID()
        needsNutritionRecalculation = false
        isRecalculatingNutrition.value = false
        errorText.value = ""
        if let presentation {
            self.presentation = presentation
        }
        updateDraft(value)
    }

    private func updateDraft(_ value: ProductDetailsDraft) {
        draft.value = ProductDetailsMath.fillingDefaultPortion(value)
        publish()
    }

    func backTapped() {
        onBack?()
    }

    func changeDateTapped() {
        onChangeDate?(draft.value?.resolvedLogDates() ?? [Date()])
    }

    func updateDates(_ dates: [Date]) {
        guard var draft = draft.value else { return }
        let unique = Array(Set(dates.map { Calendar.current.startOfDay(for: $0) })).sorted()
        guard let first = unique.first else { return }
        draft.date = first
        draft.logDates = unique
        updateDraft(draft)
    }

    func selectMeal(_ mealType: MealType) {
        guard var draft = draft.value else { return }
        draft.mealType = mealType
        updateDraft(draft)
    }

    func incrementServings() {
        guard var draft = draft.value else { return }
        draft.servings = min(99, draft.servings + 1)
        updateDraft(draft)
    }

    func decrementServings() {
        guard var draft = draft.value, draft.servings > 1 else { return }
        draft.servings = draft.servings - 1
        updateDraft(draft)
    }

    func commitPortion(_ text: String) {
        guard var draft = draft.value,
              let parsed = ProductDetailsMath.parsePortion(
                text,
                defaultIsMilliliters: (draft.portionMilliliters ?? 0) > 0
              ) else {
            publish()
            return
        }
        draft = ProductDetailsMath.applyingLoggedPortion(
            draft,
            value: parsed.value,
            isMilliliters: parsed.isMilliliters
        )
        updateDraft(draft)
        if needsNutritionRecalculation { recalculateNutrition() }
    }

    func commitIngredient(id: UUID, text: String) {
        guard var draft = draft.value, let original = draft.ingredients.first(where: { $0.id == id }) else { return }
        let previousIngredients = draft.ingredients
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != ProductDetailsMath.formatIngredient(original) else { return }
        if trimmed.isEmpty {
            guard draft.ingredients.count > 1 else {
                errorText.value = L10n.tr("product.entry.keepIngredient")
                publish()
                return
            }
            draft = ProductDetailsMath.removingIngredient(id: id, from: draft)
        } else {
            guard var parsed = ProductDetailsMath.parseIngredientLine(trimmed) else { return }
            parsed.id = id
            draft = ProductDetailsMath.replacingIngredient(parsed, in: draft)
        }
        guard draft.ingredients != previousIngredients else { return }
        needsNutritionRecalculation = true
        updateDraft(draft)
        recalculateNutrition()
    }

    func addEntryTapped() {
        guard !isRecalculatingNutrition.value else { return }
        if needsNutritionRecalculation {
            recalculateNutrition()
            return
        }
        guard let draft = draft.value else { return }
        do {
            if let stageEntries {
                try stageEntries(draft.toFoodEntries())
            } else {
                for entry in draft.toFoodEntries() {
                    _ = try logFoodUseCase.execute(entry)
                }
            }
            addedAlertText.value = stageEntries != nil ? L10n.tr("editMeal.addedToDraft")
                : L10n.format("product.entry.addedTo", draft.mealType.localizedTitle)
            showsAddedAlert.value = true
        } catch {
            errorText.value = error.localizedDescription
            Analytics.tracker.track(.foodLogFailed(method: draft.source))
        }
    }

    func addedAlertOKTapped() {
        showsAddedAlert.value = false
        onFinished?()
    }

    var mealTypes: [MealType] { [.breakfast, .lunch, .snacks, .dinner] }

    private func recalculateNutrition() {
        guard let snapshot = draft.value else { return }
        recalculationTask?.cancel()
        let requestID = UUID()
        recalculationID = requestID
        errorText.value = ""
        isRecalculatingNutrition.value = true
        publish()
        let ingredientList = snapshot.ingredients.map(ProductDetailsMath.formatIngredient).joined(separator: "\n")
        let prompt = """
        Recalculate nutrition for exactly ONE serving of this edited dish: \(snapshot.name).
        The complete current ingredient list for this one serving is:
        \(ingredientList)
        Use only these ingredients, with exactly the listed quantities. Do not restore removed ingredients.
        Estimate all nutrition values for this one serving, not per 100 g and not for multiple servings.
        The recorded finished portion is \(ProductDetailsMath.formatPortion(grams: snapshot.portionGrams, milliliters: snapshot.portionMilliliters)).
        If an ingredient or quantity cannot be understood, do not invent nutrition; return confidence 0 and explain what needs clarification.
        """
        let analyze = analyzeIngredients
        recalculationTask = Task { @MainActor [weak self] in
            do {
                guard let analyze else { throw FoodPhotoAnalysisError.invalidResponse }
                let result = try await analyze(prompt, snapshot.mealType)
                try Task.checkCancellation()
                guard let self, self.recalculationID == requestID, var current = self.draft.value else { return }
                let nutrients = [result.calories, result.protein, result.carbs, result.fats, result.fiber, result.sugar, result.sodium]
                guard result.confidence.isFinite, result.confidence > 0 else {
                    let clarification = result.assistantMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clarification.isEmpty { throw IngredientClarification(message: clarification) }
                    throw FoodPhotoAnalysisError.invalidResponse
                }
                guard nutrients.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
                    throw FoodPhotoAnalysisError.invalidResponse
                }
                current.calories = result.calories
                current.protein = result.protein
                current.carbs = result.carbs
                current.fats = result.fats
                current.fiber = result.fiber
                current.sugar = result.sugar
                current.sodium = result.sodium
                self.needsNutritionRecalculation = false
                self.isRecalculatingNutrition.value = false
                self.recalculationTask = nil
                self.updateDraft(current)
            } catch {
                guard let self, self.recalculationID == requestID else { return }
                self.isRecalculatingNutrition.value = false
                self.recalculationTask = nil
                self.errorText.value = (error as? IngredientClarification)?.message
                    ?? L10n.tr("product.entry.nutritionRecalculationFailed")
                self.publish()
            }
        }
    }

    private func publish() {
        guard let draft = draft.value else { return }
        nameText.value = draft.name
        subtitleText.value = ProductDetailsMath.subtitle(for: draft)
        portionText.value = ProductDetailsMath.loggedPortionText(for: draft)
        canEditPortion.value = (draft.portionGrams ?? 0) > 0 || (draft.portionMilliliters ?? 0) > 0
        servingsText.value = "\(draft.servings)"
        canDecrementServings.value = draft.servings > 1
        canIncrementServings.value = draft.servings < 99
        dateText.value = "  \(Self.dateBadgeText(draft.date))  "
        nutritionHeaderText.value = isRecalculatingNutrition.value
            ? L10n.tr("product.entry.recalculating")
            : draft.servings == 1
            ? L10n.format("product.entry.nutritionSummaryOne", draft.servings)
            : L10n.format("product.entry.nutritionSummaryMany", draft.servings)
        caloriesText.value = needsNutritionRecalculation ? "—" : "\(Int(draft.loggedCalories.rounded()))"
        proteinText.value = needsNutritionRecalculation ? "—" : ProductDetailsMath.formatGrams(draft.loggedProtein)
        fatText.value = needsNutritionRecalculation ? "—" : ProductDetailsMath.formatGrams(draft.loggedFats)
        carbsText.value = needsNutritionRecalculation ? "—" : ProductDetailsMath.formatGrams(draft.loggedCarbs)
        canAddEntry.value = !isRecalculatingNutrition.value
        addButtonTitle.value = L10n.tr(isRecalculatingNutrition.value
            ? "product.entry.recalculating"
            : needsNutritionRecalculation ? "product.entry.retryNutrition" : "product.entry.add")
        ingredients.value = draft.ingredients
        selectedMeal.value = draft.mealType
        loadHeroImage(from: draft)
    }

    private func loadHeroImage(from draft: ProductDetailsDraft) {
        if let data = draft.imageData, let image = StoredPhoto.image(from: data, maxPixelSize: StoredPhoto.maxDimension) {
            loadedHeroKey = "data"
            heroImage.value = image
            return
        }
        guard let url = draft.imageURL else {
            loadedHeroKey = nil
            heroImage.value = nil
            return
        }
        let key = url.absoluteString
        if loadedHeroKey == key, heroImage.value != nil { return }
        loadedHeroKey = key
        if let cached = RemoteImageLoader.shared.cached(url) {
            heroImage.value = cached
            return
        }
        heroImage.value = nil
        Task { @MainActor [weak self] in
            guard let image = await RemoteImageLoader.shared.fetch(url) else { return }
            guard self?.loadedHeroKey == key else { return }
            self?.heroImage.value = image
        }
    }

    private static func dateBadgeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        let day = formatter.string(from: date)
        if Calendar.current.isDateInToday(date) {
            return L10n.format("product.entry.todayDate", day)
        }
        return day
    }
}
