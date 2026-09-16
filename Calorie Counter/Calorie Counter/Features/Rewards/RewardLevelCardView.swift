import UIKit

final class RewardLevelCardView: UIView {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var unlockedLabel: AdaptiveLabel!
    @IBOutlet private weak var meterView: RewardMeterBarView!
    @IBOutlet private weak var xpLabel: AdaptiveLabel!
    @IBOutlet private weak var xpTopConstraint: AdaptiveConstraint!
    @IBOutlet private weak var xpBottomConstraint: AdaptiveConstraint!
    @IBOutlet private weak var meterBottomConstraint: AdaptiveConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ state: RewardsScreenState) {
        titleLabel.text = state.levelTitle
        unlockedLabel.text = state.unlockedText
        let hasXP = !state.xpText.isEmpty
        xpLabel.text = hasXP ? state.xpText : nil
        xpLabel.isHidden = !hasXP
        xpTopConstraint.isActive = hasXP
        xpBottomConstraint.isActive = hasXP
        meterBottomConstraint.isActive = !hasXP
        meterView.progress = CGFloat(state.levelFill)
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(unlockedLabel, size: 15, weight: .regular, color: AppColor.iconSecondary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(xpLabel, size: 13, weight: .regular, color: AppColor.labelsPrimary, kern: -0.08)
        titleLabel.applyWrapping()
        unlockedLabel.applyWrapping()
        xpLabel.applyWrapping()
        titleLabel.enableDynamicType(baseFont: .systemFont(ofSize: 17, weight: .semibold))
        unlockedLabel.enableDynamicType(baseFont: .systemFont(ofSize: 15))
        xpLabel.enableDynamicType(baseFont: .systemFont(ofSize: 13), textStyle: .footnote)
        applyCardShadow()
        superview?.layoutIfNeeded()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        xpLabel.setContentHuggingPriority(.required, for: .vertical)
        xpLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        guard let card = subviews.first else { return }
        card.constraints.filter {
            ($0.firstItem === meterView && $0.firstAttribute == .top)
                || ($0.firstItem === unlockedLabel && $0.firstAttribute == .centerY)
        }.forEach { $0.priority = .defaultHigh }
        NSLayoutConstraint.activate([
            unlockedLabel.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 16),
            meterView.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 16),
            meterView.topAnchor.constraint(greaterThanOrEqualTo: unlockedLabel.bottomAnchor, constant: 16)
        ])
    }

    private func applyCardShadow() {
        layer.cornerRadius = .adaptWidth(24)
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 3, height: 4)
    }
}
