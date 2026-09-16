import UIKit

final class NutritionMicroCardView: UIView {
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
        OnboardingStyle.lockFigmaFont(titleLabel, size: 13, weight: .regular, color: AppColor.iconSecondary, kern: -0.08)
        OnboardingStyle.lockFigmaFont(valueLabel, size: 13, weight: .regular, color: AppColor.labelsPrimary, kern: -0.08)
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        if let card = subviews.first as? AdaptiveView {
            card.useLiveGlass = false
            card.applyCardShadow = true
        }
    }
}
