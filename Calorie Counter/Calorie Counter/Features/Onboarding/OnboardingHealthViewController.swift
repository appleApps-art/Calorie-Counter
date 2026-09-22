import UIKit

final class OnboardingHealthViewController: BaseViewController {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var bityContainerView: AdaptiveView!
    @IBOutlet private weak var bityImageView: UIImageView!
    @IBOutlet private weak var bityLabel: AdaptiveLabel!
    @IBOutlet private weak var syncImageView: UIImageView!
    @IBOutlet private weak var healthContainerView: AdaptiveView!
    @IBOutlet private weak var healthImageView: UIImageView!
    @IBOutlet private weak var healthLabel: AdaptiveLabel!
    @IBOutlet private weak var featuresStackView: UIStackView!
    @IBOutlet private weak var pageControl: UIPageControl!
    @IBOutlet private weak var continueButton: UIButton!
    @IBOutlet private weak var maybeLaterButton: UIButton!

    var onContinue: (() async -> Void)?
    var onMaybeLater: (() -> Void)?
    var onBack: (() -> Void)?

    init() {
        super.init(nibName: "OnboardingHealthViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .onboardingHealth }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureContent()
        configureFeatures()
        OnboardingStyle.styleHeading(titleLabel, nil)
        OnboardingStyle.styleBackButton(backButton)
        OnboardingStyle.stylePrimaryButton(continueButton, title: L10n.tr("common.continue"))
        OnboardingStyle.styleSecondaryButton(maybeLaterButton, title: L10n.tr("onboarding.health.maybeLater"))
        OnboardingStyle.stylePageControl(pageControl, pages: 6, current: 4)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        maybeLaterButton.addTarget(self, action: #selector(maybeLaterTapped), for: .touchUpInside)
        FlowScrollLayout.install(in: view)
    }

    private func configureContent() {
        titleLabel.text = L10n.tr("onboarding.health.q.title")
        titleLabel.textColor = AppColor.textPrimary
        view.clipsToBounds = false
        featuresStackView.clipsToBounds = false
        cardView.useLiveGlass = false
        // The card is the grey plate the two app tiles sit on, and it hugs them.
        cardView.applyCardShadow = true
        cardView.cardFillColor = AppColor.gray6
        cardView.adaptCornerRadius = true
        cardView.designCornerRadius = 32
        NSLayoutConstraint.deactivate(view.constraints.filter { constraint in
            (constraint.firstItem === cardView || constraint.secondItem === cardView)
                && constraint.relation == .equal
                && (constraint.firstAttribute == .leading || constraint.firstAttribute == .trailing)
        })
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: .adaptWidth(16)),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: .adaptWidth(-16))
        ])
        // The plate hugs the two tiles, the way the design draws it, instead of spanning the screen.
        if let content = bityContainerView.superview?.superview {
            [
                content.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: .adaptWidth(20)),
                content.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: .adaptWidth(-20))
            ].forEach {
                $0.priority = .init(999)
                $0.isActive = true
            }
        }
        [bityContainerView, healthContainerView].forEach { tile in
            tile?.useLiveGlass = false
            tile?.applyCardShadow = true
            tile?.cardFillColor = .white
            tile?.adaptCornerRadius = true
            tile?.designCornerRadius = 24
        }
        bityContainerView.clipsToBounds = true
        bityImageView.image = UIImage(named: "BityMascot")
        bityImageView.contentMode = .scaleAspectFit
        bityLabel.text = L10n.tr("onboarding.health.bity")
        OnboardingStyle.lockFigmaFont(bityLabel, size: 22, weight: .regular, color: AppColor.textPrimary)
        healthContainerView.clipsToBounds = true
        healthImageView.image = UIImage(named: "AppleHealthIcon")
        healthImageView.contentMode = .scaleAspectFill
        healthImageView.clipsToBounds = true
        // The Apple Health artwork is a square: it needs the tile's own rounding.
        healthImageView.layer.cornerRadius = .adaptWidth(24)
        healthImageView.layer.cornerCurve = .continuous
        healthLabel.text = L10n.tr("onboarding.health.appleHealth")
        OnboardingStyle.lockFigmaFont(healthLabel, size: 22, weight: .regular, color: AppColor.textPrimary)
        for (container, label) in [(bityContainerView!, bityLabel!), (healthContainerView!, healthLabel!)] {
            NSLayoutConstraint.deactivate(container.constraints.filter {
                $0.secondItem == nil && ($0.firstAttribute == .width || $0.firstAttribute == .height)
            })
            let preferredWidth = container.widthAnchor.constraint(equalToConstant: .adaptWidth(124))
            // High enough that the tiles keep the design's size instead of stretching the card.
            preferredWidth.priority = .init(999)
            NSLayoutConstraint.activate([
                preferredWidth,
                container.widthAnchor.constraint(lessThanOrEqualToConstant: .adaptWidth(124)),
                container.heightAnchor.constraint(equalTo: container.widthAnchor),
                label.widthAnchor.constraint(equalTo: container.widthAnchor)
            ])
            label.applyWrapping()
        }
        bityContainerView.widthAnchor.constraint(equalTo: healthContainerView.widthAnchor).isActive = true
        syncImageView.image = OnboardingStyle.symbol(
            "arrow.trianglehead.2.clockwise.rotate.90",
            "arrow.triangle.2.circlepath",
            pointSize: 25
        )
        syncImageView.tintColor = AppColor.textSecondary
    }

    private func configureFeatures() {
        let features: [(String, String)] = [
            ("figure.run.treadmill", L10n.tr("onboarding.health.feature1")),
            ("chart.line.text.clipboard", L10n.tr("onboarding.health.feature2")),
            ("lock", L10n.tr("onboarding.health.feature3"))
        ]
        let rows = featuresStackView.arrangedSubviews.compactMap { $0 as? OnboardingFeatureRowView }
        zip(rows, features).forEach { row, feature in
            row.configure(icon: feature.0, title: feature.1)
        }
    }

    @objc
    private func backTapped() {
        Haptics.light()
        onBack?()
    }

    @objc
    private func continueTapped() {
        Haptics.light()
        continueButton.isEnabled = false
        Task {
            await onContinue?()
            await MainActor.run { [weak self] in
                self?.continueButton.isEnabled = true
            }
        }
    }

    @objc
    private func maybeLaterTapped() {
        Haptics.light()
        onMaybeLater?()
    }
}
