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
        giftImageView.image = OnboardingStyle.symbol("gift", pointSize: 17, weight: .regular)?.withTintColor(
            AppColor.iconSecondary,
            renderingMode: .alwaysOriginal
        )
        // Callout in the design: 16 pt for both, the reward itself in secondary grey.
        OnboardingStyle.lockFigmaFont(titleLabel, size: 16, weight: .regular, color: AppColor.labelsPrimary, kern: -0.31)
        OnboardingStyle.lockFigmaFont(detailLabel, size: 16, weight: .regular, color: AppColor.labelsSecondary, kern: -0.31)
        titleLabel.applyWrapping()
        detailLabel.applyWrapping()
        titleLabel.enableDynamicType(baseFont: .systemFont(ofSize: 16))
        detailLabel.enableDynamicType(baseFont: .systemFont(ofSize: 16))
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
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            column.addArrangedSubview(tick)
            column.addArrangedSubview(label)
            ticksStackView.addArrangedSubview(column)
        }
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        guard let card = subviews.first else { return }
        (card as? AdaptiveView)?.cardFillColor = AppColor.backgroundsPrimary
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.applyCardShadow()
        }
        NSLayoutConstraint.deactivate(card.constraints.filter {
            $0.firstItem === card && $0.firstAttribute == .height && $0.secondItem == nil
        })
        card.constraints.filter {
            ($0.firstItem === meterView && $0.firstAttribute == .top)
                || (($0.firstItem === titleLabel || $0.firstItem === detailLabel) && $0.firstAttribute == .centerY)
        }.forEach { $0.priority = .defaultHigh }
        // The card hugs its content (151 pt in the design) and grows only with larger text.
        let hug = card.bottomAnchor.constraint(equalTo: ticksStackView.bottomAnchor, constant: 29)
        hug.priority = .init(999)
        // A top-aligned stack is only a lower bound on its height; keep it as short as its tallest day.
        let ticksFit = ticksStackView.heightAnchor.constraint(equalToConstant: 0)
        ticksFit.priority = .init(990)
        NSLayoutConstraint.activate([
            hug,
            ticksFit,
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
        let isDark = traitCollection.userInterfaceStyle == .dark
        layer.shadowOpacity = isDark ? 0.45 : 0.1
        layer.shadowRadius = isDark ? 8 : 4
        layer.shadowOffset = CGSize(width: 3, height: 4)
    }
}
