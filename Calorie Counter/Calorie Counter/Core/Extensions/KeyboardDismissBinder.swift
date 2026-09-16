import UIKit

final class KeyboardDismissBinder: NSObject, UIGestureRecognizerDelegate {
    private weak var hostView: UIView?
    private var excludedViews: () -> [UIView] = { [] }

    func attach(to viewController: UIViewController, excluding views: @escaping () -> [UIView] = { [] }) {
        hostView = viewController.view
        excludedViews = views
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        viewController.view.addGestureRecognizer(tap)
        refreshScrollViews(in: viewController.view)
    }

    func refreshScrollViews(in root: UIView) {
        if let scroll = root as? UIScrollView, scroll.keyboardDismissMode == .none {
            scroll.keyboardDismissMode = .onDrag
        }
        root.subviews.forEach { refreshScrollViews(in: $0) }
    }

    @objc
    private func dismissKeyboard() {
        hostView?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        shouldDismissKeyboard(for: touch.view)
    }

    func shouldDismissKeyboard(for view: UIView?) -> Bool {
        if let view, excludedViews().contains(where: { view.isDescendant(of: $0) }) {
            return false
        }
        var hit = view
        while let current = hit {
            if current is UITextField || current is UITextView {
                return false
            }
            hit = current.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
