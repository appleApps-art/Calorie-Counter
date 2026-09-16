import UIKit

/// Keeps a flow's existing vertical layout, allowing its content to grow on short windows.
enum FlowScrollLayout {
    @discardableResult
    static func install(in root: UIView, keepingBackgrounds backgrounds: [UIView] = []) -> UIScrollView {
        enableReadableText(in: root)
        let content = UIView()
        content.accessibilityIdentifier = "flow.scroll.content"
        let scroll = UIScrollView()
        scroll.accessibilityIdentifier = "flow.scroll"
        scroll.alwaysBounceVertical = false
        scroll.keyboardDismissMode = .interactive
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.showsHorizontalScrollIndicator = false
        let moving = root.subviews.filter { view in !backgrounds.contains(where: { $0 === view }) }
        func belongsToContent(_ item: AnyObject?) -> Bool {
            guard let view = (item as? UIView) ?? (item as? UILayoutGuide)?.owningView else { return false }
            return moving.contains { view === $0 || view.isDescendant(of: $0) }
        }
        let constraints = root.constraints.filter { constraint in
            // UIKit also owns constraints connecting the root to its safe-area guide.
            // Those stay on the root; only relationships involving moved content are remapped.
            belongsToContent(constraint.firstItem) || belongsToContent(constraint.secondItem)
        }
        NSLayoutConstraint.deactivate(constraints)
        let safeArea = root.safeAreaLayoutGuide
        func remap(_ item: AnyObject?) -> AnyObject? {
            guard let item else { return nil }
            return item === root || item === safeArea ? content : item
        }
        let contentConstraints = constraints.map { original -> NSLayoutConstraint in
            let replacement: NSLayoutConstraint
            if original is AdaptiveConstraint {
                replacement = AdaptiveConstraint(
                    item: remap(original.firstItem)!, attribute: original.firstAttribute,
                    relatedBy: original.relation,
                    toItem: remap(original.secondItem), attribute: original.secondAttribute,
                    multiplier: original.multiplier, constant: original.constant
                )
            } else {
                replacement = NSLayoutConstraint(
                    item: remap(original.firstItem)!, attribute: original.firstAttribute,
                    relatedBy: original.relation,
                    toItem: remap(original.secondItem), attribute: original.secondAttribute,
                    multiplier: original.multiplier, constant: original.constant
                )
            }
            replacement.priority = original.priority
            replacement.identifier = original.identifier
            if let original = original as? AdaptiveConstraint,
               let replacement = replacement as? AdaptiveConstraint {
                replacement.adaptToWidth = original.adaptToWidth
                replacement.adaptToHeight = original.adaptToHeight
                replacement.designConstant = original.designConstant
            }
            return replacement
        }
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scroll)
        scroll.addSubview(content)
        moving.forEach(content.addSubview)
        let preferredHeight = content.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        preferredHeight.priority = .init(249)
        let preferredWidth = scroll.widthAnchor.constraint(equalTo: safeArea.widthAnchor)
        preferredWidth.priority = .init(999)
        NSLayoutConstraint.activate(contentConstraints + [
            scroll.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scroll.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            scroll.widthAnchor.constraint(lessThanOrEqualTo: safeArea.widthAnchor),
            scroll.widthAnchor.constraint(lessThanOrEqualToConstant: 640),
            preferredWidth,
            scroll.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),
            preferredHeight
        ])
        return scroll
    }

    private static func enableReadableText(in view: UIView) {
        if let label = view as? AdaptiveLabel, !label.usesDynamicType {
            label.enableDynamicType()
        }
        view.subviews.forEach(enableReadableText)
    }
}
