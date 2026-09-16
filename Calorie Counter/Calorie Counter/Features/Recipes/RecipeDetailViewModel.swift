import Foundation
import UIKit

struct RecipeMetaChip: Equatable {
    var symbol: String
    var title: String
}

enum RecipeDetailTab: Equatable {
    case nutrition
    case ingredients
    case instructions
}

final class RecipeDetailViewModel {
    let navTitle = Observable(L10n.tr("recipes.generic"))
    let nameText = Observable("")
    let subtitleText = Observable("")
    let chips = Observable<[RecipeMetaChip]>([])
    let selectedTab = Observable(RecipeDetailTab.nutrition)
    let scoreGradeText = Observable("")
    let scoreTitleText = Observable("")
    let scoreSummaryText = Observable("")
    let calorieShareTitleText = Observable(L10n.tr("recipes.details.calorieShareTitle"))
    let calorieShareBodyText = Observable("")
    let calorieShareProgress = Observable(CGFloat(0))
    let calorieSharePercentText = Observable("")
    let nutritionHeaderText = Observable(L10n.tr("product.details.nutritionFacts"))
    let nutritionRows = Observable<[ProductNutritionRow]>([])
    let ingredients = Observable<[FoodIngredient]>([])
    let steps = Observable<[String]>([])
    let isLoading = Observable(false)
    let isDetailsLoading = Observable(false)
    let isDetailsReady = Observable(false)
    let detailsUnavailable = Observable(false)
    let isSaved = Observable(false)
    let savedAlertVisible = Observable(false)
    let heroImage = Observable<UIImage?>(nil)
    let pendingConfirmText = Observable<String?>(nil)
    let isSharePreparing = Observable(false)

    var onDetailsUnavailable: (() -> Void)?
    var isResolvingPreparedDish: Bool { recipe.catalogFoodID != nil }

    func retryDetails() { Task { @MainActor in await loadDetailsIfNeeded() } }

    var onBack: (() -> Void)?
    var onShare: ((UIImage) -> Void)?
    var onAddToDiary: ((ProductDetailsDraft) -> Void)?
    var onShowScoreInfo: ((String, String) -> Void)?
    var onRequestIngredientSwapChat: ((Recipe, String) -> Void)?

    let showsAddToDiary: Bool
    let addButtonTitle: String

    private(set) var recipe: Recipe
    private let searchRecipesUseCase: SearchRecipesUseCase
    private let recipeRepository: RecipeRepositoryProtocol
    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let imageLoader: RemoteImageLoader
    private let loggingContext: ProductDetailsDraft?
    private let startedAsCatalogFood: Bool
    private var pendingSwap: RecipeIngredientSwapProposal?
    private var calorieGoal = UserGoals.default.calorieTarget
    private var detailsTask: Task<Recipe?, Never>?
    private var isSharing = false
    private var isSaving = false
    private var isAdding = false
    private var didLoadFullDetails = false
    private var replacedInitialRecipe = false

    private var canUseRecipe: Bool {
        !isResolvingPreparedDish
            && SearchRecipesUseCase.hasCompleteDetails(recipe)
            && (!SearchRecipesUseCase.hasCatalogRecipeIdentity(recipe) || didLoadFullDetails)
    }

    init(
        recipe: Recipe,
        searchRecipesUseCase: SearchRecipesUseCase,
        recipeRepository: RecipeRepositoryProtocol,
        aiAssistantService _: AIAssistantServiceProtocol,
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        showsAddToDiary: Bool = true,
        loggingContext: ProductDetailsDraft? = nil,
        addButtonTitle: String? = nil,
        imageLoader: RemoteImageLoader = .shared
    ) {
        self.recipe = recipe
        self.searchRecipesUseCase = searchRecipesUseCase
        self.recipeRepository = recipeRepository
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.showsAddToDiary = showsAddToDiary
        self.addButtonTitle = addButtonTitle ?? L10n.tr("product.details.addToDiary")
        self.loggingContext = loggingContext
        self.startedAsCatalogFood = recipe.catalogFoodID != nil
        self.imageLoader = imageLoader
        heroImage.value = loggingContext?.imageData.flatMap(UIImage.init(data:))
        publish()
        refreshSavedState()
    }

    func viewDidLoad() {
        calorieGoal = (try? fetchDailyDiaryUseCase.execute())?.goals.calorieTarget ?? UserGoals.default.calorieTarget
        publish()
        loadHeroImage()
        Task { @MainActor in
            await loadDetailsIfNeeded()
        }
    }

    func backTapped() {
        detailsTask?.cancel()
        onBack?()
    }

    func shareTapped() {
        guard !isSharing else { return }
        isSharing = true
        Task { @MainActor in
            defer { isSharing = false }
            let needsDetails = !canUseRecipe
            let needsPhoto = heroImage.value == nil
            if needsDetails || needsPhoto {
                isSharePreparing.value = true
            }
            await loadDetailsIfNeeded()
            guard canUseRecipe else { isSharePreparing.value = false; return }
            await ensureHeroImage()
            let image = RecipeShareCardRenderer.render(
                title: nameText.value,
                photo: heroImage.value,
                chips: chips.value,
                ingredients: ingredients.value,
                steps: steps.value
            )
            isSharePreparing.value = false
            guard let image else { return }
            onShare?(image)
        }
    }

    func selectTab(_ tab: RecipeDetailTab) {
        selectedTab.value = tab
    }

    func scoreInfoTapped() {
        onShowScoreInfo?(
            L10n.tr("product.details.scoreInfoTitle"),
            L10n.tr("product.details.scoreInfoBody")
        )
    }

    func addToDiaryTapped() {
        guard !isAdding else { return }
        isAdding = true
        Task { @MainActor in
            defer { isAdding = false }
            await loadDetailsIfNeeded()
            guard canUseRecipe else { return }
            var draft = ProductDetailsMath.fillingDefaultPortion(currentDraft())
            draft.servings = 1
            onAddToDiary?(draft)
        }
    }

    func saveTapped() {
        guard !isSaving else { return }
        if canUseRecipe {
            persistSavedState()
            return
        }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            await loadDetailsIfNeeded()
            guard canUseRecipe else { return }
            persistSavedState()
        }
    }

    private func persistSavedState() {
        do {
            if isSaved.value {
                try recipeRepository.deleteSaved(recipe)
                isSaved.value = false
            } else {
                try recipeRepository.save(recipe)
                adoptPersistedIdentity()
                isSaved.value = true
                savedAlertVisible.value = true
            }
        } catch {
        }
    }

    func dismissSavedAlert() {
        savedAlertVisible.value = false
    }

    func applyIngredientSwapProposal(_ proposal: RecipeIngredientSwapProposal) {
        pendingSwap = proposal
        let message = [
            L10n.format("recipes.replaceConfirm", proposal.originalName, proposal.replacementName),
            proposal.reason,
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
        pendingConfirmText.value = message
    }

    func rejectPendingSwap() {
        pendingSwap = nil
        pendingConfirmText.value = nil
    }

    func confirmPendingSwap() {
        guard let proposal = pendingSwap else { return }
        pendingConfirmText.value = nil
        recipe = ApplyRecipeIngredientSwapUseCase.execute(recipe: recipe, proposal: proposal)
        pendingSwap = nil
        publish()
    }

    private func refreshSavedState() {
        isSaved.value = (try? recipeRepository.isSaved(recipe)) ?? false
        if isSaved.value {
            adoptPersistedIdentity()
        }
    }

    private func adoptPersistedIdentity() {
        guard let externalId = recipe.externalId, !externalId.isEmpty,
              let stored = try? recipeRepository.fetchSaved(externalId: externalId) else { return }
        recipe.id = stored.id
    }

    private func publish() {
        nameText.value = recipe.title
        var draft = currentDraft()
        // Nutrition and ingredient quantities are normalized to one serving.
        draft.servings = 1
        subtitleText.value = ProductDetailsMath.recipeDetailSubtitle(for: draft)
        isDetailsReady.value = canUseRecipe
        guard canUseRecipe else {
            chips.value = []
            scoreGradeText.value = ""
            scoreTitleText.value = ""
            scoreSummaryText.value = ""
            calorieShareBodyText.value = ""
            calorieSharePercentText.value = ""
            calorieShareProgress.value = 0
            nutritionRows.value = []
            ingredients.value = []
            steps.value = []
            return
        }
        var nextChips: [RecipeMetaChip] = []
        if let minutes = recipe.readyInMinutes {
            nextChips.append(RecipeMetaChip(symbol: "clock", title: L10n.format("recipes.min", minutes)))
        }
        if recipe.calories != nil {
            let calories = draft.calories
            nextChips.append(RecipeMetaChip(symbol: "flame", title: L10n.format("recipes.kcal", Int(calories.rounded()))))
        }
        if recipe.origin.isAIRecipe {
            nextChips.append(RecipeMetaChip(symbol: "sparkles", title: L10n.tr("recipes.details.aiRecipe")))
        }
        chips.value = nextChips
        let facts = draft.nutritionFacts
        scoreGradeText.value = facts.grade.rawValue
        scoreTitleText.value = L10n.format("photo.result.healthScore", facts.score)
        scoreSummaryText.value = facts.summary
        let sample = (calories: draft.calories, protein: draft.protein, carbs: draft.carbs, fats: draft.fats)
        let portionDailyValue = NutritionFactsCalculator.facts(
            calories: draft.calories, protein: draft.protein, carbs: draft.carbs, fats: draft.fats,
            fiber: draft.fiber, sugar: draft.sugar, sodium: draft.sodium
        ).dailyValue
        let percent = calorieGoal > 0 ? max(0, (sample.calories / calorieGoal) * 100) : 0
        calorieShareProgress.value = CGFloat(min(100, percent) / 100)
        calorieSharePercentText.value = "\(Int(percent.rounded()))%"
        calorieShareBodyText.value = L10n.format(
            "recipes.details.calorieShareBody",
            Int(percent.rounded()),
            Self.grouped(calorieGoal)
        )
        nutritionRows.value = [
            ProductNutritionRow(
                title: L10n.tr("photo.result.calories"),
                value: ProductDetailsMath.formatCalories(sample.calories),
                dailyValue: ProductDetailsMath.formatDailyValue(portionDailyValue.calories)
            ),
            ProductNutritionRow(
                title: L10n.tr("home.protein"),
                value: ProductDetailsMath.formatGrams(sample.protein),
                dailyValue: ProductDetailsMath.formatDailyValue(portionDailyValue.protein)
            ),
            ProductNutritionRow(
                title: L10n.tr("photo.result.fat"),
                value: ProductDetailsMath.formatGrams(sample.fats),
                dailyValue: ProductDetailsMath.formatDailyValue(portionDailyValue.fat)
            ),
            ProductNutritionRow(
                title: L10n.tr("home.carbs"),
                value: ProductDetailsMath.formatGrams(sample.carbs),
                dailyValue: ProductDetailsMath.formatDailyValue(portionDailyValue.carbs)
            )
        ]
        ingredients.value = draft.ingredients
        steps.value = recipe.steps
    }

    private func currentDraft() -> ProductDetailsDraft {
        var draft = ProductDetailsMath.draft(from: recipe)
        guard let loggingContext else { return draft }
        draft.mealType = loggingContext.mealType
        draft.date = loggingContext.date
        draft.logDates = loggingContext.logDates
        let keepsOriginalContext = !startedAsCatalogFood && !replacedInitialRecipe
        if keepsOriginalContext {
            draft.imageData = loggingContext.imageData
            draft.fiber = loggingContext.fiber
            draft.sugar = loggingContext.sugar
            draft.sodium = loggingContext.sodium
        }
        if keepsOriginalContext, recipe.weightGrams == nil, recipe.volumeMilliliters == nil,
           let milliliters = loggingContext.portionMilliliters {
            draft.portionGrams = nil
            draft.portionMilliliters = milliliters
        }
        return draft
    }

    private func loadDetailsIfNeeded() async {
        if let detailsTask {
            // The owner publishes the result and failure state before a waiting action resumes.
            _ = await detailsTask.value
            return
        }
        guard !canUseRecipe else { return }
        detailsUnavailable.value = false
        isDetailsLoading.value = true
        let current = recipe
        let task = Task<Recipe?, Never> { @MainActor in
            defer { self.detailsTask = nil }
            do {
                let details = try await self.searchRecipesUseCase.details(for: current)
                guard !Task.isCancelled else { self.isDetailsLoading.value = false; return nil }
                guard details.catalogFoodID == nil,
                      SearchRecipesUseCase.hasCompleteDetails(details) else {
                    self.finishDetailsFailure()
                    return nil
                }
                self.applyDetailedRecipe(details)
                self.isDetailsLoading.value = false
                return details
            } catch {
                if Task.isCancelled { self.isDetailsLoading.value = false }
                else { self.finishDetailsFailure() }
                return nil
            }
        }
        detailsTask = task
        _ = await task.value
    }

    private func finishDetailsFailure() {
        isDetailsLoading.value = false
        detailsUnavailable.value = true
        isDetailsReady.value = false
        onDetailsUnavailable?()
    }

    private func applyDetailedRecipe(_ details: Recipe) {
        if recipe.externalId != details.externalId || recipe.origin != details.origin {
            replacedInitialRecipe = true
            heroImage.value = nil
        }
        recipe = details
        didLoadFullDetails = true
        detailsUnavailable.value = false
        publish()
        refreshSavedState()
        loadHeroImage()
    }

    private func loadHeroImage() {
        Task { @MainActor [weak self] in
            await self?.ensureHeroImage(forceReload: true)
        }
    }

    private func ensureHeroImage(forceReload: Bool = false) async {
        let keepsOriginalContext = !startedAsCatalogFood && !replacedInitialRecipe
        if keepsOriginalContext, let imageData = loggingContext?.imageData, let image = UIImage(data: imageData) {
            heroImage.value = image
            return
        }
        if heroImage.value != nil && !forceReload { return }
        let current = recipe
        let fallback = AIAssistantAPIConfiguration.production.foodImageURL(name: current.title)
        guard let image = await imageLoader.fetch(current.imageURL, fallbackURL: fallback) else { return }
        guard recipe.id == current.id, recipe.title == current.title, recipe.imageURL == current.imageURL else { return }
        heroImage.value = image
    }

    private static func grouped(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }
}
