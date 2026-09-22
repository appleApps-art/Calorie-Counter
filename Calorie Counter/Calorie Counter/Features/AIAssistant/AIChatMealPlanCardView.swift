import UIKit

/// The plan the chat is about, shown as the card the user handed over, the way the design opens
/// "Edit with Bity": cover, name and "6 days · 18 meals".
final class AIChatMealPlanCardView: UIView {
    private let container = AdaptiveView()
    private let card = AdaptiveView()
    private let coverView = UIImageView()
    private let titleLabel = AdaptiveLabel()
    private let subtitleLabel = AdaptiveLabel()
    private var renderedCoverSize: CGSize = .zero
    private var planTitle: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    func configure(_ plan: MealPlan) {
        planTitle = plan.title
        titleLabel.text = plan.title
        subtitleLabel.text = plan.subtitle
        renderedCoverSize = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = coverView.bounds.size
        guard let planTitle, size.width > 1, size.height > 1, size != renderedCoverSize else { return }
        renderedCoverSize = size
        coverView.image = MealPlanCover.image(title: planTitle, size: size, traits: traitCollection)
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        guard traitCollection.userInterfaceStyle != previous?.userInterfaceStyle else { return }
        renderedCoverSize = .zero
        setNeedsLayout()
    }

    private func build() {
        backgroundColor = .clear
        container.useLiveGlass = false
        container.applyCardShadow = false
        container.backgroundColor = AppColor.fillQuaternary
        container.adaptCornerRadius = true
        container.designCornerRadius = 16
        card.useLiveGlass = false
        card.applyCardShadow = true
        card.cardFillColor = AppColor.backgroundsPrimary
        card.adaptCornerRadius = true
        card.designCornerRadius = 16
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = .adaptWidth(11)
        coverView.layer.cornerCurve = .continuous
        titleLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(subtitleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)

        [container, card, coverView, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        addSubview(container)
        container.addSubview(card)
        card.addSubview(coverView)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            // The card sits on the user's side of the thread.
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: .adaptHeight(12)),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: .adaptHeight(-12)),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: .adaptWidth(12)),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: .adaptWidth(-12)),
            card.widthAnchor.constraint(equalToConstant: .adaptWidth(290)),
            coverView.topAnchor.constraint(equalTo: card.topAnchor, constant: .adaptHeight(8)),
            coverView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: .adaptWidth(8)),
            coverView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: .adaptWidth(-8)),
            coverView.heightAnchor.constraint(equalToConstant: .adaptHeight(100)),
            titleLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: .adaptHeight(8)),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: .adaptWidth(8)),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: .adaptWidth(-8)),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: .adaptHeight(4)),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: .adaptHeight(-8))
        ])
    }
}
