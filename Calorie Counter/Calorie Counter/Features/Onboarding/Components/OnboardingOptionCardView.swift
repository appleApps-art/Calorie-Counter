import UIKit

final class OnboardingOptionCardView: UIControl {
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var checkImageView: UIImageView!

    private var cardHeightConstraint: NSLayoutConstraint?

    override var isSelected: Bool {
        didSet { updateSelection() }
    }

    override var isHighlighted: Bool {
        didSet { updateHighlight() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(icon: String, title: String, subtitle: String?) {
        iconImageView.image = OnboardingStyle.symbol(icon, pointSize: 17)
        iconImageView.tintColor = AppColor.footerLabel
        titleLabel.text = title
        OnboardingStyle.lockFigmaFont(titleLabel, size: 22, weight: .regular, color: AppColor.textPrimary, kern: -0.26)
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = (subtitle == nil)
        OnboardingStyle.lockFigmaFont(subtitleLabel, size: 15, weight: .regular, color: AppColor.textSecondary, kern: -0.23)
        titleLabel.applyWrapping()
        subtitleLabel.applyWrapping()
        titleLabel.enableDynamicType(baseFont: .systemFont(ofSize: 22))
        subtitleLabel.enableDynamicType(baseFont: .systemFont(ofSize: 15))
        let height: CGFloat = subtitle == nil ? 69 : 113
        if let cardHeightConstraint {
            cardHeightConstraint.constant = height
        } else {
            let constraint = heightAnchor.constraint(greaterThanOrEqualToConstant: height)
            constraint.isActive = true
            cardHeightConstraint = constraint
        }
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        embedNibContent()
        subviews.first?.isUserInteractionEnabled = false
        subviews.first?.clipsToBounds = false
        cardView.useLiveGlass = false
        if let textStack = titleLabel.superview as? UIStackView {
            textStack.alignment = .fill
            NSLayoutConstraint.activate([
                textStack.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 16),
                textStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -16)
            ])
        }
        checkImageView.image = OnboardingStyle.symbol("checkmark", pointSize: 20)
        checkImageView.tintColor = AppColor.teal
        titleLabel.textColor = AppColor.textPrimary
        subtitleLabel.textColor = AppColor.textSecondary
        updateSelection()
    }

    private func updateSelection() {
        checkImageView.isHidden = !isSelected
    }

    private func updateHighlight() {
        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }
}
