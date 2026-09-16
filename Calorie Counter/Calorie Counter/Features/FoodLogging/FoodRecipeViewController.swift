import UIKit

final class FoodRecipeViewController: BaseViewController {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var headerCard: AdaptiveView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var nameLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var ingredientsSection: UIView!
    @IBOutlet private weak var ingredientsHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var ingredientsStackView: UIStackView!
    @IBOutlet private weak var stepsSection: UIView!
    @IBOutlet private weak var stepsHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var stepsStackView: UIStackView!
    @IBOutlet private weak var saveButton: UIButton!

    private let savedAlert = StatusAlertOverlay()
    private let viewModel: FoodRecipeViewModel

    init(viewModel: FoodRecipeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "FoodRecipeViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .recipeDetail }

    override func viewDidLoad() {
        savedAlert.attach(to: view)
        savedAlert.configure(title: L10n.tr("recipes.recipeSaved"))
        savedAlert.onOK = { [weak self] in
            self?.viewModel.dismissSavedAlert()
        }
        super.viewDidLoad()
        configureChrome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func bindViewModel() {
        viewModel.nameText.bind { [weak self] value in
            self?.nameLabel.text = value
        }
        viewModel.subtitleText.bind { [weak self] value in
            self?.subtitleLabel.text = value
        }
        viewModel.heroImage.bind { [weak self] image in
            self?.photoImageView.image = image
        }
        viewModel.ingredients.bind { [weak self] items in
            self?.renderIngredients(items)
        }
        viewModel.ingredientsVisible.bind { [weak self] visible in
            self?.ingredientsSection.isHidden = !visible
        }
        viewModel.steps.bind { [weak self] steps in
            self?.renderSteps(steps)
        }
        viewModel.stepsVisible.bind { [weak self] visible in
            self?.stepsSection.isHidden = !visible
        }
        viewModel.savedAlertVisible.bind { [weak self] visible in
            self?.savedAlert.setVisible(visible)
        }
    }

    private func configureChrome() {
        view.backgroundColor = AppColor.canvas
        titleLabel.text = L10n.tr("recipes.generic")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.styleGlassSymbolButton(
            closeButton,
            systemName: "xmark",
            foregroundColor: AppColor.iconSecondary
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerCard.useLiveGlass = false
        headerCard.applyCardShadow = true
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerRadius = .adaptWidth(12)
        photoImageView.layer.cornerCurve = .continuous
        OnboardingStyle.lockFigmaFont(nameLabel, size: 20, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.45)
        OnboardingStyle.lockFigmaFont(subtitleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        applySectionHeader(ingredientsHeaderLabel, symbol: "list.bullet.clipboard", title: L10n.tr("product.details.ingredients"))
        applySectionHeader(stepsHeaderLabel, symbol: "book", title: L10n.tr("product.details.howToPrepare"))
        OnboardingStyle.stylePrimaryButton(saveButton, title: L10n.tr("product.details.saveRecipe"), systemImage: "checkmark")
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        styleListCard(ingredientsStackView)
        styleListCard(stepsStackView)
    }

    private func styleListCard(_ stack: UIStackView) {
        stack.backgroundColor = AppColor.card
        stack.layer.cornerRadius = .adaptWidth(24)
        stack.layer.cornerCurve = .continuous
        stack.clipsToBounds = true
        OnboardingStyle.applyCardFallbackShadow(stack.layer)
    }

    private func applySectionHeader(_ label: AdaptiveLabel?, symbol: String, title: String) {
        guard let label else { return }
        let image = OnboardingStyle.symbol(symbol, pointSize: 15, weight: .semibold)
        let text = NSMutableAttributedString()
        if let image {
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(AppColor.labelVibrantPrimary, renderingMode: .alwaysOriginal)
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: " "))
        }
        text.append(NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: AppColor.labelVibrantPrimary,
                .kern: -0.23
            ]
        ))
        label.attributedText = text
        label.adaptFontSize = false
    }

    private func renderIngredients(_ items: [FoodIngredient]) {
        ingredientsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        items.enumerated().forEach { index, item in
            let view = NutritionFactRowView()
            let amount = ProductDetailsMath.formatIngredientAmount(item)
            view.configure(
                title: item.name,
                value: amount,
                dailyValue: nil,
                showsSeparator: index > 0
            )
            ingredientsStackView.addArrangedSubview(view)
        }
    }

    private func renderSteps(_ steps: [String]) {
        stepsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        steps.enumerated().forEach { index, step in
            let view = RecipeStepRowView()
            view.configure(index: index + 1, text: step, showsSeparator: index > 0)
            stepsStackView.addArrangedSubview(view)
        }
    }

    @objc private func closeTapped() {
        viewModel.closeTapped()
    }

    @objc private func saveTapped() {
        viewModel.saveTapped()
    }
}
