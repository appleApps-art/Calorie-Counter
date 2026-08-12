import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private let container: DIContainer
    private var tabBarController: MainTabBarController?
    private var didShowMain = false

    init(window: UIWindow, container: DIContainer) {
        self.window = window
        self.container = container
    }

    func start() {
        if isOnboardingCompleted {
            showMain()
        } else {
            showOnboarding()
        }
        window.makeKeyAndVisible()
    }

    private var isOnboardingCompleted: Bool {
        (try? container.fetchOnboardingStateUseCase.execute())?.onboardingCompleted ?? false
    }

    private func showOnboarding() {
        let viewModel = container.makeOnboardingViewModel()
        viewModel.isCompleted.bind { [weak self] completed in
            guard completed else { return }
            self?.showMain()
        }
        window.rootViewController = OnboardingViewController(viewModel: viewModel)
    }

    private func showMain() {
        guard !didShowMain else { return }
        didShowMain = true
        let tabBarController = MainTabBarController(container: container)
        self.tabBarController = tabBarController
        window.rootViewController = tabBarController
        container.reminderScheduleController.bootstrap()
    }
}
