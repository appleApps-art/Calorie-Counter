import UIKit

extension UICalendarView {
    /// iOS 26 caps a month page at about 400 pt and lays the neighbouring months out beside it
    /// when the calendar is wider, as it is on iPad. There the calendar keeps to one page, centred;
    /// phones are narrower than a page and keep filling their card.
    static var maximumMonthWidth: CGFloat? {
        UIDevice.current.userInterfaceIdiom == .pad ? 400 : nil
    }

    /// Horizontal constraints that fill `container` minus `inset` on each side, up to one month.
    func horizontalConstraints(in container: UIView, inset: CGFloat) -> [NSLayoutConstraint] {
        guard let maximum = Self.maximumMonthWidth else {
            return [
                leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
                trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset)
            ]
        }
        let fill = widthAnchor.constraint(equalTo: container.widthAnchor, constant: -2 * inset)
        fill.priority = .defaultHigh
        return [
            centerXAnchor.constraint(equalTo: container.centerXAnchor),
            leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: inset),
            widthAnchor.constraint(lessThanOrEqualToConstant: maximum),
            fill
        ]
    }

    /// The frame for a calendar laid out by hand in `bounds`, under the same one-month limit.
    static func frame(in bounds: CGRect) -> CGRect {
        guard let maximum = maximumMonthWidth, bounds.width > maximum else { return bounds }
        return CGRect(x: bounds.midX - maximum / 2, y: bounds.minY, width: maximum, height: bounds.height)
    }
}
