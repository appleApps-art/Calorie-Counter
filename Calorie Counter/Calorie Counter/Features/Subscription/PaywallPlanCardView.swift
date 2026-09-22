import UIKit

/// One subscription plan: price line, what it means per month or how it bills, a checkmark when
/// chosen and an optional "SAVE N%" chip over the top edge.
final class PaywallPlanCardView: UIControl {
    private let card = AdaptiveView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkView = UIImageView()
    private let badgeView = UIView()
    private let badgeLabel = UILabel()

    private(set) var planID = ""
    var onSelect: ((String) -> Void)?

    init(fillColor: UIColor) {
        super.init(frame: .zero)
        build(fillColor: fillColor)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ plan: PaywallPlanDisplay, selected: Bool) {
        planID = plan.id
        titleLabel.text = plan.title
        subtitleLabel.text = plan.subtitle
        badgeLabel.text = plan.badge
        badgeView.isHidden = plan.badge == nil
        setSelected(selected)
        accessibilityLabel = [plan.title, plan.subtitle, plan.badge].compactMap { $0 }.joined(separator: ", ")
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        checkView.isHidden = !selected
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    private func build(fillColor: UIColor) {
        isAccessibilityElement = true
        card.isUserInteractionEnabled = false
        card.useLiveGlass = false
        card.applyCardShadow = true
        card.cardFillColor = fillColor
        card.adaptCornerRadius = true
        card.designCornerRadius = 24

        titleLabel.font = .systemFont(ofSize: .adaptFont(20), weight: .semibold)
        titleLabel.textColor = AppColor.labelsPrimary
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.textAlignment = .natural
        subtitleLabel.font = .systemFont(ofSize: .adaptFont(16), weight: .regular)
        subtitleLabel.textColor = AppColor.labelsSecondary
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.75
        subtitleLabel.textAlignment = .natural

        checkView.image = OnboardingStyle.symbol("checkmark", pointSize: .adaptFont(20), weight: .regular)?
            .withRenderingMode(.alwaysTemplate)
        checkView.tintColor = AppColor.teal
        checkView.contentMode = .center
        checkView.setContentHuggingPriority(.required, for: .horizontal)
        checkView.setContentCompressionResistancePriority(.required, for: .horizontal)

        badgeView.backgroundColor = AppColor.teal
        badgeView.layer.cornerRadius = .adaptWidth(12)
        badgeView.layer.cornerCurve = .continuous
        badgeView.isUserInteractionEnabled = false
        badgeLabel.font = .systemFont(ofSize: .adaptFont(13), weight: .regular)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center

        let texts = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        texts.axis = .vertical
        texts.spacing = .adaptHeight(6)
        texts.isUserInteractionEnabled = false

        [card, texts, checkView, badgeView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: .adaptHeight(84)),

            texts.leadingAnchor.constraint(equalTo: leadingAnchor, constant: .adaptWidth(30)),
            texts.centerYAnchor.constraint(equalTo: centerYAnchor),
            texts.trailingAnchor.constraint(lessThanOrEqualTo: checkView.leadingAnchor, constant: -.adaptWidth(12)),

            checkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -.adaptWidth(30)),
            checkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: .adaptWidth(24)),

            badgeView.topAnchor.constraint(equalTo: topAnchor, constant: -.adaptHeight(9)),
            badgeView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -.adaptWidth(39)),
            badgeView.widthAnchor.constraint(greaterThanOrEqualToConstant: .adaptWidth(88)),
            badgeLabel.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: .adaptHeight(4)),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor, constant: -.adaptHeight(4)),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: .adaptWidth(10)),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -.adaptWidth(10))
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    @objc
    private func tapped() {
        Haptics.selection()
        onSelect?(planID)
    }
}
