import UIKit

final class AIIntroViewController: BaseViewController {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var previewCardView: AdaptiveView!
    @IBOutlet private weak var sessionDotView: AdaptiveView!
    @IBOutlet private weak var sessionLabel: AdaptiveLabel!
    @IBOutlet private weak var previewLabel: AdaptiveLabel!
    @IBOutlet private weak var userBubbleView: AIChatUserBubbleView!
    @IBOutlet private weak var assistantAvatarView: UIImageView!
    @IBOutlet private weak var assistantBubbleView: AdaptiveView!
    @IBOutlet private weak var assistantMessageLabel: AdaptiveLabel!
    @IBOutlet private weak var capabilitiesTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var capabilitiesCardView: AdaptiveView!
    @IBOutlet private weak var capabilitiesStackView: UIStackView!
    @IBOutlet private weak var startButton: UIButton!

    var onStart: (() -> Void)?

    init() {
        super.init(nibName: "AIIntroViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .aiIntro }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.backgroundsPrimary
        view.clipsToBounds = false
        disableCardLiveGlass()
        configureCopy()
        configurePreview()
        configureCapabilities()
        OnboardingStyle.stylePrimaryButton(startButton, title: L10n.tr("ai.intro.cta"))
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    private func configureCopy() {
        titleLabel.text = L10n.tr("ai.intro.title")
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 34,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: 0.4
        )
        sessionLabel.text = L10n.tr("ai.intro.session")
        previewLabel.text = L10n.tr("ai.intro.preview")
        OnboardingStyle.lockFigmaFont(
            sessionLabel,
            size: 11,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: 0.06
        )
        OnboardingStyle.lockFigmaFont(
            previewLabel,
            size: 11,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: 0.06
        )
        capabilitiesTitleLabel.text = L10n.tr("ai.intro.capabilitiesTitle")
        capabilitiesTitleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            capabilitiesTitleLabel,
            size: 15,
            weight: .regular,
            color: AppColor.labelVibrantPrimary,
            kern: -0.23
        )
    }

    private func configurePreview() {
        sessionDotView.backgroundColor = AppColor.teal
        userBubbleView.configure(text: L10n.tr("ai.intro.userMessage"), alignment: .left)
        userBubbleView.setContentHuggingPriority(.required, for: .horizontal)
        userBubbleView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        previewCardView.applyCardShadow = false
        previewCardView.useLiveGlass = false
        previewCardView.backgroundColor = AppColor.card
        previewCardView.clipsToBounds = false
        previewCardView.layer.masksToBounds = false
        capabilitiesCardView.useLiveGlass = false
        configureAssistantPreview()
    }

    private func configureAssistantPreview() {
        assistantMessageLabel.text = L10n.tr("ai.intro.assistantMessage")
        assistantMessageLabel.numberOfLines = 0
        assistantMessageLabel.textAlignment = .left
        OnboardingStyle.lockFigmaFont(
            assistantMessageLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        assistantMessageLabel.preferredMaxLayoutWidth = .adaptWidth(258)
        assistantBubbleView.backgroundColor = OnboardingStyle.fillQuaternary
        assistantBubbleView.applyCardShadow = false
        assistantBubbleView.useLiveGlass = false
        assistantBubbleView.setContentHuggingPriority(.required, for: .horizontal)
        assistantMessageLabel.setContentHuggingPriority(.required, for: .horizontal)
        assistantMessageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        assistantAvatarView.image = UIImage(named: "BityAIAssistant")?.withRenderingMode(.alwaysOriginal)
        assistantAvatarView.contentMode = .scaleAspectFit
        assistantAvatarView.clipsToBounds = false
        assistantAvatarView.layer.masksToBounds = false
        assistantAvatarView.backgroundColor = .clear
        assistantAvatarView.isHidden = false
        assistantAvatarView.alpha = 1
        assistantAvatarView.setContentHuggingPriority(.required, for: .horizontal)
        assistantAvatarView.setContentCompressionResistancePriority(.required, for: .horizontal)
        assistantAvatarView.setContentHuggingPriority(.required, for: .vertical)
        assistantAvatarView.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        assistantMessageLabel.preferredMaxLayoutWidth = .adaptWidth(258)
        previewCardView.bringSubviewToFront(assistantAvatarView)
    }

    private func configureCapabilities() {
        let items: [(String, String, String)] = [
            ("microphone", L10n.tr("ai.intro.capability.chat.title"), L10n.tr("ai.intro.capability.chat.subtitle")),
            ("calendar", L10n.tr("ai.intro.capability.memory.title"), L10n.tr("ai.intro.capability.memory.subtitle")),
            ("book", L10n.tr("ai.intro.capability.recipes.title"), L10n.tr("ai.intro.capability.recipes.subtitle")),
            ("lightbulb", L10n.tr("ai.intro.capability.insights.title"), L10n.tr("ai.intro.capability.insights.subtitle"))
        ]
        capabilitiesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        items.enumerated().forEach { index, item in
            let row = AICapabilityRowView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.configure(
                icon: item.0,
                title: item.1,
                subtitle: item.2,
                showsSeparator: index < items.count - 1
            )
            capabilitiesStackView.addArrangedSubview(row)
        }
    }

    private func disableCardLiveGlass() {
        [previewCardView, capabilitiesCardView].forEach { card in
            card.useLiveGlass = false
        }
    }

    @objc
    private func startTapped() {
        onStart?()
    }
}
