import UIKit

final class AIChatAssistantBubbleView: UIView {
    @IBOutlet private weak var avatarView: UIImageView!
    @IBOutlet private weak var bubbleView: AdaptiveView!
    @IBOutlet private weak var messageLabel: AdaptiveLabel!
    @IBOutlet private weak var dotsStack: AdaptiveStackView!
    @IBOutlet private weak var avatarWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var avatarHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bubbleAvatarSpacingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bubbleLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bubbleTopConstraint: NSLayoutConstraint!

    private var bubbleCenterYConstraint: NSLayoutConstraint?
    private var isTyping = false
    private var isPulseAnimating = false
    private var pulseBounds: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(text: String, showsAvatar: Bool = true) {
        isTyping = false
        stopTypingAnimation()
        dotsStack.isHidden = true
        messageLabel.isHidden = false
        messageLabel.text = text
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left
        OnboardingStyle.lockFigmaFont(
            messageLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        // Bity writes Markdown; shown as is, the reply was littered with ** and ###.
        messageLabel.attributedText = ChatMarkdownRenderer.attributed(
            text,
            style: .init(font: .systemFont(ofSize: 17, weight: .regular), color: AppColor.labelsPrimary, kern: -0.43)
        )
        messageLabel.accessibilityLabel = messageLabel.attributedText?.string
        applyBubbleChrome()
        applyAvatar(visible: showsAvatar)
        applyTypingAlignment(false)
        applyMessageWidth()
        invalidateIntrinsicContentSize()
    }

    func configureTyping() {
        isTyping = true
        messageLabel.isHidden = true
        messageLabel.text = nil
        dotsStack.isHidden = false
        applyBubbleChrome()
        applyAvatar(visible: true)
        applyTypingAlignment(true)
        prepareDotHosts()
        startTypingAnimation()
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarView.layer.cornerRadius = 0
        if messageLabel.isHidden == false {
            applyMessageWidth()
        }
        if isTyping {
            layoutPulseLayers()
            startTypingAnimation()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        isPulseAnimating = false
        if window != nil, isTyping {
            startTypingAnimation()
        } else {
            stopTypingAnimation()
        }
    }

    private func applyBubbleChrome() {
        bubbleView.backgroundColor = OnboardingStyle.fillQuaternary
        bubbleView.applyCardShadow = false
        bubbleView.useLiveGlass = false
        bubbleView.setContentHuggingPriority(.required, for: .horizontal)
        bubbleView.setContentHuggingPriority(.required, for: .vertical)
        messageLabel.setContentHuggingPriority(.required, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        dotsStack.clipsToBounds = false
        dotsStack.setContentHuggingPriority(.required, for: .horizontal)
        dotsStack.setContentHuggingPriority(.required, for: .vertical)
        dotsStack.setContentCompressionResistancePriority(.required, for: .vertical)
        (dotsStack.superview as? UIStackView)?.alignment = isTyping ? .center : .leading
    }

    private func applyTypingAlignment(_ typing: Bool) {
        if bubbleCenterYConstraint == nil {
            let constraint = bubbleView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor)
            constraint.priority = .required
            bubbleCenterYConstraint = constraint
        }
        bubbleTopConstraint.isActive = !typing
        bubbleCenterYConstraint?.isActive = typing
    }

    private func applyMessageWidth() {
        messageLabel.preferredMaxLayoutWidth = .adaptWidth(258)
    }

    private func applyAvatar(visible: Bool) {
        avatarView.image = UIImage(named: "BityAIAssistant")?.withRenderingMode(.alwaysOriginal)
        avatarView.backgroundColor = .clear
        avatarView.contentMode = .scaleAspectFit
        avatarView.clipsToBounds = false
        avatarView.layer.masksToBounds = false
        avatarView.layer.cornerRadius = 0
        avatarView.isHidden = !visible
        avatarView.alpha = visible ? 1 : 0
        avatarWidthConstraint.isActive = visible
        avatarHeightConstraint.isActive = visible
        bubbleAvatarSpacingConstraint.isActive = visible
        bubbleLeadingConstraint.priority = visible ? UILayoutPriority(1) : .required
        avatarView.setContentHuggingPriority(.required, for: .horizontal)
        avatarView.setContentCompressionResistancePriority(.required, for: .horizontal)
        avatarView.setContentHuggingPriority(.required, for: .vertical)
        avatarView.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func prepareDotHosts() {
        dotsStack.arrangedSubviews.forEach { host in
            host.backgroundColor = .clear
            host.clipsToBounds = false
            host.layer.masksToBounds = false
            _ = pulseLayer(in: host)
        }
    }

    private func pulseLayer(in host: UIView) -> CALayer {
        if let existing = host.layer.sublayers?.first(where: { $0.name == Self.pulseLayerName }) {
            return existing
        }
        let layer = CALayer()
        layer.name = Self.pulseLayerName
        layer.contentsScale = UIScreen.main.scale
        host.layer.addSublayer(layer)
        return layer
    }

    private func layoutPulseLayers() {
        let color = AppColor.labelsSecondary.resolvedColor(with: traitCollection).cgColor
        dotsStack.arrangedSubviews.forEach { host in
            let pulse = pulseLayer(in: host)
            pulse.backgroundColor = color
            pulse.cornerCurve = .continuous
            pulse.cornerRadius = min(host.bounds.width, host.bounds.height) / 2
            if pulse.animation(forKey: Self.bounceKey) == nil {
                pulse.frame = host.bounds
                pulse.opacity = 0.35
            } else {
                pulse.bounds.size = host.bounds.size
            }
        }
    }

    private func startTypingAnimation() {
        guard isTyping, window != nil else { return }
        let hosts = dotsStack.arrangedSubviews
        guard let sample = hosts.first, sample.bounds.width > 0, sample.bounds.height > 0 else { return }
        if isPulseAnimating, sample.bounds.size == pulseBounds {
            return
        }
        stopPulseAnimations()
        pulseBounds = sample.bounds.size
        isPulseAnimating = true
        layoutPulseLayers()
        let travel = CGFloat.adaptHeight(4)
        let now = CACurrentMediaTime()
        for (index, host) in hosts.enumerated() {
            let pulse = pulseLayer(in: host)
            pulse.frame = host.bounds
            pulse.opacity = 0.35
            let delay = 0.14 * Double(index)

            let bounce = CABasicAnimation(keyPath: "position.y")
            bounce.fromValue = host.bounds.midY
            bounce.toValue = host.bounds.midY - travel
            bounce.duration = 0.42
            bounce.beginTime = now + delay
            bounce.autoreverses = true
            bounce.repeatCount = .infinity
            bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bounce.isRemovedOnCompletion = false
            bounce.fillMode = .backwards

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.35
            fade.toValue = 1
            fade.duration = 0.42
            fade.beginTime = now + delay
            fade.autoreverses = true
            fade.repeatCount = .infinity
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            fade.isRemovedOnCompletion = false
            fade.fillMode = .backwards

            pulse.add(bounce, forKey: Self.bounceKey)
            pulse.add(fade, forKey: Self.fadeKey)
        }
    }

    private func stopTypingAnimation() {
        isPulseAnimating = false
        pulseBounds = .zero
        stopPulseAnimations()
    }

    private func stopPulseAnimations() {
        dotsStack.arrangedSubviews.forEach { host in
            guard let pulse = host.layer.sublayers?.first(where: { $0.name == Self.pulseLayerName }) else { return }
            pulse.removeAllAnimations()
            pulse.transform = CATransform3DIdentity
            pulse.opacity = isTyping ? 0.35 : 1
            pulse.frame = host.bounds
        }
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        embedNibContent()
        dotsStack.isHidden = true
    }

    private static let pulseLayerName = "typingPulse"
    private static let bounceKey = "typingBounce"
    private static let fadeKey = "typingFade"
}
