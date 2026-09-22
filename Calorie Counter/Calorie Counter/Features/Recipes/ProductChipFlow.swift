import UIKit

final class ProductChipButton: UIButton {
    override var intrinsicContentSize: CGSize {
        let title = attributedTitle(for: .normal) ?? NSAttributedString(string: currentTitle ?? "")
        let titleSize = title.size()
        let imageWidth = image(for: .normal)?.size.width ?? 0
        let imageHeight = image(for: .normal)?.size.height ?? 0
        let imagePad: CGFloat = imageWidth > 0 ? (imageEdgeInsets.left + imageEdgeInsets.right) : 0
        let width = contentEdgeInsets.left
            + ceil(titleSize.width)
            + imagePad
            + ceil(imageWidth)
            + contentEdgeInsets.right
        let height = contentEdgeInsets.top
            + ceil(max(titleSize.height, imageHeight))
            + contentEdgeInsets.bottom
        return CGSize(width: ceil(width) + 2, height: ceil(height))
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let intrinsic = intrinsicContentSize
        return CGSize(
            width: min(intrinsic.width, size.width > 0 ? size.width : intrinsic.width),
            height: intrinsic.height
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

enum ProductChipFlow {
    static func wrap(
        widths: [CGFloat],
        maxWidth: CGFloat,
        spacing: CGFloat
    ) -> [[Int]] {
        guard maxWidth > 0, !widths.isEmpty else { return [] }
        var rows: [[Int]] = []
        var current: [Int] = []
        var used: CGFloat = 0
        widths.enumerated().forEach { index, natural in
            let width = min(natural, maxWidth)
            if !current.isEmpty, used + spacing + width > maxWidth {
                rows.append(current)
                current = []
                used = 0
            }
            current.append(index)
            used += current.count == 1 ? width : spacing + width
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }

    static func fittedWidth(_ button: UIButton) -> CGFloat {
        button.invalidateIntrinsicContentSize()
        return ceil(max(1, button.intrinsicContentSize.width))
    }

    static func makeChip(title: String, action: @escaping () -> Void) -> UIButton {
        let button = ProductChipButton(type: .system)
        button.configuration = nil
        button.translatesAutoresizingMaskIntoConstraints = false
        let font = UIFont.systemFont(ofSize: .adaptFont(13), weight: .regular)
        let color = UIColor.white
        button.setAttributedTitle(
            NSAttributedString(
                string: title,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .kern: -0.08
                ]
            ),
            for: .normal
        )
        button.setTitle(title, for: .normal)
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = font
        button.titleLabel?.adjustsFontSizeToFitWidth = false
        button.titleLabel?.lineBreakMode = .byClipping
        button.titleLabel?.numberOfLines = 1
        button.setImage(
            UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            ),
            for: .normal
        )
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        button.tintColor = color
        button.backgroundColor = .black
        // The cross keeps the same distance from the edge as the text does on the other side.
        button.contentEdgeInsets = UIEdgeInsets(
            top: .adaptHeight(7),
            left: .adaptWidth(12),
            bottom: .adaptHeight(7),
            right: .adaptWidth(12)
        )
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        button.accessibilityIdentifier = title
        button.adjustsImageWhenHighlighted = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        button.heightAnchor.constraint(equalToConstant: .adaptHeight(34)).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
}
