import UIKit

final class WelcomeViewController: BaseViewController {
    @IBOutlet private weak var heroImageView: GIFImageView!
    @IBOutlet private weak var feature1WellView: UIView!
    @IBOutlet private weak var feature2WellView: UIView!
    @IBOutlet private weak var feature3WellView: UIView!
    @IBOutlet private weak var feature1IconView: UIImageView!
    @IBOutlet private weak var feature2IconView: UIImageView!
    @IBOutlet private weak var feature3IconView: UIImageView!
    @IBOutlet private weak var feature1CheckView: UIImageView!
    @IBOutlet private weak var feature2CheckView: UIImageView!
    @IBOutlet private weak var feature3CheckView: UIImageView!
    @IBOutlet private weak var feature1Label: UILabel!
    @IBOutlet private weak var feature2Label: UILabel!
    @IBOutlet private weak var feature3Label: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var getStartedButton: UIButton!
    @IBOutlet private weak var footerLabel: UILabel!
    @IBOutlet private weak var bottomContainer: UIView!

    var onGetStarted: (() -> Void)?

    private var didPlayEntrance = false

    init() {
        super.init(nibName: "WelcomeViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .welcome }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureContent()
        configureHero()
        let heroSizes = heroImageView.constraints.filter {
            $0.secondItem == nil && ($0.firstAttribute == .width || $0.firstAttribute == .height)
        }
        NSLayoutConstraint.deactivate(heroSizes)
        let preferredHeroWidth = heroImageView.widthAnchor.constraint(equalToConstant: 369)
        preferredHeroWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredHeroWidth,
            heroImageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
            heroImageView.heightAnchor.constraint(equalTo: heroImageView.widthAnchor, multiplier: 366.0 / 369.0)
        ])
        FlowScrollLayout.install(in: view)
        bottomContainer.alpha = 0
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: WelcomeViewController, _) in
            controller.configureHero()
            controller.configureFeatureIcons()
            controller.configureFooter()
            controller.titleLabel.textColor = AppColor.textPrimary
            controller.subtitleLabel.textColor = AppColor.textSecondary
            [controller.feature1Label, controller.feature2Label, controller.feature3Label].forEach {
                $0.textColor = AppColor.textPrimary
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didPlayEntrance {
            heroImageView.startAnimatingGIF()
        }
        playEntranceAnimationIfNeeded()
    }

    private func configureHero() {
        // The scan animation is the same in both themes; dark used to sit on a still frame.
        heroImageView.playsOnce = true
        heroImageView.loadGIF(named: "WelcomeBityWhiteTheme1")
        if didPlayEntrance {
            heroImageView.startAnimatingGIF()
        }
    }

    private func playEntranceAnimationIfNeeded() {
        guard !didPlayEntrance else { return }
        didPlayEntrance = true
        bottomContainer.transform = CGAffineTransform(translationX: 0, y: .adaptHeight(40))
        bottomContainer.alpha = 0
        UIView.animate(
            withDuration: 0.8,
            delay: 0,
            options: [.curveEaseOut],
            animations: { [weak self] in
                self?.bottomContainer.transform = .identity
                self?.bottomContainer.alpha = 1
            }
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            heroImageView.stopAnimatingGIF()
        }
    }

    private func configureContent() {
        titleLabel.text = L10n.tr("onboarding.welcome.title")
        subtitleLabel.text = L10n.tr("onboarding.welcome.subtitle")
        feature1Label.text = L10n.tr("onboarding.welcome.feature1")
        feature2Label.text = L10n.tr("onboarding.welcome.feature2")
        feature3Label.text = L10n.tr("onboarding.welcome.feature3")
        configureFeatureIcons()
        configureFooter()
        OnboardingStyle.styleTitle(titleLabel)
        OnboardingStyle.lockFigmaFont(
            subtitleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.textSecondary,
            kern: -0.43
        )
        [feature1Label, feature2Label, feature3Label].forEach { label in
            OnboardingStyle.lockFigmaFont(
                label,
                size: 16,
                weight: .regular,
                color: AppColor.textPrimary,
                kern: -0.31
            )
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.applyWrapping()
            if let row = label.superview as? UIStackView {
                NSLayoutConstraint.deactivate(row.constraints.filter {
                    $0.firstAttribute == .height && $0.secondItem == nil
                })
                row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            }
        }
        // The feature rows fill the card's width: sized to their text they shrank once the labels
        // started wrapping, and the checkmarks drifted in from the edge.
        if let features = feature1Label.superview?.superview, let host = features.superview {
            [
                features.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                features.trailingAnchor.constraint(equalTo: host.trailingAnchor)
            ].forEach {
                $0.priority = .init(999)
                $0.isActive = true
            }
        }
        view.clipsToBounds = false
        OnboardingStyle.stylePrimaryButton(getStartedButton, title: L10n.tr("onboarding.start"))
        getStartedButton.addTarget(self, action: #selector(getStartedTapped), for: .touchUpInside)
    }

    private func configureFeatureIcons() {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let checkConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let wells: [UIView] = [feature1WellView, feature2WellView, feature3WellView]
        wells.forEach { well in
            well.backgroundColor = AppColor.gray6
            well.layer.cornerRadius = 8
            well.layer.cornerCurve = .continuous
            well.clipsToBounds = true
        }
        let icons: [(UIImageView, String)] = [
            (feature1IconView, "camera"),
            (feature2IconView, "message.badge.waveform"),
            (feature3IconView, "chart.line.uptrend.xyaxis")
        ]
        icons.forEach { view, name in
            view.clipsToBounds = false
            view.contentMode = .center
            view.image = UIImage(systemName: name, withConfiguration: iconConfig)?
                .withTintColor(AppColor.iconSecondary, renderingMode: .alwaysOriginal)
        }
        let checks: [UIImageView] = [feature1CheckView, feature2CheckView, feature3CheckView]
        checks.forEach { view in
            view.image = UIImage(systemName: "checkmark", withConfiguration: checkConfig)?
                .withTintColor(OnboardingStyle.accentTeal, renderingMode: .alwaysOriginal)
            view.contentMode = .center
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
    }

    private func configureFooter() {
        (footerLabel as? AdaptiveLabel)?.adaptFontSize = false
        let prefix = L10n.tr("onboarding.welcome.footer.prefix")
        let link = L10n.tr("onboarding.welcome.termsPrivacy")
        let text = prefix + link
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: AppColor.footerLabel
            ]
        )
        let linkRange = NSRange(location: prefix.count, length: link.count)
        attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkRange)
        footerLabel.attributedText = attributed
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
    }

    @objc
    private func getStartedTapped() {
        Haptics.light()
        onGetStarted?()
    }
}
