import UIKit

final class RewardProgressCardView: UIView {
    @IBOutlet private weak var giftImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var detailLabel: AdaptiveLabel!
    @IBOutlet private weak var meterView: RewardMeterBarView!
    @IBOutlet private weak var ticksStackView: UIStackView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ progress: BadgeProgress) {
        titleLabel.text = L10n.tr("rewards.reward")
        detailLabel.text = progress.rewardDetail
        meterView.progress = CGFloat(progress.fill)
        giftImageView.image = OnboardingStyle.symbol("gift", pointSize: 20, weight: .regular)?.withTintColor(
            AppColor.iconSecondary,
            renderingMode: .alwaysOriginal
        )
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(detailLabel, size: 15, weight: .regular, color: AppColor.iconSecondary, kern: -0.23)
        titleLabel.applyWrapping()
        detailLabel.applyWrapping()
        titleLabel.enableDynamicType(baseFont: .systemFont(ofSize: 17))
        detailLabel.enableDynamicType(baseFont: .systemFont(ofSize: 15))
        rebuildTicks(progress)
        applyCardShadow()
    }

    private func rebuildTicks(_ progress: BadgeProgress) {
        ticksStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let filled = min(progress.current, progress.goal)
        for (index, title) in progress.tickLabels.enumerated() {
            let column = UIStackView()
            column.axis = .vertical
            column.alignment = .center
            column.spacing = .adaptHeight(2)

            let tick = UIView()
            tick.backgroundColor = index < filled ? AppColor.labelsPrimary : AppColor.iconSecondary
            tick.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tick.widthAnchor.constraint(equalToConstant: 1),
                tick.heightAnchor.constraint(equalToConstant: .adaptHeight(4))
            ])

            let label = AdaptiveLabel()
            label.text = title
            label.adaptFontSize = false
            OnboardingStyle.lockFigmaFont(
                label,
                size: 11,
                weight: .regular,
                color: index < filled ? AppColor.labelsPrimary : AppColor.iconSecondary,
                kern: 0.06
            )
            column.addArrangedSubview(tick)
            column.addArrangedSubview(label)
            ticksStackView.addArrangedSubview(column)
        }
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        guard let card = subviews.first else { return }
        NSLayoutConstraint.deactivate(card.constraints.filter {
            $0.firstItem === card && $0.firstAttribute == .height && $0.secondItem == nil
        })
        card.constraints.filter {
            ($0.firstItem === meterView && $0.firstAttribute == .top)
                || (($0.firstItem === titleLabel || $0.firstItem === detailLabel) && $0.firstAttribute == .centerY)
        }.forEach { $0.priority = .defaultHigh }
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 151),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 16),
            detailLabel.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 16),
            meterView.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 16),
            meterView.topAnchor.constraint(greaterThanOrEqualTo: detailLabel.bottomAnchor, constant: 16),
            card.bottomAnchor.constraint(greaterThanOrEqualTo: ticksStackView.bottomAnchor, constant: 24)
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
