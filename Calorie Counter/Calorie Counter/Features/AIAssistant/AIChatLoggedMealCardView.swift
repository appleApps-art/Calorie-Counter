import UIKit

final class AIChatLoggedMealCardView: UIView {
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var innerCardView: AdaptiveView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var mealBadge: AdaptiveView!
    @IBOutlet private weak var mealLabel: AdaptiveLabel!
    @IBOutlet private weak var kcalBadge: AdaptiveView!
    @IBOutlet private weak var kcalLabel: AdaptiveLabel!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var macrosLabel: AdaptiveLabel!
    @IBOutlet private weak var undoButton: UIButton!

    var onUndo: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(proposal: FoodLogProposal, canUndo: Bool) {
        titleLabel.text = proposal.name
        macrosLabel.text = L10n.format(
            "ai.chat.logged.macros",
            Int(proposal.protein.rounded()),
            Int(proposal.carbs.rounded()),
            Int(proposal.fats.rounded())
        )
        mealLabel.text = proposal.mealType.localizedTitle
        kcalLabel.text = L10n.format("ai.chat.kcal", Int(proposal.calories.rounded()))
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(macrosLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(mealLabel, size: 11, weight: .regular, color: .white, kern: 0.06)
        OnboardingStyle.lockFigmaFont(kcalLabel, size: 11, weight: .regular, color: .white, kern: 0.06)
        mealBadge.backgroundColor = .black
        kcalBadge.backgroundColor = .black
        cardView.backgroundColor = OnboardingStyle.fillQuaternary
        cardView.applyCardShadow = false
        cardView.useLiveGlass = false
        innerCardView.applyCardShadow = true
        innerCardView.showsDropShadow = false
        innerCardView.showsHairlineBorder = true
        innerCardView.useLiveGlass = false
        imageView.clipsToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = .adaptWidth(11)
        imageView.backgroundColor = AppColor.fillSecondary
        RemoteImageLoader.shared.display(
            proposal.imageURL,
            in: imageView,
            placeholder: OnboardingStyle.symbol("photo", pointSize: 28)?.withTintColor(
                AppColor.labelsSecondary,
                renderingMode: .alwaysOriginal
            )
        )
        undoButton.isHidden = !canUndo
        OnboardingStyle.styleSecondaryButton(undoButton, title: L10n.tr("ai.chat.undo"))
        undoButton.controlHaptic = .warning
        undoButton.setTitleColor(AppColor.iconSecondary, for: .normal)
        undoButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
    }

    @objc
    private func undoTapped() {
        onUndo?()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        undoButton?.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
    }
}
