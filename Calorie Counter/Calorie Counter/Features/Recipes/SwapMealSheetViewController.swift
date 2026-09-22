import UIKit

/// The sheet the design shows when a meal is swapped: the meal that is there now, the dishes that
/// could take its place, and one button to confirm. Picking the replacement is the user's call.
final class SwapMealSheetViewController: UIViewController {
    private let slot: MealPlanSlot
    private let options: [Recipe]
    private var selected: Recipe?

    private let closeButton = UIButton(type: .system)
    private let titleLabel = AdaptiveLabel()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headerStack = UIStackView()
    private let confirmButton = UIButton(type: .system)
    private var optionRows: [(recipe: Recipe, row: UIControl, check: UIImageView)] = []

    var onConfirm: ((Recipe) -> Void)?
    var onClose: (() -> Void)?

    init(slot: MealPlanSlot, options: [Recipe]) {
        self.slot = slot
        self.options = options
        selected = options.first
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.sheetGlassTint
        buildChrome()
        buildContent()
    }

    // MARK: - Building

    private func buildChrome() {
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark", foregroundColor: AppColor.iconSecondary)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        titleLabel.text = L10n.tr("recipes.mealPlan.swapTitle")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.stylePrimaryButton(confirmButton, title: L10n.tr("recipes.mealPlan.swapConfirm"))
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        contentStack.axis = .vertical
        contentStack.spacing = .adaptHeight(8)
        scrollView.showsVerticalScrollIndicator = false
        headerStack.axis = .vertical
        headerStack.spacing = .adaptHeight(8)
        [closeButton, titleLabel, headerStack, scrollView, confirmButton, contentStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(headerStack)
        view.addSubview(scrollView)
        view.addSubview(confirmButton)
        scrollView.addSubview(contentStack)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: .adaptWidth(16)),
            closeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: .adaptHeight(8)),
            closeButton.widthAnchor.constraint(equalToConstant: .adaptWidth(44)),
            closeButton.heightAnchor.constraint(equalToConstant: .adaptWidth(44)),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            headerStack.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: .adaptHeight(16)),
            headerStack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: .adaptWidth(16)),
            headerStack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: .adaptWidth(-16)),
            // Only the replacements scroll; the current meal and the button stay in place.
            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: .adaptHeight(8)),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            confirmButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: .adaptHeight(16)),
            confirmButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: .adaptWidth(16)),
            confirmButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: .adaptWidth(-16)),
            confirmButton.heightAnchor.constraint(equalToConstant: .adaptHeight(50)),
            confirmButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: .adaptHeight(-8)),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: .adaptWidth(16)),
            contentStack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: .adaptWidth(-16)),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: .adaptWidth(-32))
        ])
    }

    private func buildContent() {
        headerStack.addArrangedSubview(sectionHeader(L10n.tr("recipes.mealPlan.swapCurrent")))
        headerStack.addArrangedSubview(makeRow(recipe: slot.recipe, selectable: false).row)
        headerStack.setCustomSpacing(.adaptHeight(20), after: headerStack.arrangedSubviews.last!)
        headerStack.addArrangedSubview(sectionHeader(L10n.tr("recipes.mealPlan.swapReplaceWith")))
        options.forEach { recipe in
            let made = makeRow(recipe: recipe, selectable: true)
            optionRows.append((recipe, made.row, made.check))
            contentStack.addArrangedSubview(made.row)
        }
        refreshSelection()
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let label = AdaptiveLabel()
        label.text = text
        OnboardingStyle.lockFigmaFont(label, size: 15, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.23)
        return label
    }

    private func makeRow(recipe: Recipe, selectable: Bool) -> (row: UIControl, check: UIImageView) {
        let row = UIControl()
        let card = AdaptiveView()
        card.useLiveGlass = false
        card.applyCardShadow = true
        card.cardFillColor = AppColor.backgroundsPrimaryElevated
        card.adaptCornerRadius = true
        card.designCornerRadius = 16
        card.isUserInteractionEnabled = false

        let photo = UIImageView()
        photo.contentMode = .scaleAspectFill
        photo.clipsToBounds = true
        photo.layer.cornerRadius = .adaptWidth(12)
        photo.layer.cornerCurve = .continuous
        RemoteImageLoader.shared.display(recipe.imageURL, in: photo, placeholder: UIImage(systemName: "fork.knife"))

        let name = AdaptiveLabel()
        name.text = recipe.title
        name.numberOfLines = 2
        OnboardingStyle.lockFigmaFont(name, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        let calories = AdaptiveLabel()
        calories.text = recipe.calories.map { L10n.format("recipes.kcal", Int($0.rounded())) } ?? ""
        OnboardingStyle.lockFigmaFont(calories, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)

        let check = UIImageView()
        check.image = OnboardingStyle.symbol("checkmark", pointSize: 17, weight: .semibold)
        check.tintColor = AppColor.teal
        check.contentMode = .scaleAspectFit
        check.isHidden = !selectable

        let text = UIStackView(arrangedSubviews: [name, calories])
        text.axis = .vertical
        text.spacing = .adaptHeight(2)
        // Without this the stack swallows the tap and the dish never gets picked.
        [photo, text, check].forEach { $0.isUserInteractionEnabled = false }
        [card, photo, text, check].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }
        row.sendSubviewToBack(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: row.topAnchor),
            card.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            photo.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: .adaptWidth(12)),
            photo.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            photo.widthAnchor.constraint(equalToConstant: .adaptWidth(52)),
            photo.heightAnchor.constraint(equalToConstant: .adaptWidth(52)),
            text.leadingAnchor.constraint(equalTo: photo.trailingAnchor, constant: .adaptWidth(12)),
            text.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            text.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: .adaptHeight(12)),
            check.leadingAnchor.constraint(equalTo: text.trailingAnchor, constant: .adaptWidth(12)),
            check.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: .adaptWidth(-16)),
            check.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            check.widthAnchor.constraint(equalToConstant: .adaptWidth(22)),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: .adaptHeight(76))
        ])
        // Without a height of its own the row stretched to fill the sheet and squeezed the list out.
        let height = row.heightAnchor.constraint(equalToConstant: .adaptHeight(76))
        height.priority = .init(999)
        height.isActive = true
        row.isUserInteractionEnabled = selectable
        if selectable {
            row.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        }
        return (row, check)
    }

    private func refreshSelection() {
        optionRows.forEach { option in
            option.check.isHidden = MealPlanPacker.recipeKey(option.recipe) != selected.map(MealPlanPacker.recipeKey)
        }
        confirmButton.isEnabled = selected != nil
    }

    // MARK: - Actions

    @objc private func optionTapped(_ sender: UIControl) {
        guard let picked = optionRows.first(where: { $0.row === sender })?.recipe else { return }
        selected = picked
        Haptics.selection()
        refreshSelection()
    }

    @objc private func confirmTapped() {
        guard let selected else { return }
        onConfirm?(selected)
    }

    @objc private func closeTapped() {
        onClose?()
    }
}
