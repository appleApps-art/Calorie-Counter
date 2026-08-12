import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?
    private var container: DIContainer?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let container = DIContainer()
        let coordinator = AppCoordinator(window: window, container: container)
        self.window = window
        self.container = container
        self.appCoordinator = coordinator
        coordinator.start()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        container?.reminderScheduleController.refreshOnForeground()
    }
}
