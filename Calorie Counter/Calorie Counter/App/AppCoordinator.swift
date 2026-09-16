import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private let container: DIContainer
    private var tabBarController: MainTabBarController?
    private var onboardingCoordinator: OnboardingFlowCoordinator?
    private var didShowMain = false
    private let badgeUnlockPresenter: BadgeUnlockPresenter
    private let appRatingPrompt: AppRatingPromptController

    init(window: UIWindow, container: DIContainer) {
        self.window = window
        self.container = container
        self.badgeUnlockPresenter = BadgeUnlockPresenter(
            inboxStore: container.notificationInboxStore,
            markBadgeSeen: { [container] badge in
                try? container.markBadgeSeenUseCase.execute(badge)
            },
            isBadgeSeen: { [container] badge in
                container.markBadgeSeenUseCase.isSeen(badge)
            }
        )
        self.appRatingPrompt = AppRatingPromptController(
            settingsStore: container.appSettingsStore,
            analytics: Analytics.hub
        )
    }

    func start() {
        let splash = SplashViewController()
        splash.onFinished = { [weak self] in
            self?.routeAfterSplash()
        }
        window.rootViewController = splash
        window.makeKeyAndVisible()
    }

    private var isOnboardingCompleted: Bool {
        (try? container.fetchOnboardingStateUseCase.execute())?.onboardingCompleted ?? false
    }

    private func routeAfterSplash() {
        if isOnboardingCompleted {
            showMain()
        } else {
            showWelcome()
        }
    }

    private func showWelcome() {
        let coordinator = OnboardingFlowCoordinator(
            viewModel: container.makeOnboardingFlowViewModel(),
            subscriptionCoordinator: container.makeSubscriptionCoordinator(),
            subscriptionService: container.subscriptionService
        )
        coordinator.onFinished = { [weak self] in
            self?.showMain()
        }
        onboardingCoordinator = coordinator
        setRoot(coordinator.makeRootViewController())
    }

    private func showMain() {
        guard !didShowMain else { return }
        didShowMain = true
        onboardingCoordinator = nil
        let tabBarController = MainTabBarController(container: container)
        self.tabBarController = tabBarController
        bindBadgeUnlocks(host: tabBarController)
        appRatingPrompt.attach(host: tabBarController)
        Analytics.hub.appRatingPrompt = appRatingPrompt
        setRoot(tabBarController)
        DispatchQueue.main.async { [weak self] in
            self?.presentPendingBadgeUnlocks()
        }
        container.reminderScheduleController.bootstrap()
        container.healthSyncController.bootstrap()
        var properties: [String: Any] = [
            "onboarding_completed": true,
            "is_premium": container.subscriptionService.currentStatus().isPremium,
            "health_sync_enabled": container.appSettingsStore.settings.healthSyncEnabled
        ]
        if let profile = try? container.fetchOnboardingStateUseCase.execute() {
            if let goal = profile.goalType?.rawValue { properties["goal"] = goal }
            if let sex = profile.sex?.rawValue { properties["sex"] = sex }
            if let activity = profile.activityLevel?.rawValue { properties["activity_level"] = activity }
        }
        Analytics.tracker.setUserProperties(properties)
    }

    func handleSceneDidBecomeActive() {
        guard didShowMain else { return }
        presentPendingBadgeUnlocks()
        appRatingPrompt.presentIfNeeded()
    }

    private func presentPendingBadgeUnlocks() {
        #if DEBUG
        if QALaunchConfiguration.isActive { return }
        #endif
        let progress = (try? container.evaluateBadgesUseCase.execute()) ?? []
        let seen = (try? container.fetchRewardStateUseCase.execute())?.seenBadgeIDs ?? []
        let unseen = BadgeProgress.awaitingCelebration(in: progress.filter(\.isComplete), seenIDs: seen)
        badgeUnlockPresenter.present(unseen)
    }

    private func bindBadgeUnlocks(host: UIViewController) {
        badgeUnlockPresenter.attach(host: host)
        container.evaluateBadgesUseCase.onNewlyUnlocked = { [weak self] badges in
            DispatchQueue.main.async {
                self?.badgeUnlockPresenter.present(badges)
            }
        }
    }

    private func setRoot(_ viewController: UIViewController) {
        guard window.rootViewController != nil else {
            window.rootViewController = viewController
            return
        }
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: {
            self.window.rootViewController = viewController
        })
    }
}
