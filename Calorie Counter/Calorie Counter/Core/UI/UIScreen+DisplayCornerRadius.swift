import UIKit

extension UIScreen {
    var displayCornerRadius: CGFloat {
        (value(forKey: "displayCornerRadius") as? CGFloat) ?? 0
    }
}
