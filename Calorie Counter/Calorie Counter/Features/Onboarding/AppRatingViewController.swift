import StoreKit
import UIKit

final class AppRatingViewController: BaseViewController {
    @IBOutlet private weak var mascotView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var starsStackView: AdaptiveStackView!
    @IBOutlet private weak var rateButton: UIButton!
    @IBOutlet private weak var laterButton: UIButton!

    var onFinished: (() -> Void)?
    private var didFinish = false

    init() {
        super.init(nibName: "AppRatingViewController")
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    override var analyticsScreen: AnalyticsScreen? { .appRating }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.backgroundsPrimary
        mascotView.image = UIImage(named: "AppRatingMascot")
        mascotView.contentMode = .scaleAspectFit
        titleLabel.text = L10n.tr("onboarding.rating.title")
        subtitleLabel.text = L10n.tr("onboarding.rating.subtitle")
        titleLabel.numberOfLines = 0
        subtitleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 28,
            weight: .bold,
            color: AppColor.labelsPrimary,
            kern: 0.38
        )
        OnboardingStyle.lockFigmaFont(
            subtitleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsSecondary,
            kern: -0.43
        )
        renderStars()
        OnboardingStyle.stylePrimaryButton(rateButton, title: L10n.tr("onboarding.rating.rate"))
        OnboardingStyle.styleBorderlessButton(laterButton, title: L10n.tr("onboarding.health.maybeLater"))
        rateButton.addTarget(self, action: #selector(rateTapped), for: .touchUpInside)
        laterButton.addTarget(self, action: #selector(laterTapped), for: .touchUpInside)
        FlowScrollLayout.install(in: view)
    }

    private func renderStars() {
        starsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        starsStackView.axis = .horizontal
        starsStackView.alignment = .center
        starsStackView.distribution = .equalSpacing
        starsStackView.adaptSpacing = true
        let star = OnboardingStyle.symbol("star.fill", pointSize: 28, weight: .regular)?
            .withTintColor(OnboardingStyle.accentTeal, renderingMode: .alwaysOriginal)
        for _ in 0..<5 {
            let imageView = UIImageView(image: star)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            let side = CGFloat.adaptWidth(28)
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: side),
                imageView.heightAnchor.constraint(equalToConstant: side)
            ])
            starsStackView.addArrangedSubview(imageView)
        }
    }

    @objc
    private func rateTapped() {
        Analytics.tracker.track(.appRatingTapped(action: "rate"))
        if let scene = view.window?.windowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
        finish()
    }

    @objc
    private func laterTapped() {
        Analytics.tracker.track(.appRatingTapped(action: "later"))
        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinished?()
    }
}
