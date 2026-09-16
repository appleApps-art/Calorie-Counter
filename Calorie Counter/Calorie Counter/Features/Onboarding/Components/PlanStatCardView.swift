import UIKit

final class PlanStatCardView: UIView {
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var valueLabel: AdaptiveLabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
        OnboardingStyle.lockFigmaFont(titleLabel, size: 16, weight: .regular, color: AppColor.textSecondary, kern: -0.31)
        OnboardingStyle.lockFigmaFont(valueLabel, size: 22, weight: .regular, color: AppColor.textPrimary, kern: -0.26)
        titleLabel.applyWrapping()
        valueLabel.applyWrapping()
        titleLabel.enableDynamicType(baseFont: .systemFont(ofSize: 16))
        valueLabel.enableDynamicType(baseFont: .systemFont(ofSize: 22))
        titleLabel.textAlignment = .center
        valueLabel.textAlignment = .center
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        embedNibContent()
        subviews.first?.clipsToBounds = false
        cardView.useLiveGlass = false
        titleLabel.textColor = AppColor.textSecondary
        valueLabel.textColor = AppColor.textPrimary
        if let stack = titleLabel.superview as? UIStackView {
            stack.alignment = .fill
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 12),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12)
            ])
        }
    }
}
