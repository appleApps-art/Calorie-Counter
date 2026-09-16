import UIKit

final class AIChatUserBubbleView: UIView {
    @IBOutlet private weak var bubbleView: AdaptiveView!
    @IBOutlet private weak var messageLabel: AdaptiveLabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(text: String, alignment: NSTextAlignment = .left) {
        messageLabel.text = text
        messageLabel.numberOfLines = 0
        OnboardingStyle.lockFigmaFont(
            messageLabel,
            size: 17,
            weight: .regular,
            color: AppColor.onAccent,
            kern: -0.43
        )
        messageLabel.textAlignment = alignment
        bubbleView.backgroundColor = AppColor.teal
        bubbleView.applyCardShadow = false
        bubbleView.setContentHuggingPriority(.required, for: .horizontal)
        bubbleView.setContentCompressionResistancePriority(.required, for: .horizontal)
        messageLabel.setContentHuggingPriority(.required, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyMessageWidth()
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyMessageWidth()
    }

    private func applyMessageWidth() {
        messageLabel.preferredMaxLayoutWidth = .adaptWidth(238)
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
    }
}
