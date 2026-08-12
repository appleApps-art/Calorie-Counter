import UIKit

extension UIView {
    func refreshAdaptiveLayout() {
        constraints.compactMap { $0 as? AdaptiveConstraint }.forEach { $0.refreshConstant() }

        if let stackView = self as? AdaptiveStackView {
            stackView.refreshSpacing()
        }

        subviews.forEach { $0.refreshAdaptiveLayout() }
    }
}
