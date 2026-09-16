import UIKit

final class AIChatRecipeCardView: UIView, UIGestureRecognizerDelegate {
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var kcalBadge: AdaptiveView!
    @IBOutlet private weak var kcalLabel: AdaptiveLabel!
    @IBOutlet private weak var timeBadge: AdaptiveView!
    @IBOutlet private weak var timeLabel: AdaptiveLabel!
    @IBOutlet private weak var mealTypeLabel: AdaptiveLabel!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var summaryLabel: AdaptiveLabel!
    @IBOutlet private weak var macrosLabel: AdaptiveLabel!
    @IBOutlet private weak var logButton: UIButton!

    var onLog: (() -> Void)?
    var onSelect: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ option: MealSuggestionOption, mealType: MealType) {
        let mealTitle = (option.mealType ?? mealType).localizedTitle
        mealTypeLabel.text = mealTitle
        mealTypeLabel.accessibilityIdentifier = "ai.chat.recipe.mealType"
        titleLabel.text = option.title
        summaryLabel.text = option.summary
        summaryLabel.numberOfLines = 0
        macrosLabel.text = L10n.format(
            "ai.chat.recipe.macros",
            Int(option.calories.rounded()),
            Int(option.protein.rounded()),
            Int(option.carbs.rounded()),
            Int(option.fats.rounded())
        )
        kcalLabel.text = L10n.format("ai.chat.kcal", Int(option.calories.rounded()))
        if let minutes = option.cookTimeMinutes {
            timeBadge.isHidden = false
            timeLabel.text = L10n.format("ai.chat.minutes", Int(minutes.rounded()))
        } else {
            timeBadge.isHidden = true
        }
        OnboardingStyle.lockFigmaFont(mealTypeLabel, size: 13, weight: .semibold, color: AppColor.labelsSecondary, kern: -0.08)
        mealTypeLabel.applyWrapping()
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(summaryLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(macrosLabel, size: 13, weight: .regular, color: AppColor.labelsSecondary, kern: -0.08)
        OnboardingStyle.lockFigmaFont(kcalLabel, size: 11, weight: .regular, color: .white, kern: 0.06)
        OnboardingStyle.lockFigmaFont(timeLabel, size: 11, weight: .regular, color: .white, kern: 0.06)
        kcalBadge.backgroundColor = .black
        timeBadge.backgroundColor = .black
        cardView.backgroundColor = OnboardingStyle.fillQuaternary
        cardView.applyCardShadow = false
        cardView.useLiveGlass = false
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.preferredSymbolConfiguration = nil
        imageView.layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = .adaptWidth(12)
        imageView.backgroundColor = AppColor.fillSecondary
        RemoteImageLoader.shared.display(
            option.imageURL,
            in: imageView,
            placeholder: OnboardingStyle.symbol("photo", pointSize: 28)?.withTintColor(
                AppColor.labelsSecondary,
                renderingMode: .alwaysOriginal
            )
        )
        OnboardingStyle.stylePrimaryButton(logButton, title: L10n.tr("ai.chat.logMeal"), systemImage: "plus")
        isAccessibilityElement = false
        cardView.isAccessibilityElement = true
        cardView.accessibilityTraits = .button
        cardView.accessibilityLabel = "\(mealTitle). \(option.title)"
    }

    @objc
    private func logTapped() {
        onLog?()
    }

    @objc
    private func cardTapped() {
        Haptics.light()
        onSelect?()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current === logButton {
                return false
            }
            view = current.superview
        }
        return true
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        logButton?.addTarget(self, action: #selector(logTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)
    }
}
