import UIKit

final class MealCardView: UIView {
    @IBOutlet private weak var emojiLabel: AdaptiveLabel!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesLabel: AdaptiveLabel!
    @IBOutlet private weak var editButton: UIButton!
    @IBOutlet private weak var foodsStackView: UIStackView!

    private(set) var mealType: MealType = .breakfast
    var onEdit: ((MealType) -> Void)?
    var onToggleFood: ((UUID) -> Void)?
    var onOpenFood: ((UUID) -> Void)?

    private var foods: [HomeFoodItem] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ section: HomeMealSection) {
        mealType = section.mealType
        emojiLabel.text = section.emoji
        titleLabel.text = section.title
        caloriesLabel.text = section.caloriesText
        OnboardingStyle.lockFigmaFont(titleLabel, size: 15, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(caloriesLabel, size: 12, weight: .medium, color: AppColor.iconSecondary)
        OnboardingStyle.lockFigmaFont(emojiLabel, size: 22, weight: .regular, color: AppColor.labelVibrantPrimary, kern: -0.26)
        foods = section.foods
        renderFoods()
    }

    @IBAction private func editTapped() {
        onEdit?(mealType)
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        if let editButton {
            OnboardingStyle.styleGlassSymbolButton(
                editButton,
                systemName: "pencil",
                foregroundColor: AppColor.labelVibrantPrimary
            )
            editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        if let editButton {
            OnboardingStyle.styleGlassSymbolButton(
                editButton,
                systemName: "pencil",
                foregroundColor: AppColor.labelVibrantPrimary
            )
        }
    }

    private func renderFoods() {
        foodsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        foodsStackView.isHidden = foods.isEmpty
        foods.forEach { item in
            let row = FoodItemRowView()
            row.onToggle = { [weak self] id in
                self?.onToggleFood?(id)
            }
            row.onSelect = { [weak self] id in
                self?.onOpenFood?(id)
            }
            foodsStackView.addArrangedSubview(row)
            row.configure(item)
        }
    }
}
