import UIKit

final class AppNavigationController: UINavigationController, UIGestureRecognizerDelegate, UINavigationControllerDelegate {
    var dismissesWhenPoppedToRoot = false

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        restorePopGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        restorePopGesture()
    }

    override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        super.setNavigationBarHidden(hidden, animated: animated)
        restorePopGesture()
    }

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        (tabBarController as? MainTabBarController)?.refreshTabBarChrome(for: viewController)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        restorePopGesture()
        (tabBarController as? MainTabBarController)?.refreshTabBarChrome(for: viewController)
        guard dismissesWhenPoppedToRoot,
              viewControllers.count <= 1,
              presentingViewController != nil else { return }
        dismiss(animated: false)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === interactivePopGestureRecognizer
    }

    private func restorePopGesture() {
        interactivePopGestureRecognizer?.isEnabled = true
        interactivePopGestureRecognizer?.delegate = self
    }
}
