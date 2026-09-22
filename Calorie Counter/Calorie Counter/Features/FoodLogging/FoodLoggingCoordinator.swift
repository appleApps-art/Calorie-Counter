import UIKit

final class FoodLoggingCoordinator {
    private let navigationController: UINavigationController
    private let container: DIContainer
    private var classificationTask: Task<Void, Never>?
    private var classificationRequest = UUID()
    private var foodPhotoCapturer: FoodPhotoCapturing = UnconfiguredFoodPhotoCapturer()
    private weak var screenBeingReplaced: UIViewController?

    init(navigationController: UINavigationController, container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {}

    func openBarcodeScanner(mealType: MealType = .snacks, date: Date = Date(), navigationController: UINavigationController? = nil) {
        Analytics.tracker.track(.foodLogStarted(method: "barcode", source: "quick_log", mealType: mealType.rawValue))
        let viewModel = BarcodeFoodLoggingViewModel(
            lookupBarcodeProductUseCase: container.lookupBarcodeProductUseCase,
            mealType: mealType,
            date: date
        )
        let viewController = BarcodeScannerViewController(
            viewModel: viewModel,
            showsFreeScanQuota: !container.subscriptionService.currentStatus().isPremium
        )
        let host = pushFoodScreen(viewController, from: navigationController)
        viewModel.onClose = { [weak self, weak host] in
            self?.popFoodScreen(host)
        }
        viewModel.onProductReady = { [weak self, weak host] draft in
            self?.openProductDetails(draft, navigationController: host)
        }
        viewModel.onSwitchMode = { [weak self, weak host, weak viewController] action in
            guard let self, let host else { return }
            if case .scanBarcode = action { return }
            self.switchCaptureMode(to: action, replacing: viewController, in: host, mealType: mealType, date: date)
        }
    }

    func openTextFoodLogging(onLogged: (() -> Void)? = nil) {
        Analytics.tracker.track(.foodLogStarted(method: "text", source: "home", mealType: MealType.snacks.rawValue))
        let viewModel = TextFoodLoggingViewModel(
            analyzeTextFoodUseCase: container.analyzeTextFoodUseCase,
            logFoodUseCase: container.logFoodUseCase
        )
        viewModel.onLogged = { [weak self] in
            onLogged?()
            self?.navigationController.popViewController(animated: true)
        }
        let viewController = TextFoodLoggingViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    func openVoiceLog(mealType: MealType = .snacks, date: Date = Date(), navigationController: UINavigationController? = nil) {
        pushVoiceLog(mealType: mealType, date: date, navigationController: navigationController)
    }

    private func pushVoiceLog(mealType: MealType, date: Date, navigationController: UINavigationController?) {
        Analytics.tracker.track(.foodLogStarted(method: "voice", source: "quick_log", mealType: mealType.rawValue))
        let viewModel = container.makeVoiceFoodLoggingViewModel(mealType: mealType, date: date)
        let viewController = VoiceLogViewController(viewModel: viewModel)
        let host = pushFoodScreen(viewController, from: navigationController)
        viewModel.onClose = { [weak self, weak host] in
            self?.popFoodScreen(host)
        }
        viewModel.onViewDetails = { [weak self, weak host] draft in
            self?.openProductDetails(draft, navigationController: host)
        }
        viewModel.onAddEntry = { [weak self, weak host] draft in
            self?.openAddFoodEntry(draft, navigationController: host)
        }
    }

    func makeFoodPhotoAnalysisViewModel(onLogged: (() -> Void)? = nil) -> FoodPhotoAnalysisViewModel {
        let viewModel = FoodPhotoAnalysisViewModel(
            analyzeFoodPhotoUseCase: container.analyzeFoodPhotoUseCase
        )
        viewModel.onLogged = onLogged
        return viewModel
    }

    func attachFoodPhotoCapturer(_ capturer: FoodPhotoCapturing, viewModel: FoodPhotoAnalysisViewModel) {
        foodPhotoCapturer.stopCapture()
        foodPhotoCapturer = capturer
        foodPhotoCapturer.onPhotoCaptured = { [weak viewModel] data in
            viewModel?.analyze(imageData: data)
        }
        foodPhotoCapturer.onCaptureFailed = { [weak viewModel] error in
            viewModel?.statusText.value = error.localizedDescription
        }
    }

    func startFoodPhotoCapture() {
        foodPhotoCapturer.startCapture()
    }

    func stopFoodPhotoCapture() {
        foodPhotoCapturer.stopCapture()
    }

    func analyzeFoodPhoto(imageData: Data, viewModel: FoodPhotoAnalysisViewModel) {
        viewModel.analyze(imageData: imageData)
    }

    func openEditMeal(mealType: MealType, date: Date) {
        let viewModel = EditMealViewModel(
            mealType: mealType,
            date: date,
            fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase,
            deleteFoodEntryUseCase: container.deleteFoodEntryUseCase,
            updateFoodEntryUseCase: container.updateFoodEntryUseCase,
            scaleFoodPortionUseCase: container.scaleFoodPortionUseCase,
            logFoodUseCase: container.logFoodUseCase,
            replaceFoodEntryUseCase: container.replaceFoodEntryUseCase,
            aiAssistantService: container.aiAssistantService,
            buildAIAssistantUserContextUseCase: container.buildAIAssistantUserContextUseCase,
            parseAIAssistantActionsUseCase: container.parseAIAssistantActionsUseCase,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
        )
        let viewController = EditMealViewController(viewModel: viewModel)
        let nav = AppNavigationController(rootViewController: viewController)
        nav.setNavigationBarHidden(true, animated: false)
        nav.isNavigationBarHidden = true
        nav.modalPresentationStyle = .pageSheet
        nav.view.backgroundColor = AppColor.backgroundsPrimaryElevated
        nav.presentationController?.delegate = viewController
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        viewModel.onClose = { [weak nav] in
            nav?.dismiss(animated: true)
        }
        viewModel.onSaved = { [weak nav] in
            nav?.dismiss(animated: true)
        }
        viewModel.onAddFood = { [weak self, weak nav] in
            self?.openMealAddOptions(mealType: mealType, date: date, navigationController: nav)
        }
        viewModel.onOpenFood = { [weak self, weak nav, weak viewModel] id in
            guard let entry = viewModel?.foodEntry(id: id) else { return }
            self?.openDiaryFood(
                entry,
                showsAddToDiary: false,
                navigationController: nav
            )
        }
        navigationController.present(nav, animated: true)
    }

    func openMealAddOptions(mealType: MealType, date: Date, navigationController: UINavigationController?) {
        guard let host = navigationController, host.presentedViewController == nil else { return }
        let sheet = QuickLogSheetViewController(titleKey: "food.edit.addMeal") { [weak self, weak host] action in
            guard let self, let host else { return }
            switch action {
            case .scanFood:
                self.openAIPhoto(mealType: mealType, date: date, navigationController: host)
            case .scanBarcode:
                self.openBarcodeScanner(mealType: mealType, date: date, navigationController: host)
            case .search:
                self.openFoodSearch(mealType: mealType, date: date, navigationController: host)
            case .voiceLog:
                self.openVoiceLog(mealType: mealType, date: date, navigationController: host)
            }
        }
        host.present(sheet, animated: true)
    }

    func openAIPhoto(mealType: MealType, date: Date, navigationController: UINavigationController? = nil) {
        pushAIPhoto(mealType: mealType, date: date, navigationController: navigationController)
    }

    private func pushAIPhoto(mealType: MealType, date: Date, navigationController: UINavigationController?) {
        Analytics.tracker.track(.foodLogStarted(method: "photo", source: "quick_log", mealType: mealType.rawValue))
        let viewModel = FoodPhotoAnalysisViewModel(
            analyzeFoodPhotoUseCase: container.analyzeFoodPhotoUseCase,
            mealType: mealType,
            date: date
        )
        let viewController = AIPhotoCameraViewController(
            viewModel: viewModel,
            showsFreeScanQuota: !container.subscriptionService.currentStatus().isPremium
        )
        let host = pushFoodScreen(viewController, from: navigationController)
        viewModel.onClose = { [weak self, weak host] in
            self?.popFoodScreen(host)
        }
        viewModel.onLogged = { [weak self, weak host] in
            self?.popFoodScreen(host)
        }
        viewModel.onSwitchMode = { [weak self, weak host, weak viewController] action in
            guard let self, let host else { return }
            if case .scanFood = action { return }
            self.switchCaptureMode(to: action, replacing: viewController, in: host, mealType: mealType, date: date)
        }
        viewModel.onViewDetails = { [weak self, weak host] draft in
            self?.openProductDetails(draft, navigationController: host)
        }
        viewModel.onAddEntry = { [weak self, weak host] draft in
            self?.openAddFoodEntry(draft, navigationController: host)
        }
    }

    func attachRecipeDetailsOpening(
        to chat: AIAssistantViewController,
        navigationController: UINavigationController? = nil
    ) {
        chat.onOpenRecipeDetails = { [weak self] option, mealType in
            self?.openMealSuggestionDetails(
                option,
                mealType: mealType,
                navigationController: navigationController
            )
        }
    }

    func openMealSuggestionDetails(
        _ option: MealSuggestionOption,
        mealType: MealType,
        navigationController: UINavigationController? = nil
    ) {
        openProductDetails(
            ProductDetailsMath.draft(from: option, mealType: mealType),
            navigationController: navigationController
        )
    }

    func openDiaryFood(
        _ entry: FoodEntry,
        showsAddToDiary: Bool = false,
        navigationController: UINavigationController? = nil
    ) {
        openProductDetails(
            ProductDetailsMath.draft(from: entry),
            showsAddToDiary: showsAddToDiary,
            navigationController: navigationController
        )
    }

    func openRecipeDetail(
        _ recipe: Recipe,
        showsAddToDiary: Bool = true,
        loggingContext: ProductDetailsDraft? = nil,
        addButtonTitle: String? = nil,
        navigationController: UINavigationController? = nil,
        onAdd: ((ProductDetailsDraft) -> Void)? = nil
    ) {
        // From food logging a dish opens as a recipe: the diary, a scan result or a search hit.
        Analytics.tracker.track(.recipeOpened(
            source: loggingContext?.source ?? "food_logging",
            origin: recipe.origin.isAIRecipe ? "ai" : "catalog"
        ))
        let viewModel = RecipeDetailViewModel(
            recipe: recipe,
            searchRecipesUseCase: container.searchRecipesUseCase,
            recipeRepository: container.recipeRepository,
            aiAssistantService: container.aiAssistantService,
            fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase,
            showsAddToDiary: showsAddToDiary,
            loggingContext: loggingContext,
            addButtonTitle: addButtonTitle
        )
        let viewController = RecipeDetailViewController(viewModel: viewModel)
        let nav = pushFoodScreen(viewController, from: navigationController)
        viewModel.onBack = { [weak self, weak nav] in
            self?.popFoodScreen(nav)
        }
        viewModel.onShare = { [weak nav] image in
            let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            nav?.present(activity, animated: true)
        }
        viewModel.onShowScoreInfo = { [weak nav] title, message in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
            nav?.present(alert, animated: true)
        }
        viewModel.onAddToDiary = { [weak self, weak nav] draft in
            if let onAdd { onAdd(draft) }
            else { self?.openRecipeAddToDiary(draft, from: nav) }
        }
    }

    func openProductDetails(
        _ draft: ProductDetailsDraft,
        showsAddToDiary: Bool = true,
        addButtonTitle: String? = nil,
        // The pantry keeps products on the product screen: a dish there would open the recipe page,
        // whose add button waits for full recipe details that a pantry product never has.
        routesDishesToRecipe: Bool = true,
        navigationController: UINavigationController? = nil,
        onAdd: ((ProductDetailsDraft) -> Void)? = nil
    ) {
        classificationTask?.cancel()
        classificationRequest = UUID()
        guard draft.resolvedFoodType != nil else {
            let requestID = classificationRequest
            let host = navigationController ?? self.navigationController
            let origin = host.topViewController
            let wasVisible = host.viewIfLoaded?.window != nil
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            let loadingHost = origin?.view ?? host.view!
            loadingHost.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: loadingHost.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: loadingHost.centerYAnchor)
            ])
            spinner.startAnimating()
            classificationTask = Task { @MainActor [weak self, weak host, weak origin] in
                defer { spinner.removeFromSuperview() }
                guard let self, let host else { return }
                do {
                    let resolved = try await self.container.searchFoodProductsUseCase.classifiedDraft(draft)
                    guard !Task.isCancelled, self.classificationRequest == requestID,
                          host.topViewController === origin, !host.isBeingDismissed,
                          (!wasVisible || host.viewIfLoaded?.window != nil) else { return }
                    self.openProductDetails(resolved, showsAddToDiary: showsAddToDiary,
                                            addButtonTitle: addButtonTitle, routesDishesToRecipe: routesDishesToRecipe,
                                            navigationController: navigationController, onAdd: onAdd)
                } catch {
                    guard !Task.isCancelled, self.classificationRequest == requestID,
                          host.topViewController === origin, !host.isBeingDismissed,
                          (!wasVisible || host.viewIfLoaded?.window != nil) else { return }
                    Analytics.tracker.track(.errorShown(
                        context: "food_classification",
                        reason: NetworkMonitor.shared.isOnline ? "unavailable" : "offline"
                    ))
                    let alert = UIAlertController(title: L10n.tr("food.classificationUnavailable.title"),
                                                  message: L10n.tr("food.classificationUnavailable.message"), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
                    alert.addAction(UIAlertAction(title: L10n.tr("search.retry"), style: .default) { [weak self] _ in
                        self?.openProductDetails(draft, showsAddToDiary: showsAddToDiary,
                                                 addButtonTitle: addButtonTitle, routesDishesToRecipe: routesDishesToRecipe,
                                                 navigationController: navigationController, onAdd: onAdd)
                    })
                    host.present(alert, animated: true)
                }
            }
            return
        }
        if draft.resolvedFoodType == .dish, routesDishesToRecipe {
            openRecipeDetail(draft.toFoodEntry().asRecipe(), showsAddToDiary: showsAddToDiary,
                             loggingContext: draft, addButtonTitle: addButtonTitle, navigationController: navigationController, onAdd: onAdd)
            return
        }
        let viewModel = ProductDetailsViewModel(
            searchFoodProductsUseCase: container.searchFoodProductsUseCase,
            diaryProvider: { [container] date in try container.fetchDailyDiaryUseCase.execute(for: date) },
            relatedRecipeLoader: { [container] ingredient in
                try await container.searchRecipesUseCase.recipes(containing: ingredient)
            },
            fallbackImageURL: { AIAssistantAPIConfiguration.production.foodImageURL(name: $0) }
        )
        viewModel.configure(draft, showsAddToDiary: showsAddToDiary, addButtonTitle: addButtonTitle)
        let viewController = ProductDetailsViewController(viewModel: viewModel)
        let nav = pushFoodScreen(viewController, from: navigationController)
        viewModel.onBack = { [weak self, weak nav] in
            self?.popFoodScreen(nav)
        }
        viewModel.onShare = { [weak nav] text, image in
            var items: [Any] = [text]
            if let image {
                items.append(image)
            }
            let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
            nav?.present(activity, animated: true)
        }
        viewModel.onShowScoreInfo = { [weak nav] title, message in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
            nav?.present(alert, animated: true)
        }
        viewModel.onAddToDiary = { [weak self, weak nav] draft in
            if let onAdd {
                onAdd(draft)
            } else {
                self?.openAddFoodEntry(draft, navigationController: nav)
            }
        }
        viewModel.onOpenRecipe = { [weak self, weak nav] draft in
            self?.openRecipeDetail(draft.toFoodEntry().asRecipe(), showsAddToDiary: showsAddToDiary,
                                   loggingContext: draft, navigationController: nav, onAdd: onAdd)
        }
    }

    func openFoodRecipe(_ draft: ProductDetailsDraft, from navigationController: UINavigationController?) {
        openRecipeDetail(draft.toFoodEntry().asRecipe(), loggingContext: draft,
                         navigationController: navigationController)
    }

    func openAddFoodEntry(_ draft: ProductDetailsDraft, navigationController: UINavigationController? = nil) {
        let nav = navigationController ?? self.navigationController
        let editor = nav.viewControllers.compactMap { $0 as? EditMealViewController }.first
        let viewModel = AddFoodEntryViewModel(
            logFoodUseCase: container.logFoodUseCase,
            stageEntries: editor.map { editor in { try editor.stageAdditions($0) } },
            analyzeIngredients: { [container] text, mealType in
                try await container.analyzeTextFoodUseCase.execute(text: text, mealType: mealType, includeDiaryContext: false)
            }
        )
        viewModel.configure(draft, presentation: .foodPage)
        viewModel.onBack = { [weak nav] in
            nav?.popViewController(animated: true)
        }
        viewModel.onFinished = { [weak self, weak nav] in
            guard let nav else { return }
            if let editMeal = nav.viewControllers.first(where: { $0 is EditMealViewController }) {
                nav.popToViewController(editMeal, animated: true)
            } else {
                self?.popToHome(from: nav)
            }
        }
        viewModel.onChangeDate = { [weak self, weak viewModel, weak nav] dates in
            self?.openChangeDate(dates: dates, allowsMultipleSelection: true, from: nav) { selected in
                viewModel?.updateDates(selected)
            }
        }
        let viewController = AddFoodEntryViewController(viewModel: viewModel)
        nav.pushViewController(viewController, animated: true)
    }

    func openRecipeAddToDiary(_ draft: ProductDetailsDraft, from navigationController: UINavigationController? = nil) {
        let editor = (navigationController ?? self.navigationController).viewControllers.compactMap { $0 as? EditMealViewController }.first
        let viewModel = AddFoodEntryViewModel(
            logFoodUseCase: container.logFoodUseCase,
            stageEntries: editor.map { editor in { try editor.stageAdditions($0) } },
            analyzeIngredients: { [container] text, mealType in
                try await container.analyzeTextFoodUseCase.execute(text: text, mealType: mealType, includeDiaryContext: false)
            }
        )
        viewModel.configure(draft, presentation: .recipeSheet)
        let viewController = AddFoodEntryViewController(viewModel: viewModel)
        let nav = AppNavigationController(rootViewController: viewController)
        nav.setNavigationBarHidden(true, animated: false)
        nav.isNavigationBarHidden = true
        nav.modalPresentationStyle = .pageSheet
        nav.view.backgroundColor = AppColor.gray6
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        viewModel.onBack = { [weak nav] in
            nav?.dismiss(animated: true)
        }
        viewModel.onFinished = { [weak nav] in
            nav?.dismiss(animated: true)
        }
        let presenter = navigationController ?? self.navigationController
        presenter.present(nav, animated: true)
    }

    func openChangeDate(
        dates: [Date],
        allowsMultipleSelection: Bool,
        from navigationController: UINavigationController? = nil,
        onSelect: @escaping ([Date]) -> Void
    ) {
        let viewController = ChangeDateSheetViewController(
            dates: dates,
            allowsMultipleSelection: allowsMultipleSelection
        )
        viewController.modalPresentationStyle = .pageSheet
        viewController.sheetPresentationController?.applyFigmaInspectorDetent(522)
        viewController.onClose = { [weak viewController] in
            viewController?.dismiss(animated: true)
        }
        viewController.onSelectDates = { [weak viewController] selected in
            onSelect(selected)
            viewController?.dismiss(animated: true)
        }
        presentFromTop(viewController, from: navigationController ?? self.navigationController)
    }

    private func presentFromTop(_ viewController: UIViewController, from host: UIViewController) {
        var presenter = host
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        presenter.present(viewController, animated: true)
    }

    private func popToHome(from navigationController: UINavigationController? = nil) {
        let nav = navigationController ?? self.navigationController
        if let home = nav.viewControllers.first(where: { $0 is HomeViewController }) {
            nav.popToViewController(home, animated: true)
        } else {
            nav.popToRootViewController(animated: true)
        }
    }

    func openFoodSearch(
        mealType: MealType,
        date: Date,
        navigationController: UINavigationController? = nil
    ) {
        let source = navigationController == nil ? "quick_log" : "edit_meal"
        Analytics.tracker.track(.foodLogStarted(method: "search", source: source, mealType: mealType.rawValue))
        let viewModel = FoodSearchViewModel(
            mealType: mealType,
            date: date,
            searchFoodProductsUseCase: container.searchFoodProductsUseCase,
            fetchRecipeBrowseSectionsUseCase: container.fetchRecipeBrowseSectionsUseCase,
            fetchSavedFoodsUseCase: container.fetchSavedFoodsUseCase,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
        )
        let viewController = FoodSearchViewController(viewModel: viewModel)
        let nav = pushFoodScreen(viewController, from: navigationController)
        viewModel.onBack = { [weak self, weak nav] in
            self?.popFoodScreen(nav)
        }
        viewModel.onOpenDetails = { [weak self, weak nav] draft in
            self?.openFoodSearchDetails(draft, navigationController: nav)
        }
        viewModel.onOpenCategory = { [weak self, weak nav, weak viewModel] category in
            self?.openFoodSearchCategory(
                category,
                mealType: mealType,
                date: date,
                previewItems: viewModel?.browseSections.value.first { $0.category == category }?.items ?? [],
                navigationController: nav
            )
        }
        viewModel.onAskBity = { [weak self, weak nav] query in
            self?.openAskBity(query: query, navigationController: nav)
        }
    }

    func openAskBity(query: String, navigationController: UINavigationController?) {
        if let host = navigationController,
           let editor = host.viewControllers.compactMap({ $0 as? EditMealViewController }).first {
            host.popToViewController(editor, animated: true)
            editor.askAssistant(query)
            return
        }
        let chatViewModel = container.makeAIAssistantViewModel(initialInput: query)
        let chat = AIAssistantViewController(viewModel: chatViewModel)
        chat.showsBackButton = true
        chat.showsHistoryButton = false
        let host = navigationController ?? self.navigationController
        attachRecipeDetailsOpening(to: chat, navigationController: host)
        host.pushViewController(chat, animated: true)
    }

    func openFoodSearchCategory(
        _ category: FoodSearchCategory,
        mealType: MealType,
        date: Date,
        previewItems: [FoodSearchItem] = [],
        navigationController: UINavigationController? = nil
    ) {
        let viewModel = FoodSearchCategoryViewModel(
            category: category,
            mealType: mealType,
            date: date,
            searchFoodProductsUseCase: container.searchFoodProductsUseCase,
            fetchRecipeBrowseSectionsUseCase: container.fetchRecipeBrowseSectionsUseCase,
            previewItems: previewItems
        )
        let viewController = FoodSearchCategoryViewController(viewModel: viewModel)
        let nav = pushFoodScreen(viewController, from: navigationController)
        viewModel.onBack = { [weak self, weak nav] in
            self?.popFoodScreen(nav)
        }
        viewModel.onOpenDetails = { [weak self, weak nav] draft in
            self?.openFoodSearchDetails(draft, navigationController: nav)
        }
    }

    private func openFoodSearchDetails(_ draft: ProductDetailsDraft, navigationController: UINavigationController?) {
        openProductDetails(draft, navigationController: navigationController)
    }

    @discardableResult
    private func pushFoodScreen(
        _ viewController: UIViewController,
        from source: UINavigationController?
    ) -> UINavigationController {
        let host = source ?? navigationController
        if let replaced = screenBeingReplaced, host.viewControllers.contains(where: { $0 === replaced }) {
            // Switching mode swaps the screen in place, the way the segmented control reads.
            var stack = host.viewControllers
            stack.removeAll { $0 === replaced }
            host.setViewControllers(stack + [viewController], animated: false)
            return host
        }
        if isSheetContainer(host) {
            if let presented = host.presentedViewController as? UINavigationController,
               presented.modalPresentationStyle == .fullScreen {
                presented.pushViewController(viewController, animated: true)
                return presented
            }
            let nav = AppNavigationController()
            nav.dismissesWhenPoppedToRoot = true
            nav.setNavigationBarHidden(true, animated: false)
            nav.isNavigationBarHidden = true
            nav.modalPresentationStyle = .fullScreen
            nav.setViewControllers(
                [Self.snapshotPlaceholder(from: host), viewController],
                animated: false
            )
            host.present(nav, animated: true)
            return nav
        }
        host.pushViewController(viewController, animated: true)
        return host
    }

    private static func snapshotPlaceholder(from host: UIViewController) -> UIViewController {
        let placeholder = UIViewController()
        placeholder.view.backgroundColor = AppColor.backgroundsPrimary
        if let snapshot = host.view.window?.snapshotView(afterScreenUpdates: false) {
            snapshot.frame = placeholder.view.bounds
            snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            placeholder.view.addSubview(snapshot)
        }
        return placeholder
    }

    /// The capture screens' segmented control opens another mode in place of the current one.
    /// Popping first left a full-screen flow at its root for a moment, and such a flow closes itself
    /// there, which dropped the user back on Home.
    private func switchCaptureMode(
        to action: HomeQuickLogAction,
        replacing screen: UIViewController?,
        in host: UINavigationController,
        mealType: MealType,
        date: Date
    ) {
        screenBeingReplaced = screen
        defer { screenBeingReplaced = nil }
        switch action {
        case .scanFood:
            openAIPhoto(mealType: mealType, date: date, navigationController: host)
        case .scanBarcode:
            openBarcodeScanner(mealType: mealType, date: date, navigationController: host)
        case .search:
            openFoodSearch(mealType: mealType, date: date, navigationController: host)
        case .voiceLog:
            openVoiceLog(mealType: mealType, date: date, navigationController: host)
        }
    }

    private func popFoodScreen(_ nav: UINavigationController?) {
        classificationTask?.cancel()
        guard let nav else { return }
        if nav.presentingViewController != nil, nav.viewControllers.count <= 1 {
            nav.dismiss(animated: true)
        } else {
            nav.popViewController(animated: true)
        }
    }

    private func isSheetContainer(_ nav: UINavigationController) -> Bool {
        nav.modalPresentationStyle == .pageSheet || nav.sheetPresentationController != nil
    }
}
