import UIKit
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?
    private var container: DIContainer?
    private let analyticsLifecycle = AnalyticsLifecycle()
    private var isColdStart = true

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let container = DIContainer()
        #if DEBUG
        QASession.prepare(container: container)
        #endif
        let coordinator = AppCoordinator(window: window, container: container)
        self.window = window
        self.container = container
        self.appCoordinator = coordinator
        AppAppearance.apply(container.appSettingsStore.settings.appearanceMode)
        coordinator.start()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        guard let container else { return }
        let profile = try? container.fetchOnboardingStateUseCase.execute()
        analyticsLifecycle.appWillEnterForeground(
            isColdStart: isColdStart,
            isExistingUser: profile?.onboardingCompleted ?? false,
            snapshot: container.analyticsUserSnapshot()
        )
        isColdStart = false
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            Analytics.tracker.setUserProperties([
                "notifications_enabled": settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            ])
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        analyticsLifecycle.appDidEnterBackground()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        container?.reminderScheduleController.refreshOnForeground()
        container?.healthSyncController.refreshOnForeground()
        appCoordinator?.handleSceneDidBecomeActive()
    }
}
