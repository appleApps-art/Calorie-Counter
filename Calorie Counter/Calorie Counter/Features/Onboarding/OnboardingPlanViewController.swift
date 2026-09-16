import UIKit

final class OnboardingPlanViewController: BaseViewController {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var energyCardView: AdaptiveView!
    @IBOutlet private weak var energyTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var energyValueLabel: AdaptiveLabel!
    @IBOutlet private weak var goalDateBadgeView: AdaptiveView!
    @IBOutlet private weak var goalDateLabel: AdaptiveLabel!
    @IBOutlet private weak var macroTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinCardView: PlanStatCardView!
    @IBOutlet private weak var fatsCardView: PlanStatCardView!
    @IBOutlet private weak var carbsCardView: PlanStatCardView!
    @IBOutlet private weak var waterCardView: PlanStatCardView!
    @IBOutlet private weak var healthTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var healthCardView: AdaptiveView!
    @IBOutlet private weak var fiberTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var fiberValueLabel: AdaptiveLabel!
    @IBOutlet private weak var sugarTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var sugarValueLabel: AdaptiveLabel!
    @IBOutlet private weak var sodiumTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var sodiumValueLabel: AdaptiveLabel!
    @IBOutlet private weak var continueButton: UIButton!

    var onContinue: (() -> Void)?
    var onBack: (() -> Void)?
    var onLearnMore: (() -> Void)?

    private var display: OnboardingPlanDisplay?

    init() {
        super.init(nibName: "OnboardingPlanViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .onboardingPlan }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = false
        backgroundImageView.image = UIImage(named: "OnboardingBg")
        configureChrome()
        OnboardingStyle.styleBackButton(backButton)
        OnboardingStyle.stylePrimaryButton(continueButton, title: L10n.tr("onboarding.plan.cta"))
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        if let display {
            render(display)
        }
        configureFlexibleCards()
    }

    func apply(_ display: OnboardingPlanDisplay) {
        self.display = display
        guard isViewLoaded else { return }
        render(display)
    }

    private func configureFlexibleCards() {
        for row in [proteinCardView.superview, carbsCardView.superview].compactMap({ $0 }) {
            NSLayoutConstraint.deactivate(row.constraints.filter { $0.firstAttribute == .height && $0.secondItem == nil })
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 77).isActive = true
        }
        NSLayoutConstraint.deactivate(healthCardView.constraints.filter { $0.firstAttribute == .height && $0.secondItem == nil })
        healthCardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 172).isActive = true
        for title in [fiberTitleLabel, sugarTitleLabel, sodiumTitleLabel].compactMap({ $0 }) {
            title.applyWrapping()
            if let row = title.superview as? UIStackView {
                row.spacing = 8
                title.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.43).isActive = true
            }
        }
        [energyTitleLabel, energyValueLabel, macroTitleLabel, healthTitleLabel,
         fiberValueLabel, sugarValueLabel, sodiumValueLabel, goalDateLabel].forEach { $0?.applyWrapping() }
    }

    private func configureChrome() {
        titleLabel.text = L10n.tr("onboarding.plan.q.title")
        OnboardingStyle.styleHeading(titleLabel, subtitleLabel)
        configureSubtitle()
        energyTitleLabel.text = L10n.tr("onboarding.plan.energyTitle")
        energyTitleLabel.textColor = AppColor.textSecondary
        energyValueLabel.textColor = AppColor.textPrimary
        goalDateBadgeView.backgroundColor = AppColor.gray6
        macroTitleLabel.text = L10n.tr("onboarding.plan.macroTitle")
        macroTitleLabel.textColor = AppColor.textPrimary
        healthTitleLabel.text = L10n.tr("onboarding.plan.healthTitle")
        healthTitleLabel.textColor = AppColor.textPrimary
        fiberTitleLabel.text = L10n.tr("onboarding.plan.fiber")
        sugarTitleLabel.text = L10n.tr("onboarding.plan.sugar")
        sodiumTitleLabel.text = L10n.tr("onboarding.plan.sodium")
        [fiberTitleLabel, sugarTitleLabel, sodiumTitleLabel].forEach {
            OnboardingStyle.lockFigmaFont($0, size: 17, weight: .regular, color: AppColor.textPrimary)
        }
        [fiberValueLabel, sugarValueLabel, sodiumValueLabel].forEach {
            OnboardingStyle.lockFigmaFont($0, size: 17, weight: .regular, color: AppColor.textSecondary)
        }
        energyCardView.useLiveGlass = false
        healthCardView.useLiveGlass = false
        OnboardingStyle.lockFigmaFont(energyTitleLabel, size: 17, weight: .semibold, color: AppColor.textSecondary)
        OnboardingStyle.lockFigmaFont(energyValueLabel, size: 34, weight: .bold, color: AppColor.textPrimary)
        OnboardingStyle.lockFigmaFont(macroTitleLabel, size: 22, weight: .bold, color: AppColor.textPrimary)
        OnboardingStyle.lockFigmaFont(healthTitleLabel, size: 22, weight: .bold, color: AppColor.textPrimary)
        goalDateLabel.adaptFontSize = false
        subtitleLabel.adaptFontSize = false
    }

    private func render(_ display: OnboardingPlanDisplay) {
        energyValueLabel.text = display.energyValue
        OnboardingStyle.lockFigmaFont(energyValueLabel, size: 34, weight: .bold, color: AppColor.textPrimary)
        renderGoalDate(display.goalDateText)
        proteinCardView.configure(title: L10n.tr("onboarding.plan.protein"), value: display.proteinValue)
        fatsCardView.configure(title: L10n.tr("onboarding.plan.fats"), value: display.fatsValue)
        carbsCardView.configure(title: L10n.tr("onboarding.plan.carbs"), value: display.carbsValue)
        waterCardView.configure(title: L10n.tr("onboarding.plan.water"), value: display.waterValue)
        fiberValueLabel.text = display.fiberValue
        sugarValueLabel.text = display.sugarValue
        sodiumValueLabel.text = display.sodiumValue
        [fiberValueLabel, sugarValueLabel, sodiumValueLabel].forEach {
            OnboardingStyle.lockFigmaFont($0, size: 17, weight: .regular, color: AppColor.textSecondary)
        }
    }

    private func configureSubtitle() {
        let prefix = L10n.tr("onboarding.plan.q.subtitle")
        let link = L10n.tr("onboarding.plan.learnMore")
        let attributed = NSMutableAttributedString(
            string: prefix,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: AppColor.textSecondary
            ]
        )
        let linkAttributed = NSAttributedString(
            string: link,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: AppColor.textSecondary,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        attributed.append(linkAttributed)
        subtitleLabel.attributedText = attributed
        subtitleLabel.isUserInteractionEnabled = true
        if subtitleLabel.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) != true {
            subtitleLabel.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(subtitleTapped(_:)))
            )
        }
    }

    private func renderGoalDate(_ text: String) {
        let iconAttachment = NSTextAttachment()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        iconAttachment.image = UIImage(systemName: "calendar.badge.checkmark", withConfiguration: symbolConfig)?
            .withTintColor(AppColor.textSecondary, renderingMode: .alwaysOriginal)
        let attributed = NSMutableAttributedString(attachment: iconAttachment)
        attributed.append(NSAttributedString(
            string: "  " + text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: AppColor.textSecondary
            ]
        ))
        goalDateLabel.attributedText = attributed
    }

    @objc
    private func backTapped() {
        onBack?()
    }

    @objc
    private func continueTapped() {
        onContinue?()
    }

    @objc
    private func subtitleTapped(_ gesture: UITapGestureRecognizer) {
        guard let text = subtitleLabel.attributedText?.string else { return }
        let link = L10n.tr("onboarding.plan.learnMore")
        let range = (text as NSString).range(of: link)
        guard range.location != NSNotFound, didTap(in: range, gesture: gesture) else { return }
        onLearnMore?()
    }

    private func didTap(in targetRange: NSRange, gesture: UITapGestureRecognizer) -> Bool {
        guard let attributed = subtitleLabel.attributedText else { return false }
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: subtitleLabel.bounds.size)
        let textStorage = NSTextStorage(attributedString: attributed)
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = subtitleLabel.numberOfLines
        textContainer.lineBreakMode = subtitleLabel.lineBreakMode
        let index = layoutManager.characterIndex(
            for: gesture.location(in: subtitleLabel),
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        return NSLocationInRange(index, targetRange)
    }
}
