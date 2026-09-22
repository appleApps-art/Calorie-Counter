import UIKit

/// Puts one section of a screen into its own scroll view, leaving the heading and the buttons
/// where they are. The section keeps the constraints it was laid out with.
enum ScrollSectionLayout {
    @discardableResult
    static func wrap(_ section: UIView) -> UIScrollView? {
        guard let parent = section.superview else { return nil }
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.accessibilityIdentifier = "flow.section.scroll"
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = false
        scroll.contentInsetAdjustmentBehavior = .never

        let related = parent.constraints.filter { $0.firstItem === section || $0.secondItem === section }
        NSLayoutConstraint.deactivate(related)
        section.removeFromSuperview()
        parent.addSubview(scroll)
        scroll.addSubview(section)

        let remapped = related.map { original -> NSLayoutConstraint in
            func item(_ value: AnyObject?) -> AnyObject? { value === section ? scroll : value }
            let replacement: NSLayoutConstraint
            if let original = original as? AdaptiveConstraint {
                let made = AdaptiveConstraint(
                    item: item(original.firstItem)!, attribute: original.firstAttribute,
                    relatedBy: original.relation,
                    toItem: item(original.secondItem), attribute: original.secondAttribute,
                    multiplier: original.multiplier, constant: original.constant
                )
                made.adaptToWidth = original.adaptToWidth
                made.adaptToHeight = original.adaptToHeight
                made.designConstant = original.designConstant
                replacement = made
            } else {
                replacement = NSLayoutConstraint(
                    item: item(original.firstItem)!, attribute: original.firstAttribute,
                    relatedBy: original.relation,
                    toItem: item(original.secondItem), attribute: original.secondAttribute,
                    multiplier: original.multiplier, constant: original.constant
                )
            }
            replacement.priority = original.priority
            replacement.identifier = original.identifier
            return replacement
        }

        NSLayoutConstraint.activate(remapped + [
            section.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            section.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            section.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            section.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            section.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        return scroll
    }
}
