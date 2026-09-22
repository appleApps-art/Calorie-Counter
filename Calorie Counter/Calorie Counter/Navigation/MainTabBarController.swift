import UIKit

final class MainTabBarController: UITabBarController {
    private let container: DIContainer
    private var foodLoggingCoordinator: FoodLoggingCoordinator?
    private var aiAssistantCoordinator: AIAssistantCoordinator?
    private var rewardsCoordinator: RewardsCoordinator?
    private var progressCoordinator: ProgressCoordinator?
    private var recipesCoordinator: RecipesCoordinator?
    private var settingsCoordinator: SettingsCoordinator?

    init(container: DIContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let backgroundBlurView = TabBarBackgroundBlurView()
    private var didInstallBackgroundBlur = false
    private weak var transitioningViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabBar()
        viewControllers = Tab.tabBarItems.map(makeNavigationController(for:))
        delegate = self
        #if DEBUG
        if QALaunchConfiguration.isActive {
            DispatchQueue.main.async { [weak self] in
                self?.qaStart()
            }
        }
        #endif
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installBackgroundBlurIfNeeded()
        layoutTabBarBackground()
    }

    private func configureTabBar() {
        tabBar.tintColor = AppColor.tabSelected
        tabBar.unselectedItemTintColor = AppColor.labelsSecondary
        tabBar.isTranslucent = true
        tabBar.clipsToBounds = false
        tabBar.layer.masksToBounds = false
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = .clear
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    private func installBackgroundBlurIfNeeded() {
        guard !didInstallBackgroundBlur else { return }
        didInstallBackgroundBlur = true
        backgroundBlurView.isUserInteractionEnabled = false
        view.clipsToBounds = false
        view.layer.masksToBounds = false
    }

    func refreshTabBarChrome(for viewController: UIViewController? = nil) {
        transitioningViewController = viewController
        installBackgroundBlurIfNeeded()
        layoutTabBarBackground()
        transitioningViewController = nil
    }

    private func layoutTabBarBackground() {
        guard didInstallBackgroundBlur else { return }
        let showChrome = shouldShowTabBarBackground()
        if !showChrome {
            backgroundBlurView.isHidden = true
            backgroundBlurView.alpha = 0
            backgroundBlurView.removeFromSuperview()
            return
        }

        tabBar.clipsToBounds = false
        tabBar.layer.masksToBounds = false
        view.clipsToBounds = false
        view.layer.masksToBounds = false

        var tabChrome: UIView = tabBar
        while let parent = tabChrome.superview, parent !== view {
            tabChrome.clipsToBounds = false
            tabChrome.layer.masksToBounds = false
            tabChrome = parent
        }
        tabChrome.clipsToBounds = false
        tabChrome.layer.masksToBounds = false
        backgroundBlurView.isHidden = false
        backgroundBlurView.alpha = 1
        if tabChrome.superview === view {
            view.insertSubview(backgroundBlurView, belowSubview: tabChrome)
        } else {
            view.addSubview(backgroundBlurView)
        }

        backgroundBlurView.neutralBackground = selectedIndex == Tab.tabBarItems.firstIndex(of: .rewards)
        // Figma: 65 pt of bottom chrome + the home-indicator safe area (99 pt on iPhone).
        // UITabBar.bounds already includes UIKit's margins; adding an overhang double-counts them.
        let backdropHeight = 65 + view.safeAreaInsets.bottom
        backgroundBlurView.frame = CGRect(
            x: view.bounds.minX,
            y: view.bounds.maxY - backdropHeight,
            width: view.bounds.width,
            height: backdropHeight
        )
    }

    private func shouldShowTabBarBackground() -> Bool {
        if tabBar.isHidden { return false }
        let displayed = displayedContentViewController()
        if displayed?.hidesBottomBarWhenPushed == true {
            let navigation = displayed?.navigationController
            if navigation == nil || navigation?.viewControllers.first !== displayed {
                return false
            }
        }
        if displayed?.presentedViewController != nil
            || selectedViewController?.presentedViewController != nil {
            return false
        }
        let tabFrame = tabBar.convert(tabBar.bounds, to: view)
        // iPad's top tab bar supplies its own material. The bottom fade is only
        // appropriate for the phone-style tab bar at the bottom of the window.
        return tabFrame.minY >= view.bounds.midY && tabFrame.minY < view.bounds.maxY - 8
    }

    private func displayedContentViewController() -> UIViewController? {
        if let transitioningViewController {
            return transitioningViewController
        }
        if let navigation = selectedViewController as? UINavigationController {
            return navigation.topViewController
        }
        return selectedViewController
    }

    private func makeNavigationController(for tab: Tab) -> UINavigationController {
        let navigationController = AppNavigationController()
        configureNavigationBar(navigationController.navigationBar)
        let rootViewController = makeRootViewController(for: tab, navigationController: navigationController)
        navigationController.setViewControllers([rootViewController], animated: false)
        navigationController.tabBarItem = UITabBarItem(
            title: tab.title,
            image: UIImage(systemName: tab.systemImageName),
            tag: tab.rawValue
        )
        if tab == .home || tab == .aiAssistant || tab == .rewards || tab == .progress || tab == .recipes {
            rootViewController.navigationItem.largeTitleDisplayMode = .never
        } else {
            rootViewController.navigationItem.title = tab.title
            rootViewController.navigationItem.largeTitleDisplayMode = .always
        }
        return navigationController
    }

    private func configureNavigationBar(_ navigationBar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: AppColor.textPrimary,
            .font: UIFont.systemFont(ofSize: 28, weight: .bold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: AppColor.textPrimary,
            .font: UIFont.systemFont(ofSize: 28, weight: .bold)
        ]
        navigationBar.prefersLargeTitles = true
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = AppColor.teal
        navigationBar.isTranslucent = true
    }

    private func makeRootViewController(for tab: Tab, navigationController: UINavigationController) -> UIViewController {
        switch tab {
        case .home:
            let foodLogging = FoodLoggingCoordinator(
                navigationController: navigationController,
                container: container
            )
            foodLoggingCoordinator = foodLogging
            let home = HomeViewController(viewModel: container.makeHomeViewModel())
            home.onQuickLog = { [weak self, weak home] action in
                self?.handle(action, date: home?.displayedDate ?? Date())
            }
            home.onEditMeal = { [weak self] mealType, date in
                self?.foodLoggingCoordinator?.openEditMeal(mealType: mealType, date: date)
            }
            home.onOpenFood = { [weak self] entry in
                self?.foodLoggingCoordinator?.openDiaryFood(entry, showsAddToDiary: false)
            }
            home.onOpenProfile = { [weak self, weak navigationController] in
                self?.openSettings(from: navigationController)
            }
            home.onOpenStreak = { [weak self] in
                self?.selectedIndex = Tab.rewards.rawValue
            }
            return home
        case .aiAssistant:
            let coordinator = AIAssistantCoordinator(
                navigationController: navigationController,
                container: container
            )
            aiAssistantCoordinator = coordinator
            return coordinator.makeRoot()
        case .progress:
            let coordinator = ProgressCoordinator(
                navigationController: navigationController,
                container: container
            )
            progressCoordinator = coordinator
            navigationController.setNavigationBarHidden(true, animated: false)
            return coordinator.makeRoot()
        case .recipes:
            let coordinator = RecipesCoordinator(
                navigationController: navigationController,
                container: container
            )
            recipesCoordinator = coordinator
            return coordinator.start()
        case .rewards:
            let coordinator = RewardsCoordinator(
                navigationController: navigationController,
                container: container
            )
            rewardsCoordinator = coordinator
            navigationController.setNavigationBarHidden(true, animated: false)
            return coordinator.makeRoot()
        }
    }

    private func handle(_ action: HomeQuickLogAction, mealType: MealType = .snacks, date: Date) {
        selectedIndex = Tab.home.rawValue
        switch action {
        case .scanBarcode:
            foodLoggingCoordinator?.openBarcodeScanner(mealType: mealType, date: date)
        case .search:
            foodLoggingCoordinator?.openFoodSearch(mealType: mealType, date: date)
        case .scanFood:
            foodLoggingCoordinator?.openAIPhoto(mealType: mealType, date: date)
        case .voiceLog:
            foodLoggingCoordinator?.openVoiceLog(mealType: mealType, date: date)
        }
    }

    /// A tapped reminder lands where it asked the user to go: a meal reminder opens the ways to
    /// log that very meal, the weight one opens the weight entry.
    func openReminder(_ kind: ReminderKind) {
        presentedViewController?.dismiss(animated: false)
        viewControllers?.forEach { ($0 as? UINavigationController)?.popToRootViewController(animated: false) }
        switch kind {
        case .breakfast, .lunch, .dinner:
            let mealType: MealType = kind == .breakfast ? .breakfast : (kind == .lunch ? .lunch : .dinner)
            selectedIndex = Tab.home.rawValue
            let sheet = QuickLogSheetViewController { [weak self] action in
                self?.handle(action, mealType: mealType, date: Date())
            }
            present(sheet, animated: true)
        case .weight:
            selectedIndex = Tab.progress.rawValue
            progressCoordinator?.openLogSheet()
        case .water, .dailyStreak, .comeback:
            selectedIndex = Tab.home.rawValue
        }
    }

    private func openSettings(from navigationController: UINavigationController?) {
        guard let navigationController else { return }
        let coordinator = SettingsCoordinator(
            navigationController: navigationController,
            container: container
        )
        settingsCoordinator = coordinator
        coordinator.start()
    }
}

extension MainTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard Tab.tabBarItems.indices.contains(selectedIndex) else { return }
        Analytics.tracker.track(.tabSelected(Tab.tabBarItems[selectedIndex].analyticsName))
        Haptics.selection()
    }
}

#if DEBUG
extension MainTabBarController {
    func qaStart() {
        if let route = QALaunchConfiguration.route {
            qaPerform(route)
        }
        QACaptureRunner.startIfNeeded(from: self)
    }

    func qaResetStack() {
        view.window?.endEditing(true)
        presentedViewController?.dismiss(animated: false)
        viewControllers?.forEach { controller in
            controller.presentedViewController?.dismiss(animated: false)
            (controller as? UINavigationController)?.popToRootViewController(animated: false)
        }
    }

    func qaPerform(_ route: QARoute) {
        switch route {
        case .home:
            selectedIndex = Tab.home.rawValue
        case .homeGlassVolume:
            selectedIndex = Tab.home.rawValue
            let sheet = GlassVolumeSheetViewController(milliliters: 150) { _ in }
            selectedViewController?.present(sheet, animated: false)
        case .recipesAll, .recipesSaved, .recipesSavedEmpty, .recipesMealPlans, .recipesMealPlansEmpty,
             .recipesSearch, .recipesSearchEmpty, .recipesFilters, .recipesSection,
             .recipesCreate, .recipesCreateRecipe, .recipesCreateCustom, .recipesCreateMealPlan,
             .pantry, .pantrySelect, .pantrySelected, .pantryDelete, .pantryAdd,
             .fridgeResult, .pantryEdit, .pantryProduct, .recipeDetail, .recipeDetailIngredients,
             .recipeDetailInstructions, .mealPlanPreview, .mealPlanSwap, .mealPlanSwapLoading:
            selectedIndex = Tab.recipes.rawValue
            recipesCoordinator?.qaPerform(route)
        case .progress, .progressLog, .progressPhotos:
            selectedIndex = Tab.progress.rawValue
            qaProgress(route)
        case .settings, .settingsNutrition, .settingsWeight, .settingsTheme,
             .settingsNotifications, .settingsHealth:
            selectedIndex = Tab.home.rawValue
            qaSettings(route)
        case .aiIntro, .aiChat, .aiMealSuggestion, .aiFoodSwap, .aiMealLogged, .aiHistory:
            selectedIndex = Tab.aiAssistant.rawValue
            qaAssistant(route)
        case .foodSearch, .foodSearchResults, .productDetails, .addFoodEntry, .foodRecipe,
             .editMeal, .textFood, .voiceFood, .voiceFoodResult, .photoFood, .photoFoodResult, .barcodeScanner:
            selectedIndex = Tab.home.rawValue
            qaFood(route)
        case .logWeight, .logWorkout, .logWeightDate, .logWorkoutDate:
            selectedIndex = Tab.progress.rawValue
            if route == .logWeight || route == .logWeightDate { progressCoordinator?.openLogWeight() }
            else { progressCoordinator?.openLogExercise() }
            if route == .logWeightDate || route == .logWorkoutDate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                    self?.progressCoordinator?.openChangeDate(date: Date(), maximumDate: Date(), onSelect: { _ in })
                }
            }
        case .rewards, .rewardDetail, .rewardCelebration:
            selectedIndex = Tab.rewards.rawValue
            if route != .rewards {
                let detail = RewardDetailViewController(
                    progress: BadgeProgress(badge: .mealTrackerMaster, current: 7, goal: 7),
                    playsCelebration: route == .rewardCelebration
                )
                detail.modalPresentationStyle = .overFullScreen
                selectedViewController?.present(detail, animated: false)
            }
        case .onboardingWelcome, .onboardingGoal, .onboardingSex, .onboardingActivity,
             .onboardingAge, .onboardingBody, .onboardingHealth, .onboardingPlan, .appRating:
            qaOnboarding(route)
        case .paywallOnboarding, .paywallFeature:
            let paywall = container.paywallFactory.makePaywall(
                placement: route == .paywallOnboarding ? .onboarding : .main,
                events: SubscriptionPaywallEvents()
            )
            paywall.modalPresentationStyle = .fullScreen
            present(paywall, animated: false)
        }
    }

    private func qaProgress(_ route: QARoute) {
        guard let coordinator = progressCoordinator else { return }
        switch route {
        case .progressLog:
            coordinator.openLogSheet()
        case .progressPhotos:
            coordinator.openPhotos()
        default:
            break
        }
    }

    private func qaSettings(_ route: QARoute) {
        let navigation = selectedViewController as? UINavigationController ?? viewControllers?[Tab.home.rawValue] as? UINavigationController
        guard let navigation else { return }
        if settingsCoordinator == nil || navigation.topViewController is HomeViewController {
            openSettings(from: navigation)
        }
        settingsCoordinator?.qaOpen(route)
    }

    private func qaPush(_ controller: UIViewController, hidesTabBar: Bool = true) {
        controller.hidesBottomBarWhenPushed = hidesTabBar
        (selectedViewController as? UINavigationController)?.pushViewController(controller, animated: false)
    }

    private func qaAssistant(_ route: QARoute) {
        if route == .aiIntro {
            qaPush(AIIntroViewController(), hidesTabBar: false)
            return
        }
        if route == .aiHistory {
            let history = PersistChatHistoryUseCase(chatHistoryRepository: QAResponsiveChatHistory())
            qaPush(ChatHistoryViewController(viewModel: ChatHistoryViewModel(persistChatHistoryUseCase: history)))
            return
        }
        let viewModel = AIAssistantViewModel(
            aiAssistantService: container.aiAssistantService,
            fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase
        )
        let option = MealSuggestionOption(
            title: "Курка з кіноа, запеченими овочами та йогуртовим соусом",
            summary: "Поживний обід із простих інгредієнтів. Порція розрахована на одну людину.",
            calories: 420, protein: 34, carbs: 42, fats: 13,
            cookTimeMinutes: 25, externalRecipeId: nil, imageURL: qaFoodImageURL,
            ingredients: ["Куряче філе 150 г", "Кіноа 80 г", "Овочі 120 г"],
            steps: ["Відваріть кіноа.", "Запечіть курку й овочі та подавайте із соусом."],
            mealType: .lunch, portionGrams: 350
        )
        let content: AIChatItem.Kind
        switch route {
        case .aiMealSuggestion:
            viewModel.selectedCategory.value = .meals
            content = .recipe(option, mealType: .lunch)
        case .aiFoodSwap:
            viewModel.selectedCategory.value = .swaps
            content = .swap(FoodSwapProposal(
                original: FoodSwapItem(name: "Солодкий йогурт із наповнювачем", calories: 210, protein: 7, carbs: 32, fats: 6, portionLabel: "200 г", imageURL: qaFoodImageURL),
                alternative: FoodSwapItem(name: "Грецький йогурт із сезонними ягодами", calories: 145, protein: 18, carbs: 14, fats: 2, portionLabel: "200 г", imageURL: qaFoodImageURL),
                savingsKcal: 65, savingsNote: "Більше білка та менше доданого цукру.", applyToEntryId: nil
            ))
        case .aiMealLogged:
            content = .loggedMeal(entryID: nil, proposal: option.asFoodLogProposal(mealType: .lunch))
        default:
            content = .assistant("Можу запропонувати ідеї страв, підібрати заміну продукту або допомогти записати прийом їжі. Що ви хотіли б приготувати сьогодні?")
        }
        viewModel.messages.value = [
            AIChatItem(kind: .user("Порадь поживну страву на обід, яку можна швидко приготувати вдома.")),
            AIChatItem(kind: content)
        ]
        let chat = AIAssistantViewController(viewModel: viewModel)
        chat.showsBackButton = false
        chat.showsHistoryButton = true
        chat.showsNewChatButton = true
        qaPush(chat, hidesTabBar: false)
    }

    private func qaFood(_ route: QARoute) {
        let draft = qaFoodDraft
        switch route {
        case .foodSearch:
            foodLoggingCoordinator?.openFoodSearch(mealType: .lunch, date: Date())
        case .foodSearchResults:
            let model = FoodSearchViewModel(
                mealType: .lunch, date: Date(), searchFoodProductsUseCase: container.searchFoodProductsUseCase,
                fetchRecipeBrowseSectionsUseCase: container.fetchRecipeBrowseSectionsUseCase,
                fetchSavedFoodsUseCase: container.fetchSavedFoodsUseCase,
                voiceRecorder: container.voiceFoodAudioRecorder,
                transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
            )
            let controller = FoodSearchViewController(viewModel: model)
            qaPush(controller)
            model.updateQuery("chicken")
            model.searchTapped()
        case .productDetails:
            let recipe = draft.toFoodEntry().asRecipe()
            let model = ProductDetailsViewModel(
                diaryProvider: { [container] date in try container.fetchDailyDiaryUseCase.execute(for: date) },
                relatedRecipeLoader: { _ in [recipe] }
            )
            var product = draft
            product.name = "Грецький йогурт"
            product.catalogKind = .product
            product.recipeSteps = []
            product.ingredients = []
            product.calories = 150
            product.protein = 20
            product.carbs = 8
            product.fats = 4
            product.fiber = 0
            product.sugar = 8
            product.sodium = 60
            product.portionGrams = 200
            model.configure(product)
            model.onOpenRecipe = { [weak self] recipeDraft in
                self?.foodLoggingCoordinator?.openFoodRecipe(recipeDraft, from: self?.selectedViewController as? UINavigationController)
            }
            qaPush(ProductDetailsViewController(viewModel: model))
        case .addFoodEntry:
            foodLoggingCoordinator?.openAddFoodEntry(draft)
        case .foodRecipe:
            foodLoggingCoordinator?.openFoodRecipe(draft, from: selectedViewController as? UINavigationController)
        case .editMeal:
            foodLoggingCoordinator?.openEditMeal(mealType: .lunch, date: Date())
        case .textFood:
            foodLoggingCoordinator?.openTextFoodLogging()
        case .voiceFood, .voiceFoodResult:
            let model = container.makeVoiceFoodLoggingViewModel(mealType: .lunch)
            if route == .voiceFoodResult {
                model.transcriptText.value = "Я з’їв курку з кіноа, овочами та йогуртовим соусом, приблизно 350 грамів."
                model.analysis.value = qaFoodAnalysis
                model.phase.value = .result
            }
            qaPush(VoiceLogViewController(viewModel: model))
        case .photoFood, .photoFoodResult:
            let model = FoodPhotoAnalysisViewModel(analyzeFoodPhotoUseCase: container.analyzeFoodPhotoUseCase)
            if route == .photoFoodResult {
                model.analysis.value = qaFoodAnalysis
                model.capturedImage.value = UIImage(data: QACatalog.jpeg(color: .systemOrange))
                model.phase.value = .result
                model.canConfirmLog.value = true
            }
            qaPush(AIPhotoCameraViewController(viewModel: model, capturer: QAResponsivePhotoCapturer()))
        case .barcodeScanner:
            let model = BarcodeFoodLoggingViewModel(lookupBarcodeProductUseCase: container.lookupBarcodeProductUseCase)
            // Render real scanner chrome without beginning an AV authorization/session flow.
            qaPush(QAResponsiveCameraChromeHost(content: BarcodeScannerViewController(viewModel: model)))
        default: break
        }
    }

    private var qaFoodImageURL: URL {
        let url = QACatalog.imageURL(id: "responsive-food", color: .systemOrange)
        RemoteImageLoader.shared.display(url, data: QACatalog.jpeg(color: .systemOrange), in: UIImageView(), placeholder: nil)
        return url
    }

    private var qaFoodDraft: ProductDetailsDraft {
        var value = ProductDetailsMath.draft(from: qaFoodAnalysis, imageData: QACatalog.jpeg(color: .systemOrange), mealType: .lunch, date: Date())
        value.imageURL = qaFoodImageURL
        value.recipeSteps = ["Відваріть кіноа до готовності.", "Запечіть курку та овочі. Додайте соус перед подачею."]
        value.catalogKind = .recipe
        return value
    }

    private var qaFoodAnalysis: FoodPhotoAnalysis {
        FoodPhotoAnalysis(
            name: "Курка з кіноа, овочами та йогуртовим соусом", mealType: .lunch,
            calories: 420, protein: 34, carbs: 42, fats: 13, fiber: 7, sugar: 5, sodium: 480,
            portionGrams: 350, portionMilliliters: nil, confidence: 0.95,
            notes: "Домашня страва з овочами та легким соусом.", assistantMessage: "Страву розпізнано.",
            servingLabel: "1 порція", ingredients: [
                FoodIngredient(name: "Куряче філе", grams: 150), FoodIngredient(name: "Кіноа", grams: 80),
                FoodIngredient(name: "Запечені овочі", grams: 120)
            ], tags: ["high protein"], source: "qa"
        )
    }

    private func qaOnboarding(_ route: QARoute) {
        let controller: UIViewController
        switch route {
        case .onboardingWelcome: controller = WelcomeViewController()
        case .onboardingGoal: controller = OnboardingOptionsViewController.goal()
        case .onboardingSex: controller = OnboardingOptionsViewController.sex()
        case .onboardingActivity: controller = OnboardingOptionsViewController.activity()
        case .onboardingAge: controller = OnboardingAgeViewController()
        case .onboardingBody: controller = OnboardingBodyViewController()
        case .onboardingHealth: controller = OnboardingHealthViewController()
        case .appRating: controller = AppRatingViewController()
        default:
            let plan = OnboardingPlanViewController()
            // Fed by the real calculator, so QA sees the numbers and units a user would.
            var profile = UserProfile.empty
            profile.sex = .male
            profile.age = 30
            profile.heightCm = 180
            profile.weightKg = 80
            profile.activityLevel = .moderate
            profile.goalType = .lose
            if let calculated = CalculateNutritionPlanUseCase().execute(profile: profile) {
                plan.apply(OnboardingFlowViewModel.display(for: calculated))
            }
            controller = plan
        }
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: false)
    }
}

private final class QAResponsivePhotoCapturer: FoodPhotoCapturing {
    var onPhotoCaptured: ((Data) -> Void)?
    var onCaptureFailed: ((Error) -> Void)?
    var onSessionRunning: (() -> Void)?
    var isTorchAvailable: Bool { false }
    var isTorchOn: Bool { false }
    func attachPreview(to view: UIView) { view.backgroundColor = .black }
    func layoutPreview(in view: UIView) {}
    func startCapture() { onSessionRunning?() }
    func stopCapture() {}
    func captureStillPhoto(scanFrameInPreview frame: CGRect) {}
    func setTorchOn(_ on: Bool) {}
    func setLivePreviewHidden(_ hidden: Bool) {}
}

private final class QAResponsiveCameraChromeHost: UIViewController {
    private let content: UIViewController
    override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }
    init(content: UIViewController) { self.content = content; super.init(nibName: nil, bundle: nil) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), content.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.view.topAnchor.constraint(equalTo: view.topAnchor), content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        content.didMove(toParent: self)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

private final class QAResponsiveChatHistory: ChatHistoryRepositoryProtocol {
    private var messages: [ChatHistoryMessage] = (0..<8).flatMap { index in
        let date = Date().addingTimeInterval(-Double(index) * 25 * 3600)
        let conversationID = QACatalog.uuid("responsive-chat-\(index)")
        return [
            ChatHistoryMessage(id: UUID(), role: "user", content: index.isMultiple(of: 2) ? "Що приготувати на вечерю з куркою та сезонними овочами?" : "Допоможи підібрати поживний перекус після тренування", createdAt: date, conversationID: conversationID),
            ChatHistoryMessage(id: UUID(), role: "assistant", content: "Ось проста страва з достатньою кількістю білка та овочів для збалансованого харчування.", createdAt: date.addingTimeInterval(15), conversationID: conversationID)
        ]
    }
    func fetchRecent(limit: Int) throws -> [ChatHistoryMessage] { Array(messages.suffix(limit)) }
    func fetchAll() throws -> [ChatHistoryMessage] { messages }
    func append(_ message: ChatHistoryMessage) throws { messages.append(message) }
    func replaceAll(_ messages: [ChatHistoryMessage]) throws { self.messages = messages }
}
#endif
