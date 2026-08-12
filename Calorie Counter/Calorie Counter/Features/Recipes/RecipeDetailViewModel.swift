import Foundation

final class RecipeDetailViewModel {
    let titleText = Observable("")
    let summaryText = Observable("")
    let nutritionText = Observable("")
    let ingredientsText = Observable("")
    let stepsText = Observable("")
    let statusText = Observable("")
    let isLoading = Observable(false)
    let saveButtonTitle = Observable(L10n.tr("common.save"))
    let pendingConfirmText = Observable<String?>(nil)

    var onRequestIngredientSwapChat: ((Recipe, String) -> Void)?

    private(set) var recipe: Recipe
    private let searchRecipesUseCase: SearchRecipesUseCase
    private let recipeRepository: RecipeRepositoryProtocol
    private var pendingSwap: RecipeIngredientSwapProposal?

    init(
        recipe: Recipe,
        searchRecipesUseCase: SearchRecipesUseCase,
        recipeRepository: RecipeRepositoryProtocol,
        aiAssistantService: AIAssistantServiceProtocol,
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    ) {
        self.recipe = recipe
        self.searchRecipesUseCase = searchRecipesUseCase
        self.recipeRepository = recipeRepository
        publish()
    }

    func viewDidLoad() {
        refreshSaveState()
        guard let externalId = recipe.externalId, recipe.ingredients.isEmpty || recipe.steps.isEmpty else { return }
        isLoading.value = true
        statusText.value = L10n.tr("recipes.loadingDetails")
        Task { @MainActor in
            do {
                let detailed = try await searchRecipesUseCase.details(externalId: externalId)
                recipe = detailed
                publish()
                refreshSaveState()
                statusText.value = L10n.tr("common.ready")
            } catch {
                statusText.value = error.localizedDescription
            }
            isLoading.value = false
        }
    }

    func saveTapped() {
        do {
            try recipeRepository.save(recipe)
            saveButtonTitle.value = L10n.tr("common.saved")
            statusText.value = L10n.tr("recipes.recipeSaved")
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func replaceIngredientTapped() {
        let names = recipe.ingredients.map(\.name)
        let hint = names.first.map { L10n.format("recipes.replaceHint", $0) } ?? L10n.tr("recipes.replaceHintEmpty")
        onRequestIngredientSwapChat?(recipe, hint)
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
        statusText.value = L10n.tr("recipes.confirmSwap")
    }

    func rejectPendingSwap() {
        pendingSwap = nil
        pendingConfirmText.value = nil
        statusText.value = L10n.tr("recipes.swapCancelled")
    }

    func confirmPendingSwap() {
        guard let proposal = pendingSwap else { return }
        pendingConfirmText.value = nil
        recipe = ApplyRecipeIngredientSwapUseCase.execute(recipe: recipe, proposal: proposal)
        pendingSwap = nil
        publish()
        statusText.value = L10n.tr("recipes.swapApplied")
        saveButtonTitle.value = L10n.tr("common.save")
    }

    private func publish() {
        titleText.value = recipe.title
        summaryText.value = recipe.summary?.isEmpty == false ? (recipe.summary ?? "") : L10n.tr("recipes.noSummary")
        nutritionText.value = [
            recipe.calories.map { L10n.format("recipes.kcal", Int($0.rounded())) },
            recipe.protein.map { L10n.format("recipes.nutritionP", Int($0.rounded())) },
            recipe.carbs.map { L10n.format("recipes.nutritionC", Int($0.rounded())) },
            recipe.fats.map { L10n.format("recipes.nutritionF", Int($0.rounded())) },
            recipe.readyInMinutes.map { L10n.format("recipes.min", $0) },
        ].compactMap { $0 }.joined(separator: " · ")

        if recipe.ingredients.isEmpty {
            ingredientsText.value = L10n.tr("recipes.noIngredients")
        } else {
            ingredientsText.value = recipe.ingredients.map { ingredient in
                if let original = ingredient.originalText, !original.isEmpty {
                    return "• \(original)"
                }
                let amount = ingredient.amount.map { String(format: "%g", $0) } ?? ""
                let unit = ingredient.unit ?? ""
                return "• \(amount) \(unit) \(ingredient.name)".replacingOccurrences(of: "  ", with: " ")
            }.joined(separator: "\n")
        }

        if recipe.steps.isEmpty {
            stepsText.value = L10n.tr("recipes.noSteps")
        } else {
            stepsText.value = recipe.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n\n")
        }
    }

    private func refreshSaveState() {
        guard let externalId = recipe.externalId else {
            saveButtonTitle.value = L10n.tr("common.save")
            return
        }
        do {
            saveButtonTitle.value = try recipeRepository.isSaved(externalId: externalId) ? L10n.tr("common.saved") : L10n.tr("common.save")
        } catch {
            saveButtonTitle.value = L10n.tr("common.save")
        }
    }
}
