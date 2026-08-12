import UIKit

final class MainTabBarController: UITabBarController {
    private let container: DIContainer
    private var recipesCoordinator: RecipesCoordinator?
    private var foodLoggingCoordinator: FoodLoggingCoordinator?

    init(container: DIContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = Tab.allCases.map(makeNavigationController(for:))
    }

    private func makeNavigationController(for tab: Tab) -> UINavigationController {
        let navigationController = UINavigationController()
        let rootViewController = makeRootViewController(for: tab, navigationController: navigationController)
        rootViewController.title = tab.title
        rootViewController.tabBarItem = UITabBarItem(
            title: tab.title,
            image: UIImage(systemName: tab.systemImageName),
            tag: tab.rawValue
        )
        navigationController.setViewControllers([rootViewController], animated: false)
        navigationController.tabBarItem = rootViewController.tabBarItem
        return navigationController
    }

    private func makeRootViewController(for tab: Tab, navigationController: UINavigationController) -> UIViewController {
        switch tab {
        case .home:
            let foodLogging = FoodLoggingCoordinator(
                navigationController: navigationController,
                container: container
            )
            foodLoggingCoordinator = foodLogging
            return HomeViewController(
                viewModel: container.makeHomeViewModel(),
                onScanBarcode: { [weak foodLogging] in
                    foodLogging?.openBarcodeScanner()
                },
                onLogByText: { [weak foodLogging] in
                    foodLogging?.openTextFoodLogging()
                }
            )
        case .recipes:
            let coordinator = RecipesCoordinator(navigationController: navigationController, container: container)
            recipesCoordinator = coordinator
            return coordinator.start()
        case .aiAssistant:
            return AIAssistantViewController(
                viewModel: AIAssistantViewModel(
                    aiAssistantService: container.aiAssistantService,
                    fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase,
                    logWaterUseCase: container.logWaterUseCase,
                    buildAIAssistantUserContextUseCase: container.buildAIAssistantUserContextUseCase,
                    parseAIAssistantActionsUseCase: container.parseAIAssistantActionsUseCase,
                    confirmAIAssistantActionUseCase: container.confirmAIAssistantActionUseCase,
                    persistChatHistoryUseCase: container.persistChatHistoryUseCase
                )
            )
        case .progress:
            return ProgressViewController(viewModel: container.makeProgressViewModel())
        case .settings:
            return SettingsViewController(viewModel: container.makeSettingsViewModel())
        }
    }
}
