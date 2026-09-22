import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private let container: DIContainer
    private var tabBarController: MainTabBarController?
    private var onboardingCoordinator: OnboardingFlowCoordinator?
    private var didShowMain = false
    private var backgroundedAt: Date?
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
        PremiumPrompt.makeCoordinator = { [container] in container.makeSubscriptionCoordinator() }
        PremiumPrompt.featureAccess = container.featureAccess
        #if DEBUG
        switch QALaunchConfiguration.freeUsage {
        case "exhausted": container.featureAccess.exhaustFreeUses()
        case "fresh": container.featureAccess.resetFreeUses()
        default: break
        }
        #endif
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
            showMain(offersPaywall: true)
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

    /// `offersPaywall` is for opening the app; right after onboarding its own paywall was just seen.
    private func showMain(offersPaywall: Bool = false) {
        guard !didShowMain else { return }
        didShowMain = true
        onboardingCoordinator = nil
        let tabBarController = MainTabBarController(container: container)
        self.tabBarController = tabBarController
        bindBadgeUnlocks(host: tabBarController)
        appRatingPrompt.attach(host: tabBarController)
        Analytics.hub.appRatingPrompt = appRatingPrompt
        // The paywall goes up inside the same crossfade, so the splash dissolves straight into it.
        setRoot(tabBarController) { [weak self] in
            if offersPaywall {
                self?.offerPaywall(over: tabBarController, animated: false)
            }
        }
        NotificationAnalyticsDelegate.shared.onOpenReminder = { [weak tabBarController] kind in
            tabBarController?.openReminder(kind)
        }
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

    func handleSceneDidEnterBackground() {
        backgroundedAt = Date()
    }

    func handleSceneDidBecomeActive() {
        guard didShowMain else { return }
        if let backgroundedAt, Date().timeIntervalSince(backgroundedAt) >= Self.reopenInterval,
           let tabBarController, tabBarController.presentedViewController == nil {
            offerPaywall(over: tabBarController, animated: true)
        }
        backgroundedAt = nil
        presentPendingBadgeUnlocks()
        appRatingPrompt.presentIfNeeded()
    }

    /// Coming back after this long counts as opening the app again.
    private static let reopenInterval: TimeInterval = 30 * 60

    /// Without Premium, opening the app starts on the paywall; closing it reveals the app.
    private func offerPaywall(over host: UIViewController, animated: Bool) {
        #if DEBUG
        if QALaunchConfiguration.isActive { return }
        #endif
        guard !container.subscriptionService.currentStatus().isPremium else { return }
        container.makeSubscriptionCoordinator().presentPaywall(from: host, placement: .main, animated: animated)
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

    private func setRoot(_ viewController: UIViewController, alongside: (() -> Void)? = nil) {
        guard window.rootViewController != nil else {
            window.rootViewController = viewController
            alongside?()
            return
        }
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: {
            self.window.rootViewController = viewController
            alongside?()
        })
    }
}
