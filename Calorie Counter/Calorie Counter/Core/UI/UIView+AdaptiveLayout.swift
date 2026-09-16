import UIKit

extension UIView {
    func refreshAdaptiveLayout() {
        constraints.compactMap { $0 as? AdaptiveConstraint }.forEach { $0.refreshConstant(in: self) }

        if let stackView = self as? AdaptiveStackView {
            stackView.refreshSpacing()
        }

        if let label = self as? AdaptiveLabel {
            label.refreshFont()
        }

        subviews.forEach { $0.refreshAdaptiveLayout() }
    }

    /// A centered, readable column which remains fluid in a narrow iPad window or on iPhone.
    func makeReadableContentGuide(maximumWidth: CGFloat = 760, horizontalInset: CGFloat = 16) -> UILayoutGuide {
        let guide = UILayoutGuide()
        addLayoutGuide(guide)
        let preferredWidth = guide.widthAnchor.constraint(
            equalTo: safeAreaLayoutGuide.widthAnchor,
            constant: -horizontalInset * 2
        )
        preferredWidth.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            guide.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            guide.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: horizontalInset),
            guide.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -horizontalInset),
            guide.widthAnchor.constraint(lessThanOrEqualToConstant: maximumWidth),
            guide.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            guide.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            preferredWidth
        ])
        return guide
    }
}

extension UIScrollView {
    func pinFilledContent(_ content: UIView, hugHeight: Bool = false) {
        let owned = constraints.filter { constraint in
            constraint.firstItem === content || constraint.secondItem === content
        }
        NSLayoutConstraint.deactivate(owned)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor)
        ])
        if hugHeight {
            let hug = heightAnchor.constraint(equalTo: content.heightAnchor)
            hug.priority = UILayoutPriority(999)
            hug.isActive = true
            alwaysBounceVertical = false
        }
    }
}
