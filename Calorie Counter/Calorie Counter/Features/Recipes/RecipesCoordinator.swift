import UIKit

final class RecipesCoordinator {
    private let navigationController: UINavigationController
    private let container: DIContainer
    private weak var recipeDetailViewModel: RecipeDetailViewModel?
    private weak var recipesViewModel: RecipesViewModel?
    private weak var pantryViewModel: MyPantryViewModel?
    private weak var createFormViewModel: CreateRecipeFormViewModel?
    private weak var mealPlanViewModel: MealPlanPreviewViewModel?
    private lazy var foodLoggingCoordinator = FoodLoggingCoordinator(
        navigationController: navigationController,
        container: container
    )

    init(navigationController: UINavigationController, container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() -> UIViewController {
        let viewModel = RecipesViewModel(
            searchRecipesUseCase: container.searchRecipesUseCase,
            fetchBrowseSectionsUseCase: container.fetchRecipeBrowseSectionsUseCase,
            recipeRepository: container.recipeRepository,
            fetchMealPlansUseCase: container.fetchMealPlansUseCase,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
        )
        recipesViewModel = viewModel
        viewModel.onSelectRecipe = { [weak self, weak viewModel] recipe in
            let source: String
            if viewModel?.showsFilterResults.value == true {
                source = "search"
            } else if viewModel?.selectedTab.value == .saved {
                source = "saved"
            } else {
                source = "browse"
            }
            self?.showRecipeDetail(recipe, source: source)
        }
        viewModel.onSelectMealPlan = { [weak self] plan in
            self?.showMealPlanPreview(plan)
        }
        viewModel.onOpenSection = { [weak self] kind, title in
            self?.showSection(kind, title: title)
        }
        viewModel.onOpenPantry = { [weak self] in
            self?.showPantry()
        }
        viewModel.onOpenFilters = { [weak self] filters in
            self?.showFilters(filters)
        }
        viewModel.onOpenCreateSheet = { [weak self] in
            self?.presentCreateSheet()
        }
        viewModel.onCreateRecipe = { [weak self] in
            self?.showCreateForm(.recipe)
        }
        viewModel.onCreateMealPlan = { [weak self] in
            self?.showCreateForm(.mealPlan)
        }
        return RecipesViewController(viewModel: viewModel)
    }

    private func showSection(_ kind: RecipeBrowseSectionKind, title: String) {
        Analytics.tracker.track(.recipeSectionOpened(section: kind.rawValue))
        let viewModel = RecipeSectionViewModel(
            kind: kind,
            title: title,
            fetchBrowseSectionsUseCase: container.fetchRecipeBrowseSectionsUseCase
        )
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onSelectRecipe = { [weak self] recipe in
            self?.showRecipeDetail(recipe, source: "section")
        }
        navigationController.pushViewController(
            RecipeSectionViewController(viewModel: viewModel),
            animated: true
        )
    }

    private func presentCreateSheet() {
        let sheet = RecipesCreateSheetViewController { [weak self] action in
            switch action {
            case .recipe:
                self?.showCreateForm(.recipe)
            case .mealPlan:
                self?.showCreateForm(.mealPlan)
            }
        }
        navigationController.present(sheet, animated: true)
    }

    private func showCreateForm(_ kind: CreateRecipeFormKind) {
        let viewModel = CreateRecipeFormViewModel(
            kind: kind,
            fetchPantryItemsUseCase: container.fetchPantryItemsUseCase,
            createRecipeUseCase: container.createRecipeUseCase,
            createMealPlanUseCase: container.createMealPlanUseCase,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
        )
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onCreatedRecipe = { [weak self] recipe in
            self?.recipesViewModel?.reloadAfterCreate()
            self?.showRecipeDetail(recipe, source: "create", replacingCreateForm: true)
        }
        viewModel.onCreatedMealPlan = { [weak self] plan in
            self?.recipesViewModel?.reloadAfterMealPlanCreate()
            self?.showMealPlanPreview(plan, replacingCreateForm: true)
        }
        createFormViewModel = viewModel
        navigationController.pushViewController(
            CreateRecipeFormViewController(viewModel: viewModel),
            animated: true
        )
    }

    private func showFilters(_ filters: RecipeSearchFilters) {
        let viewModel = RecipeFiltersViewModel(
            filters: filters,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
        )
        let viewController = RecipeFiltersViewController(viewModel: viewModel)
        viewModel.onClose = { [weak viewController] in
            viewController?.dismiss(animated: true)
        }
        viewModel.onApply = { [weak self, weak viewController] filters in
            Analytics.tracker.track(.recipeFiltersApplied(count: filters.resultChips.count))
            viewController?.dismiss(animated: true)
            self?.recipesViewModel?.applyFilters(filters)
        }
        navigationController.present(viewController, animated: true)
    }

    private func showPantry() {
        let viewModel = MyPantryViewModel(
            fetchPantryItemsUseCase: container.fetchPantryItemsUseCase,
            savePantryItemUseCase: container.savePantryItemUseCase,
            deletePantryItemsUseCase: container.deletePantryItemsUseCase,
            suggestPantryRecipeUseCase: container.suggestPantryRecipeUseCase
        )
        pantryViewModel = viewModel
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onAdd = { [weak self] in
            self?.presentAddToPantry()
        }
        viewModel.onEdit = { [weak self] item in
            self?.presentPantryEdit(item) { saved in
                self?.pantryViewModel?.save(saved)
            }
        }
        viewModel.onOpenDetails = { [weak self] item in
            self?.openPantryProductDetails(
                ProductDetailsMath.draft(from: item),
                addsToPantry: false
            )
        }
        viewModel.onOpenRecipe = { [weak self] recipe in
            self?.showRecipeDetail(recipe, source: "pantry")
        }
        viewModel.onCreateRecipe = { [weak self] in
            self?.showCreateForm(.recipe)
        }
        navigationController.pushViewController(
            MyPantryViewController(viewModel: viewModel),
            animated: true
        )
    }

    private func presentAddToPantry() {
        let sheet = AddToPantrySheetViewController { [weak self] action in
            self?.handlePantryAdd(action)
        }
        navigationController.present(sheet, animated: true)
    }

    private func handlePantryAdd(_ action: HomeQuickLogAction) {
        switch action {
        case .scanFood:
            openFridgeCamera()
        case .scanBarcode:
            openPantryBarcode()
        case .search:
            openPantrySearch()
        case .voiceLog:
            openPantryVoice()
        }
    }

    private func openFridgeCamera() {
        let viewModel = FoodPhotoAnalysisViewModel(
            analyzeFoodPhotoUseCase: container.analyzeFoodPhotoUseCase,
            searchFoodProductsUseCase: container.searchFoodProductsUseCase,
            inventoryMode: true
        )
        viewModel.onClose = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onFridgeItemsReady = { [weak self] items in
            self?.showFridgeResult(items)
        }
        viewModel.onSwitchMode = { [weak self] action in
            guard let self else { return }
            self.navigationController.popViewController(animated: false)
            self.handlePantryAdd(action)
        }
        navigationController.pushViewController(
            AIPhotoCameraViewController(
                viewModel: viewModel,
                showsFreeScanQuota: !container.subscriptionService.currentStatus().isPremium
            ),
            animated: true
        )
    }

    private func showFridgeResult(_ items: [PantryItem]) {
        let existing = (try? container.fetchPantryItemsUseCase.execute()) ?? []
        let unique = PantryItem.excludingExisting(items, in: existing)
        guard !unique.isEmpty else {
            popToPantry()
            return
        }
        let viewModel = FridgePhotoResultViewModel(items: unique)
        let viewController = FridgePhotoResultViewController(viewModel: viewModel)
        viewModel.onBack = { [weak self] in
            self?.popToPantry()
        }
        viewModel.onEdit = { [weak self, weak viewModel] item in
            self?.presentPantryEdit(item) { saved in
                viewModel?.replace(saved)
            }
        }
        viewModel.onAdded = { [weak self] items in
            try? self?.container.savePantryItemUseCase.execute(items: items)
            Analytics.tracker.track(.pantryItemsAdded(count: items.count, method: "fridge_scan"))
            self?.popToPantry()
        }
        var stack = navigationController.viewControllers
        if stack.last is AIPhotoCameraViewController {
            stack.removeLast()
        }
        stack.append(viewController)
        navigationController.setViewControllers(stack, animated: true)
    }

    private func openPantryBarcode() {
        let viewModel = BarcodeFoodLoggingViewModel(
            lookupBarcodeProductUseCase: container.lookupBarcodeProductUseCase
        )
        viewModel.onClose = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onProductReady = { [weak self] draft in
            self?.openPantryProductDetails(draft, addsToPantry: true)
        }
        viewModel.onSwitchMode = { [weak self] action in
            self?.navigationController.popViewController(animated: false)
            self?.handlePantryAdd(action)
        }
        navigationController.pushViewController(
            BarcodeScannerViewController(
                viewModel: viewModel,
                showsFreeScanQuota: !container.subscriptionService.currentStatus().isPremium
            ),
            animated: true
        )
    }

    private func openPantrySearch() {
        let viewModel = FoodSearchViewModel(
            mealType: .snacks,
            date: Date(),
            searchFoodProductsUseCase: container.searchFoodProductsUseCase,
            fetchRecipeBrowseSectionsUseCase: container.fetchRecipeBrowseSectionsUseCase,
            fetchSavedFoodsUseCase: container.fetchSavedFoodsUseCase,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase,
            includeRecipes: false
        )
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onOpenDetails = { [weak self] draft in
            self?.openPantryProductDetails(draft, addsToPantry: true)
        }
        viewModel.onOpenCategory = { [weak self, weak viewModel] category in
            self?.openPantrySearchCategory(
                category,
                previewItems: viewModel?.browseSections.value.first { $0.category == category }?.items ?? []
            )
        }
        viewModel.onAskBity = { [weak self] query in
            self?.presentAssistant(initialInput: query)
        }
        navigationController.pushViewController(
            FoodSearchViewController(viewModel: viewModel),
            animated: true
        )
    }

    private func openPantrySearchCategory(
        _ category: FoodSearchCategory,
        previewItems: [FoodSearchItem] = []
    ) {
        let viewModel = FoodSearchCategoryViewModel(
            category: category,
            mealType: .snacks,
            date: Date(),
            searchFoodProductsUseCase: container.searchFoodProductsUseCase,
            fetchRecipeBrowseSectionsUseCase: container.fetchRecipeBrowseSectionsUseCase,
            previewItems: previewItems
        )
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onOpenDetails = { [weak self] draft in
            self?.openPantryProductDetails(draft, addsToPantry: true)
        }
        navigationController.pushViewController(
            FoodSearchCategoryViewController(viewModel: viewModel),
            animated: true
        )
    }

    private func openPantryVoice() {
        let viewModel = container.makeVoiceFoodLoggingViewModel()
        viewModel.onClose = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onViewDetails = { [weak self] draft in
            self?.openPantryProductDetails(draft, addsToPantry: true)
        }
        viewModel.onAddEntry = { [weak self] draft in
            self?.openPantryProductDetails(draft, addsToPantry: true)
        }
        navigationController.pushViewController(
            VoiceLogViewController(viewModel: viewModel),
            animated: true
        )
    }

    private func openPantryProductDetails(_ draft: ProductDetailsDraft, addsToPantry: Bool) {
        foodLoggingCoordinator.openProductDetails(
            draft,
            showsAddToDiary: true,
            addButtonTitle: addsToPantry ? L10n.tr("pantry.addTitle") : nil,
            routesDishesToRecipe: false,
            onAdd: addsToPantry
                ? { [weak self] draft in
                    self?.savePantryDraft(draft)
                }
                : nil
        )
    }

    private func savePantryDraft(_ draft: ProductDetailsDraft) {
        do {
            try container.savePantryItemUseCase.execute(PantryItem.from(draft: draft))
        } catch {
            // Silently doing nothing is what made the button look broken.
            let alert = UIAlertController(
                title: L10n.tr("pantry.saveFailed.title"),
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
            (navigationController.presentedViewController ?? navigationController).present(alert, animated: true)
            return
        }
        Analytics.tracker.track(.pantryItemsAdded(count: 1, method: draft.source))
        popToPantry()
    }

    private func presentPantryEdit(_ item: PantryItem, onSave: @escaping (PantryItem) -> Void) {
        let viewModel = PantryItemEditViewModel(item: item)
        let viewController = PantryItemEditViewController(viewModel: viewModel)
        viewModel.onClose = { [weak viewController] in
            viewController?.dismiss(animated: true)
        }
        viewModel.onSave = { [weak viewController] item in
            viewController?.dismiss(animated: true)
            onSave(item)
        }
        navigationController.present(viewController, animated: true)
    }

    private func popToPantry() {
        // A product opened over a sheet lives in a presented stack: popping alone would leave it up.
        navigationController.presentedViewController?.dismiss(animated: true)
        if let pantry = navigationController.viewControllers.first(where: { $0 is MyPantryViewController }) {
            navigationController.popToViewController(pantry, animated: true)
        } else {
            navigationController.popViewController(animated: true)
        }
    }

    private func presentAssistant(initialInput: String? = nil, mealPlan: MealPlan? = nil) {
        let viewModel = container.makeAIAssistantViewModel(
            mealPlanContext: mealPlan,
            initialInput: initialInput
        )
        viewModel.onMealPlanSwapProposed = { [weak self] proposal in
            guard self?.mealPlanViewModel?.applySwapProposal(proposal) == true else { return false }
            self?.navigationController.dismiss(animated: true)
            return true
        }
        let chat = AIAssistantViewController(viewModel: viewModel)
        chat.showsBackButton = true
        chat.showsHistoryButton = false
        let nav = UINavigationController(rootViewController: chat)
        foodLoggingCoordinator.attachRecipeDetailsOpening(to: chat, navigationController: nav)
        chat.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.navigationController.dismiss(animated: true)
            }
        )
        navigationController.present(nav, animated: true)
    }

    private func showRecipeDetail(_ recipe: Recipe, source: String, replacingCreateForm: Bool = false) {
        Analytics.tracker.track(.recipeOpened(source: source, origin: recipe.origin.isAIRecipe ? "ai" : "catalog"))
        let viewModel = RecipeDetailViewModel(
            recipe: recipe,
            searchRecipesUseCase: container.searchRecipesUseCase,
            recipeRepository: container.recipeRepository,
            aiAssistantService: container.aiAssistantService,
            fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase
        )
        recipeDetailViewModel = viewModel
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onShare = { [weak self] image in
            Analytics.tracker.track(.recipeShared)
            let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            self?.navigationController.present(activity, animated: true)
        }
        viewModel.onShowScoreInfo = { [weak self] title, message in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
            self?.navigationController.present(alert, animated: true)
        }
        viewModel.onAddToDiary = { [weak self] draft in
            Analytics.tracker.track(.recipeAddTapped(mealType: draft.mealType.rawValue))
            self?.foodLoggingCoordinator.openRecipeAddToDiary(draft)
        }
        viewModel.onRequestIngredientSwapChat = { [weak self] recipe, prefill in
            self?.presentIngredientSwapChat(recipe: recipe, prefill: prefill)
        }
        let viewController = RecipeDetailViewController(viewModel: viewModel)
        if replacingCreateForm {
            replaceCreateForm(with: viewController)
        } else {
            navigationController.pushViewController(viewController, animated: true)
        }
    }

    private func qaSwapMeal(showsSheet: Bool) {
        guard let slot = mealPlanViewModel?.selectedDay.value?.slots.first else { return }
        if showsSheet {
            mealPlanViewModel?.onSwapOptions?(slot, Array(QACatalog.recipes.prefix(3)))
        } else {
            mealPlanViewModel?.swappingRecipeIndex.value = slot.recipeIndex
        }
    }

    private func showMealPlanPreview(_ plan: MealPlan, replacingCreateForm: Bool = false) {
        Analytics.tracker.track(.mealPlanOpened)
        let viewModel = MealPlanPreviewViewModel(
            plan: plan,
            mealPlanRepository: container.mealPlanRepository,
            searchRecipesUseCase: container.searchRecipesUseCase,
            fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase,
            logFoodUseCase: container.logFoodUseCase,
            isFreshlyCreated: replacingCreateForm
        )
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onShare = { [weak self] text, image in
            var items: [Any] = [text]
            if let image {
                items.append(image)
            }
            let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
            self?.navigationController.present(activity, animated: true)
        }
        viewModel.onEditWithBity = { [weak self] plan in
            // The plan opens the chat as a card; typing its name into the field said nothing to Bity.
            self?.presentAssistant(mealPlan: plan)
        }
        viewModel.onDeleted = { [weak self] in
            self?.recipesViewModel?.reloadAfterMealPlanCreate()
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onOpenRecipe = { [weak self] recipe in
            self?.showRecipeDetail(recipe, source: "meal_plan")
        }
        mealPlanViewModel = viewModel
        let viewController = MealPlanPreviewViewController(viewModel: viewModel)
        if replacingCreateForm {
            replaceCreateForm(with: viewController)
        } else {
            navigationController.pushViewController(viewController, animated: true)
        }
    }

    private func replaceCreateForm(with viewController: UIViewController) {
        navigationController.pushViewController(viewController, animated: false)
        let stack = navigationController.viewControllers.filter { !($0 is CreateRecipeFormViewController) }
        navigationController.setViewControllers(stack, animated: false)
    }

    private func presentIngredientSwapChat(recipe: Recipe, prefill: String) {
        let viewModel = container.makeAIAssistantViewModel(
            recipeContext: recipe,
            initialInput: prefill
        )
        viewModel.onRecipeIngredientSwapProposed = { [weak self] proposal in
            self?.recipeDetailViewModel?.applyIngredientSwapProposal(proposal)
            self?.navigationController.dismiss(animated: true)
        }
        let chat = AIAssistantViewController(viewModel: viewModel)
        chat.showsHistoryButton = false
        let nav = UINavigationController(rootViewController: chat)
        foodLoggingCoordinator.attachRecipeDetailsOpening(to: chat, navigationController: nav)
        chat.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.navigationController.dismiss(animated: true)
            }
        )
        navigationController.present(nav, animated: true)
    }
}

#if DEBUG
extension RecipesCoordinator {
    func qaPerform(_ route: QARoute) {
        navigationController.popToRootViewController(animated: false)
        navigationController.presentedViewController?.dismiss(animated: false)
        let hub = navigationController.viewControllers.first as? RecipesViewController
        switch route {
        case .recipesAll:
            hub?.qaSelectHub(.all)
        case .recipesSaved, .recipesSavedEmpty:
            hub?.qaSelectHub(.saved)
        case .recipesMealPlans, .recipesMealPlansEmpty:
            hub?.qaSelectHub(.mealPlans)
        case .recipesSearch:
            hub?.qaSearch("chicken")
        case .recipesSearchEmpty:
            hub?.qaSearch("zzzzempty")
        case .recipesFilters:
            var filters = RecipeSearchFilters.empty
            filters.cuisines = [L10n.tr("recipes.filters.italian")]
            filters.excludedIngredients = [
                L10n.tr("recipes.filters.suggest.eggs"),
                L10n.tr("recipes.filters.suggest.wheat")
            ]
            showFilters(filters)
        case .recipesSection:
            showSection(.healthyBreakfast, title: L10n.tr(RecipeBrowseSectionKind.healthyBreakfast.titleKey))
        case .recipeDetail:
            showRecipeDetail(QACatalog.recipes[0], source: "qa")
        case .recipeDetailIngredients:
            showRecipeDetail(QACatalog.recipes[0], source: "qa")
            recipeDetailViewModel?.selectTab(.ingredients)
        case .recipeDetailInstructions:
            showRecipeDetail(QACatalog.recipes[0], source: "qa")
            recipeDetailViewModel?.selectTab(.instructions)
        case .recipesCreate:
            presentCreateSheet()
        case .recipesCreateRecipe:
            showCreateForm(.recipe)
        case .recipesCreateCustom:
            showCreateForm(.recipe)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.createFormViewModel?.selectSource(.custom)
            }
        case .recipesCreateMealPlan:
            showCreateForm(.mealPlan)
        case .mealPlanPreview, .mealPlanSwap, .mealPlanSwapLoading:
            let plan = (try? container.fetchMealPlansUseCase.execute())?.first ?? MealPlan(
                id: QACatalog.uuid("meal-plan"),
                title: QACatalog.recipes[0].title,
                weeks: 1,
                imageURL: QACatalog.recipes[0].imageURL,
                recipes: Array(QACatalog.recipes.prefix(6)),
                createdAt: Date()
            )
            showMealPlanPreview(plan)
            if route != .mealPlanPreview {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.qaSwapMeal(showsSheet: route == .mealPlanSwap)
                }
            }
        case .pantry:
            showPantry()
        case .pantrySelect, .pantrySelected, .pantryDelete, .pantryAdd, .pantryEdit, .fridgeResult, .pantryProduct:
            showPantry()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.qaConfigurePantry(route)
            }
        default:
            break
        }
    }

    private func qaConfigurePantry(_ route: QARoute) {
        switch route {
        case .pantrySelect:
            pantryViewModel?.selectModeTapped()
        case .pantrySelected:
            pantryViewModel?.selectModeTapped()
            if let id = pantryViewModel?.items.value.first?.id {
                pantryViewModel?.toggleItem(id)
            }
        case .pantryDelete:
            pantryViewModel?.selectModeTapped()
            pantryViewModel?.selectAllTapped()
            pantryViewModel?.deleteSelectedTapped()
        case .pantryAdd:
            presentAddToPantry()
        case .pantryEdit:
            if let item = pantryViewModel?.items.value.first {
                presentPantryEdit(item) { _ in }
            }
        case .fridgeResult:
            let items = (try? container.fetchPantryItemsUseCase.execute()) ?? []
            showFridgeResult(Array(items.prefix(4)))
        case .pantryProduct:
            if let recipe = QACatalog.recipes(matching: "healthy").first {
                openPantryProductDetails(ProductDetailsMath.draft(from: recipe), addsToPantry: true)
            }
        default:
            break
        }
    }
}
#endif
