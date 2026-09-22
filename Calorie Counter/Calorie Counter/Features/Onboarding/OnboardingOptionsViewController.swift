import UIKit

struct OnboardingOption {
    let icon: String
    let title: String
    let subtitle: String?
}

final class OnboardingOptionsViewController: BaseViewController {
    struct Content {
        let backgroundImageName: String?
        let title: String
        let subtitle: String
        let options: [OnboardingOption]
        let selectedIndex: Int
        let pageCount: Int
        let pageIndex: Int
        let analyticsScreen: AnalyticsScreen
    }

    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var cardsStackView: UIStackView!
    @IBOutlet private weak var pageControl: UIPageControl!
    @IBOutlet private weak var continueButton: UIButton!

    var onContinue: ((Int) -> Void)?
    var onBack: (() -> Void)?

    var selectedIndex: Int {
        cards.firstIndex(where: \.isSelected) ?? content.selectedIndex
    }

    private let content: Content
    private var cards: [OnboardingOptionCardView] = []

    init(content: Content) {
        self.content = content
        super.init(nibName: "OnboardingOptionsViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { content.analyticsScreen }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureChrome()
        buildOptions()
        // The design keeps the question and the button in place: only the list of options moves.
        if let scroll = ScrollSectionLayout.wrap(cardsStackView) {
            scroll.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: .adaptHeight(-16)).isActive = true
        }
    }

    private func configureChrome() {
        if let name = content.backgroundImageName {
            backgroundImageView.image = UIImage(named: name)
            backgroundImageView.isHidden = false
        } else {
            backgroundImageView.isHidden = true
        }
        titleLabel.text = content.title
        subtitleLabel.text = content.subtitle
        OnboardingStyle.styleHeading(titleLabel, subtitleLabel)
        OnboardingStyle.styleBackButton(backButton)
        OnboardingStyle.stylePrimaryButton(continueButton, title: L10n.tr("common.continue"))
        OnboardingStyle.stylePageControl(pageControl, pages: content.pageCount, current: content.pageIndex)
        cardsStackView.clipsToBounds = false
        view.clipsToBounds = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }

    private func buildOptions() {
        cardsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        cards.removeAll()
        for (index, option) in content.options.enumerated() {
            let card = OnboardingOptionCardView()
            card.translatesAutoresizingMaskIntoConstraints = false
            card.configure(icon: option.icon, title: option.title, subtitle: option.subtitle)
            card.isSelected = (index == content.selectedIndex)
            card.tag = index
            card.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
            cardsStackView.addArrangedSubview(card)
            cards.append(card)
        }
    }

    @objc
    private func optionTapped(_ sender: OnboardingOptionCardView) {
        guard !sender.isSelected else { return }
        Haptics.selection()
        cards.forEach { $0.isSelected = ($0 === sender) }
    }

    @objc
    private func backTapped() {
        Haptics.light()
        onBack?()
    }

    @objc
    private func continueTapped() {
        Haptics.light()
        onContinue?(selectedIndex)
    }
}

extension OnboardingOptionsViewController {
    static func goal() -> OnboardingOptionsViewController {
        OnboardingOptionsViewController(content: Content(
            backgroundImageName: "startOnboardingBg",
            title: L10n.tr("onboarding.goal.q.title"),
            subtitle: L10n.tr("onboarding.goal.q.subtitle"),
            options: [
                OnboardingOption(icon: "flame", title: L10n.tr("onboarding.goal.lose.title"), subtitle: L10n.tr("onboarding.goal.lose.subtitle")),
                OnboardingOption(icon: "leaf", title: L10n.tr("onboarding.goal.maintain.title"), subtitle: L10n.tr("onboarding.goal.maintain.subtitle")),
                OnboardingOption(icon: "dumbbell", title: L10n.tr("onboarding.goal.build.title"), subtitle: L10n.tr("onboarding.goal.build.subtitle"))
            ],
            selectedIndex: 0,
            pageCount: 6,
            pageIndex: 0,
            analyticsScreen: .onboardingGoal
        ))
    }

    static func activity() -> OnboardingOptionsViewController {
        OnboardingOptionsViewController(content: Content(
            backgroundImageName: "startOnboardingBg",
            title: L10n.tr("onboarding.activity.q.title"),
            subtitle: L10n.tr("onboarding.activity.q.subtitle"),
            options: [
                OnboardingOption(icon: "figure.seated.side.right", title: L10n.tr("onboarding.activity.sedentary.title"), subtitle: L10n.tr("onboarding.activity.sedentary.subtitle")),
                OnboardingOption(icon: "figure.walk", title: L10n.tr("onboarding.activity.moderate.title"), subtitle: L10n.tr("onboarding.activity.moderate.subtitle")),
                OnboardingOption(icon: "figure.basketball", title: L10n.tr("onboarding.activity.active.title"), subtitle: L10n.tr("onboarding.activity.active.subtitle")),
                OnboardingOption(icon: "figure.yoga", title: L10n.tr("onboarding.activity.athletic.title"), subtitle: L10n.tr("onboarding.activity.athletic.subtitle"))
            ],
            selectedIndex: 0,
            pageCount: 6,
            pageIndex: 5,
            analyticsScreen: .onboardingActivity
        ))
    }

    static func sex() -> OnboardingOptionsViewController {
        OnboardingOptionsViewController(content: Content(
            backgroundImageName: "OnboardingBg1",
            title: L10n.tr("onboarding.sex.q.title"),
            subtitle: L10n.tr("onboarding.sex.q.subtitle"),
            options: [
                OnboardingOption(icon: "figure.stand", title: L10n.tr("onboarding.sex.male"), subtitle: nil),
                OnboardingOption(icon: "figure.stand.dress", title: L10n.tr("onboarding.sex.female"), subtitle: nil)
            ],
            selectedIndex: 0,
            pageCount: 6,
            pageIndex: 1,
            analyticsScreen: .onboardingSex
        ))
    }
}
