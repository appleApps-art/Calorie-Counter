import Foundation
import UIKit

struct ProductNutritionRow: Equatable {
    var title: String
    var value: String
    var dailyValue: String?
}

final class ProductDetailsViewModel {
    let draft = Observable<ProductDetailsDraft?>(nil)
    let nameText = Observable("")
    let subtitleText = Observable("")
    let scoreGradeText = Observable("")
    let scoreTitleText = Observable("")
    let scoreSummaryText = Observable("")
    let nutritionHeaderText = Observable("")
    let nutritionRows = Observable<[ProductNutritionRow]>([])
    let tags = Observable<[String]>([])
    let ingredients = Observable<[FoodIngredient]>([])
    let recipeSteps = Observable<[String]>([])
    let suggestionVisible = Observable(false)
    let canAddSuggestion = Observable(false)
    let relatedRecipe = Observable<Recipe?>(nil)
    let relatedRecipeLoading = Observable(false)
    let relatedRecipeUnavailable = Observable(false)
    let wantToCookVisible = Observable(false)
    let isLoading = Observable(false)
    let suggestionNameText = Observable("")
    let suggestionSummaryText = Observable("")
    let suggestionScoreText = Observable("")
    let heroImage = Observable<UIImage?>(nil)
    let showsAddToDiary = Observable(true)
    let addButtonTitle = Observable(L10n.tr("product.details.addToDiary"))

    var onBack: (() -> Void)?
    var onShare: ((String, UIImage?) -> Void)?
    var onAddToDiary: ((ProductDetailsDraft) -> Void)?
    var onShowScoreInfo: ((String, String) -> Void)?
    var onOpenRecipe: ((ProductDetailsDraft) -> Void)?

    private let searchFoodProductsUseCase: SearchFoodProductsUseCase?
    private var detailsTaskID = UUID()
    private let diaryProvider: ((Date) throws -> DailyDiarySummary)?
    private let relatedRecipeLoader: ((String) async throws -> [Recipe])?
    private var recipeTask: Task<Void, Never>?
    private var recipeTaskID = UUID()

    init(
        searchFoodProductsUseCase: SearchFoodProductsUseCase? = nil,
        diaryProvider: ((Date) throws -> DailyDiarySummary)? = nil,
        relatedRecipeLoader: ((String) async throws -> [Recipe])? = nil
    ) {
        self.searchFoodProductsUseCase = searchFoodProductsUseCase
        self.diaryProvider = diaryProvider
        self.relatedRecipeLoader = relatedRecipeLoader
    }

    deinit { recipeTask?.cancel() }

    func refreshInsights() {
        publish()
    }

    func configure(
        _ value: ProductDetailsDraft,
        showsAddToDiary: Bool = true,
        addButtonTitle: String? = nil
    ) {
        self.showsAddToDiary.value = showsAddToDiary
        let title = addButtonTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.addButtonTitle.value = title.isEmpty
            ? L10n.tr("product.details.addToDiary")
            : title
        detailsTaskID = UUID()
        recipeTask?.cancel()
        recipeTaskID = UUID()
        relatedRecipe.value = nil
        relatedRecipeLoading.value = false
        draft.value = value
        publish()
        loadHeroImage()
        loadLocalizedDetailsIfNeeded()
        loadRelatedRecipe()
    }

    func backTapped() {
        onBack?()
    }

    func shareTapped() {
        guard let draft = draft.value else { return }
        onShare?(shareText(for: draft), heroImage.value)
    }

    func addToDiaryTapped() {
        guard let draft = draft.value else { return }
        onAddToDiary?(draft)
    }

    func scoreInfoTapped() {
        onShowScoreInfo?(
            L10n.tr("product.details.scoreInfoTitle"),
            L10n.tr("product.details.scoreInfoBody")
        )
    }

    func addSuggestionTapped() {
        detailsTaskID = UUID()
        isLoading.value = false
        guard let draft = draft.value, let suggestion = draft.suggestion else { return }
        self.draft.value = ProductDetailsMath.applyingSuggestion(suggestion, to: draft)
        publish()
        loadHeroImage()
        loadRelatedRecipe()
    }

    func wantToCookTapped() {
        guard let draft = draft.value else { return }
        guard let recipe = relatedRecipe.value else {
            loadRelatedRecipe()
            return
        }
        var recipeDraft = ProductDetailsMath.draft(from: recipe, mealType: draft.mealType, date: draft.date)
        recipeDraft.servings = 1
        recipeDraft.logDates = draft.logDates
        onOpenRecipe?(recipeDraft)
    }

    private func loadRelatedRecipe() {
        guard let loader = relatedRecipeLoader, let draft = draft.value else { return }
        recipeTask?.cancel()
        let token = UUID()
        recipeTaskID = token
        relatedRecipe.value = nil
        relatedRecipeUnavailable.value = false
        relatedRecipeLoading.value = true
        let remaining = (try? diaryProvider?(draft.date))?.remainingCalories
        recipeTask = Task { @MainActor [weak self] in
            let recipes = (try? await loader(draft.name)) ?? []
            guard !Task.isCancelled, let self, self.recipeTaskID == token else { return }
            // Prefer a serving that fits the remaining budget; never invent nutrition or a recipe.
            let fitting = recipes.filter { recipe in
                guard let remaining, remaining > 0, let calories = recipe.calories, calories > 0 else { return false }
                return calories <= remaining
            }
            self.relatedRecipe.value = fitting.first ?? recipes.first
            self.relatedRecipeLoading.value = false
            self.relatedRecipeUnavailable.value = self.relatedRecipe.value == nil
        }
    }

    private func loadLocalizedDetailsIfNeeded() {
        guard let searchFoodProductsUseCase, let draft = draft.value else { return }
        let loadCatalog = Self.shouldLoadCatalogDetails(draft)
        let loadAI = Self.shouldLoadAIDetails(draft)
        guard loadCatalog || loadAI else { return }
        let id = draft.catalogExternalId
        let kind = draft.catalogKind
        let title = draft.name
        let imageURL = draft.imageURL
        let source = draft.source
        let token = UUID()
        detailsTaskID = token
        isLoading.value = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.detailsTaskID == token {
                    self.isLoading.value = false
                }
            }
            var product: FoodProduct?
            if loadCatalog, let id {
                switch kind {
                case .ingredient:
                    product = try? await searchFoodProductsUseCase.ingredientDetails(id: id)
                case .recipe:
                    product = try? await searchFoodProductsUseCase.recipeDetails(id: id)
                case .product, .none:
                    product = try? await searchFoodProductsUseCase.productDetails(id: id)
                }
            }
            if product == nil, loadAI {
                let enrichKind = kind?.rawValue
                    ?? (FoodProductSource(apiValue: source).isAIRecipe
                        ? FoodProductKind.recipe.rawValue
                        : FoodProductKind.product.rawValue)
                product = try? await searchFoodProductsUseCase.enrichDetails(
                    title: title,
                    imageURL: imageURL,
                    source: source,
                    kind: enrichKind
                )
            }
            guard self.detailsTaskID == token, let product else { return }
            guard var current = self.draft.value else { return }
            let previousImage = current.imageURL
            current = Self.merging(localized: product, into: current)
            self.draft.value = current
            self.publish()
            if current.imageURL != previousImage {
                self.loadHeroImage()
            }
        }
    }

    private static func shouldLoadCatalogDetails(_ draft: ProductDetailsDraft) -> Bool {
        guard let id = draft.catalogExternalId, !id.isEmpty, id.allSatisfy(\.isNumber) else {
            return false
        }
        let source = FoodProductSource(apiValue: draft.source)
        if source == .openFoodFacts {
            return draft.catalogKind != .recipe
        }
        guard source == .spoonacular else { return false }
        return true
    }

    private static func shouldLoadAIDetails(_ draft: ProductDetailsDraft) -> Bool {
        if draft.catalogKind == .recipe {
            return FoodProductSource(apiValue: draft.source).isAIRecipe
        }
        if FoodProductSource(apiValue: draft.source).isAIRecipe {
            return true
        }
        return draft.calories <= 0
    }

    private static func merging(localized product: FoodProduct, into draft: ProductDetailsDraft) -> ProductDetailsDraft {
        var next = draft
        let serving = product.servingSizeLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !serving.isEmpty {
            next.servingLabel = serving
        }
        if next.catalogKind == nil {
            next.catalogKind = product.kind
        }
        let isRecipe = next.catalogKind == .recipe
        let ingredients = product.ingredients.compactMap(ProductDetailsMath.parseIngredientLine)
        if !ingredients.isEmpty {
            next.ingredients = ingredients
        }
        if isRecipe {
            let steps = product.steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !steps.isEmpty {
                next.recipeSteps = steps
            }
        } else {
            next.recipeSteps = []
        }
        if let calories = product.calories, calories > 0 {
            next.calories = calories
        }
        if let protein = product.protein { next.protein = protein }
        if let carbs = product.carbs { next.carbs = carbs }
        if let fats = product.fats { next.fats = fats }
        if let fiber = product.fiber { next.fiber = fiber }
        if let sugar = product.sugar { next.sugar = sugar }
        if let sodium = product.sodium { next.sodium = sodium }
        if let imageURL = product.imageURL {
            next.imageURL = imageURL
        }
        return next
    }

    private func publish() {
        guard let draft = draft.value else { return }
        nameText.value = draft.name
        subtitleText.value = ProductDetailsMath.subtitle(for: draft)
        let facts = draft.nutritionFacts
        scoreGradeText.value = facts.grade.rawValue
        scoreTitleText.value = L10n.format("photo.result.healthScore", facts.score)
        scoreSummaryText.value = facts.summary
        if draft.portionGrams != nil {
            nutritionHeaderText.value = L10n.tr("product.details.nutritionFactsPer100g")
        } else {
            nutritionHeaderText.value = L10n.tr("product.details.nutritionFacts")
        }
        let sample = draft.perReferenceNutrition
        nutritionRows.value = [
            ProductNutritionRow(title: L10n.tr("photo.result.calories"), value: ProductDetailsMath.formatCalories(sample.calories), dailyValue: ProductDetailsMath.formatDailyValue(facts.dailyValue.calories)),
            ProductNutritionRow(title: L10n.tr("home.protein"), value: ProductDetailsMath.formatGrams(sample.protein), dailyValue: ProductDetailsMath.formatDailyValue(facts.dailyValue.protein)),
            ProductNutritionRow(title: L10n.tr("photo.result.fat"), value: ProductDetailsMath.formatGrams(sample.fats), dailyValue: ProductDetailsMath.formatDailyValue(facts.dailyValue.fat)),
            ProductNutritionRow(title: L10n.tr("home.carbs"), value: ProductDetailsMath.formatGrams(sample.carbs), dailyValue: ProductDetailsMath.formatDailyValue(facts.dailyValue.carbs)),
            ProductNutritionRow(title: L10n.tr("home.fiber"), value: ProductDetailsMath.formatGrams(sample.fiber), dailyValue: ProductDetailsMath.formatDailyValue(facts.dailyValue.fiber)),
            ProductNutritionRow(title: L10n.tr("home.sugar"), value: ProductDetailsMath.formatGrams(sample.sugar), dailyValue: ProductDetailsMath.formatDailyValue(facts.dailyValue.sugar)),
            ProductNutritionRow(title: L10n.tr("home.sodium"), value: L10n.format("photo.result.mgValue", Int(sample.sodium.rounded())), dailyValue: ProductDetailsMath.formatDailyValue(facts.dailyValue.sodium))
        ]
        tags.value = ProductDetailsMath.displayTags(for: draft)
        ingredients.value = []
        recipeSteps.value = []
        wantToCookVisible.value = relatedRecipeLoader != nil
        canAddSuggestion.value = showsAddToDiary.value && draft.suggestion != nil
        if let suggestion = draft.suggestion {
            suggestionVisible.value = true
            suggestionNameText.value = suggestion.name
            suggestionSummaryText.value = suggestion.summary + " " + Self.wellnessSummary(
                for: ProductDetailsMath.applyingSuggestion(suggestion, to: draft),
                diary: try? diaryProvider?(draft.date)
            )
            let score = NutritionFactsCalculator.facts(
                calories: suggestion.calories,
                protein: suggestion.protein,
                carbs: suggestion.carbs,
                fats: suggestion.fats,
                fiber: suggestion.fiber,
                sugar: suggestion.sugar,
                sodium: suggestion.sodium
            ).score
            suggestionScoreText.value = "\(score)"
        } else {
            suggestionVisible.value = true
            suggestionNameText.value = draft.name
            suggestionScoreText.value = "\(facts.score)"
            suggestionSummaryText.value = Self.wellnessSummary(
                for: draft, diary: try? diaryProvider?(draft.date)
            )
        }
    }

    static func wellnessSummary(for draft: ProductDetailsDraft, diary: DailyDiarySummary?) -> String {
        guard draft.loggedCalories.isFinite, draft.loggedCalories > 0 else {
            return L10n.tr("product.insight.missingNutrition")
        }
        let calories = Int(draft.loggedCalories.rounded())
        guard let diary, diary.goals.calorieTarget > 0 else {
            return L10n.format("product.insight.portion", calories, Int(draft.loggedProtein.rounded()))
                + " " + L10n.tr("product.insight.noDiary")
        }
        let remaining = diary.remainingCalories
        let after = remaining - draft.loggedCalories
        var lines = [L10n.format("product.insight.budget", calories, Int(max(0, remaining).rounded()))]
        if remaining <= 0 {
            lines.append(L10n.tr("product.insight.targetReached"))
        } else if after >= 0 {
            lines.append(L10n.format("product.insight.after", Int(after.rounded())))
        } else {
            lines.append(L10n.format("product.insight.over", Int((-after).rounded())))
        }
        if diary.remainingProtein > 0, draft.loggedProtein > 0 {
            lines.append(L10n.format("product.insight.protein", Int(draft.loggedProtein.rounded()),
                                    Int(max(0, diary.remainingProtein - draft.loggedProtein).rounded())))
        }
        return lines.joined(separator: " ")
    }

    private func loadHeroImage() {
        guard let draft = draft.value else {
            heroImage.value = nil
            return
        }
        if let data = draft.imageData, let image = UIImage(data: data) {
            heroImage.value = image
            return
        }
        heroImage.value = nil
        guard let url = draft.imageURL else { return }
        Task { @MainActor [weak self] in
            guard let image = await RemoteImageLoader.shared.fetch(url) else { return }
            guard self?.draft.value?.imageURL == url else { return }
            self?.heroImage.value = image
        }
    }

    private func shareText(for draft: ProductDetailsDraft) -> String {
        let facts = draft.nutritionFacts
        return [
            draft.name,
            ProductDetailsMath.subtitle(for: draft),
            L10n.format("photo.result.healthScore", facts.score),
            ProductDetailsMath.formatCalories(draft.calories)
        ].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
