import UIKit

final class AdaptiveLabel: UILabel {
    private var storedDesignFontSize: CGFloat?
    private var dynamicBaseFont: UIFont?

    @IBInspectable var adaptFontSize: Bool = true {
        didSet { refreshFont() }
    }

    /// Opt in on labels whose surrounding layout can grow or scroll with larger text.
    @IBInspectable var usesDynamicType: Bool = false {
        didSet { refreshFont() }
    }

    var dynamicTextStyle: UIFont.TextStyle = .body {
        didSet { refreshFont() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        storedDesignFontSize = font?.pointSize
        refreshFont()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshFont()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshFont()
    }

    /// Call after styling a label whose container can expand or scroll with larger text.
    /// Existing color, kerning, alignment and font weights in attributed text are preserved.
    func enableDynamicType(baseFont: UIFont? = nil, textStyle: UIFont.TextStyle = .body) {
        let attributedFont: UIFont?
        if let attributedText, attributedText.length > 0 {
            attributedFont = attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        } else {
            attributedFont = nil
        }
        let base = baseFont ?? attributedFont ?? font ?? .preferredFont(forTextStyle: textStyle)
        dynamicBaseFont = base
        storedDesignFontSize = base.pointSize
        dynamicTextStyle = textStyle
        adaptFontSize = true
        usesDynamicType = true
    }

    func refreshFont() {
        guard !DesignMetrics.isInterfaceBuilder else { return }
        guard adaptFontSize else {
            adjustsFontForContentSizeCategory = false
            return
        }
        guard let currentFont = font else { return }
        let designSize = storedDesignFontSize ?? currentFont.pointSize
        storedDesignFontSize = designSize
        let baseFont = (dynamicBaseFont ?? currentFont).withSize(.adaptFont(designSize))
        let resolvedFont = usesDynamicType
            ? UIFontMetrics(forTextStyle: dynamicTextStyle).scaledFont(for: baseFont, compatibleWith: traitCollection)
            : baseFont
        adjustsFontForContentSizeCategory = usesDynamicType
        let attributed = attributedText
        if font != resolvedFont { font = resolvedFont }
        if usesDynamicType, let attributed, attributed.length > 0 {
            let updated = NSMutableAttributedString(attributedString: attributed)
            attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length)) { value, range, _ in
                let styledBase = (value as? UIFont ?? baseFont).withSize(designSize)
                let scaled = UIFontMetrics(forTextStyle: self.dynamicTextStyle).scaledFont(for: styledBase, compatibleWith: self.traitCollection)
                updated.addAttribute(.font, value: scaled, range: range)
            }
            if !updated.isEqual(to: attributedText ?? NSAttributedString(string: "")) {
                attributedText = updated
            }
        }
    }
}

extension UILabel {
    func applyLineTruncation(lines: Int) {
        (self as? AdaptiveLabel)?.adaptFontSize = false
        numberOfLines = lines
        lineBreakMode = .byTruncatingTail
        adjustsFontSizeToFitWidth = false
        minimumScaleFactor = 1
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        guard let attributed = attributedText, attributed.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = lines == 1 ? .byTruncatingTail : .byWordWrapping
        paragraph.alignment = textAlignment
        mutable.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: 0, length: mutable.length)
        )
        attributedText = mutable
        textAlignment = paragraph.alignment
    }

    func applyWrapping() {
        (self as? AdaptiveLabel)?.adaptFontSize = false
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
        adjustsFontSizeToFitWidth = false
        minimumScaleFactor = 1
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        guard let attributed = attributedText, attributed.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment
        paragraph.lineBreakMode = .byWordWrapping
        mutable.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: 0, length: mutable.length)
        )
        attributedText = mutable
        textAlignment = paragraph.alignment
    }
}
