import UIKit

final class ProductDetailsViewController: BaseViewController {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var shareButton: UIButton!
    @IBOutlet private weak var productCard: AdaptiveView!
    @IBOutlet private weak var heroImageView: UIImageView!
    @IBOutlet private weak var nameLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreCircleView: AdaptiveView!
    @IBOutlet private weak var scoreGradeLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreSummaryLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreLinkButton: UIButton!
    @IBOutlet private weak var tagsScrollView: UIScrollView!
    @IBOutlet private weak var tagsStackView: AdaptiveStackView!
    @IBOutlet private weak var nutritionHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var nutritionCard: AdaptiveView!
    @IBOutlet private weak var nutritionStackView: UIStackView!
    @IBOutlet private weak var ingredientsSection: UIView!
    @IBOutlet private weak var ingredientsHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var ingredientsCard: AdaptiveView!
    @IBOutlet private weak var ingredientsStackView: UIStackView!
    @IBOutlet private weak var recipeSection: UIView!
    @IBOutlet private weak var recipeHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var recipeCard: AdaptiveView!
    @IBOutlet private weak var recipeStackView: UIStackView!
    @IBOutlet private weak var suggestionSection: UIView!
    @IBOutlet private weak var suggestionHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var suggestionCard: AdaptiveView!
    @IBOutlet private weak var suggestionImageView: UIImageView!
    @IBOutlet private weak var suggestionEyebrowLabel: AdaptiveLabel!
    @IBOutlet private weak var suggestionNameLabel: AdaptiveLabel!
    @IBOutlet private weak var suggestionScoreCircle: AdaptiveView!
    @IBOutlet private weak var suggestionScoreLabel: AdaptiveLabel!
    @IBOutlet private weak var suggestionSummaryLabel: AdaptiveLabel!
    @IBOutlet private weak var addInsteadButton: UIButton!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var saveRecipeButton: UIButton!
    @IBOutlet private weak var wantToCookRow: WantToCookRowView!

    private let loadingOverlay = CustomLoadingOverlayView()
    private let viewModel: ProductDetailsViewModel

    init(viewModel: ProductDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "ProductDetailsViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .productDetails }

    override func viewDidLoad() {
        loadingOverlay.attach(to: view)
        configureChrome()
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.refreshInsights()
    }

    private func updateRelatedRecipe() {
        wantToCookRow.configure(recipe: viewModel.relatedRecipe.value,
                                loading: viewModel.relatedRecipeLoading.value,
                                unavailable: viewModel.relatedRecipeUnavailable.value)
    }

    override func bindViewModel() {
        viewModel.nameText.bind { [weak self] value in
            self?.nameLabel.text = value
        }
        viewModel.subtitleText.bind { [weak self] value in
            self?.subtitleLabel.text = value
        }
        viewModel.scoreGradeText.bind { [weak self] value in
            self?.scoreGradeLabel.text = value
        }
        viewModel.scoreTitleText.bind { [weak self] value in
            self?.scoreTitleLabel.text = value
        }
        viewModel.scoreSummaryText.bind { [weak self] value in
            self?.scoreSummaryLabel.text = value
        }
        viewModel.nutritionHeaderText.bind { [weak self] value in
            self?.applySectionHeader(self?.nutritionHeaderLabel, symbol: "info.circle", title: value)
        }
        viewModel.nutritionRows.bind { [weak self] rows in
            self?.renderNutrition(rows)
        }
        viewModel.tags.bind { [weak self] tags in
            self?.renderTags(tags)
        }
        viewModel.ingredients.bind { [weak self] items in
            self?.renderIngredients(items)
        }
        viewModel.wantToCookVisible.bind { [weak self] visible in
            self?.wantToCookRow.isHidden = !visible
        }
        viewModel.relatedRecipe.bind { [weak self] _ in self?.updateRelatedRecipe() }
        viewModel.relatedRecipeLoading.bind { [weak self] _ in self?.updateRelatedRecipe() }
        viewModel.relatedRecipeUnavailable.bind { [weak self] _ in self?.updateRelatedRecipe() }
        viewModel.canAddSuggestion.bind { [weak self] visible in
            self?.addInsteadButton.isHidden = !visible
        }
        viewModel.isLoading.bind { [weak self] loading in
            self?.loadingOverlay.setVisible(loading)
        }
        viewModel.suggestionVisible.bind { [weak self] visible in
            self?.suggestionSection.isHidden = !visible
        }
        viewModel.suggestionNameText.bind { [weak self] value in
            self?.suggestionNameLabel.text = value
        }
        viewModel.suggestionSummaryText.bind { [weak self] value in
            self?.suggestionSummaryLabel.text = value
        }
        viewModel.suggestionScoreText.bind { [weak self] value in
            self?.suggestionScoreLabel.text = value
        }
        viewModel.heroImage.bind { [weak self] image in
            self?.heroImageView.image = image
            self?.suggestionImageView.image = self?.viewModel.draft.value?.suggestion == nil ? image : nil
        }
        viewModel.showsAddToDiary.bind { [weak self] visible in
            self?.addButton.isHidden = !visible
        }
        viewModel.addButtonTitle.bind { [weak self] title in
            guard let self else { return }
            OnboardingStyle.stylePrimaryButton(self.addButton, title: title, systemImage: "plus")
        }
    }

    private func configureChrome() {
        view.backgroundColor = AppColor.gray6
        backgroundImageView.alpha = 0.18
        backgroundImageView.image = UIImage(named: "appBackground")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.isHidden = false
        view.sendSubviewToBack(backgroundImageView)
        titleLabel.text = L10n.tr("product.details.title")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.styleBackButton(backButton)
        OnboardingStyle.styleGlassSymbolButton(shareButton, systemName: "square.and.arrow.up")
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        [productCard, nutritionCard, ingredientsCard, recipeCard, suggestionCard].forEach { card in
            card?.useLiveGlass = false
            card?.applyCardShadow = true
        }
        scoreCircleView.useLiveGlass = false
        scoreCircleView.backgroundColor = AppColor.accentMint
        suggestionScoreCircle.useLiveGlass = false
        suggestionScoreCircle.backgroundColor = AppColor.accentMint
        heroImageView.contentMode = .scaleAspectFill
        heroImageView.clipsToBounds = true
        heroImageView.layer.cornerRadius = .adaptWidth(12)
        heroImageView.layer.cornerCurve = .continuous
        suggestionImageView.contentMode = .scaleAspectFill
        suggestionImageView.clipsToBounds = true
        suggestionImageView.layer.cornerRadius = .adaptWidth(12)
        OnboardingStyle.lockFigmaFont(nameLabel, size: 22, weight: .bold, color: AppColor.labelsPrimary, kern: -0.26)
        OnboardingStyle.lockFigmaFont(subtitleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(scoreGradeLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary)
        OnboardingStyle.lockFigmaFont(scoreTitleLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(scoreSummaryLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        scoreLinkButton.setTitle(L10n.tr("product.details.scoreLink"), for: .normal)
        OnboardingStyle.styleBorderlessButton(scoreLinkButton, title: L10n.tr("product.details.scoreLink"))
        scoreLinkButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        scoreLinkButton.contentHorizontalAlignment = .leading
        scoreLinkButton.addTarget(self, action: #selector(scoreInfoTapped), for: .touchUpInside)
        applySectionHeader(ingredientsHeaderLabel, symbol: "list.bullet.clipboard", title: L10n.tr("product.details.ingredients"))
        applySectionHeader(recipeHeaderLabel, symbol: "list.number", title: L10n.tr("recipes.generic"))
        applySectionHeader(suggestionHeaderLabel, symbol: "sparkles", title: L10n.tr("product.details.aiSuggestion"))
        suggestionEyebrowLabel.text = L10n.tr("product.details.aiInsight")
        OnboardingStyle.lockFigmaFont(suggestionEyebrowLabel, size: 17, weight: .semibold, color: AppColor.labelsSecondary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(suggestionNameLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(suggestionSummaryLabel, size: 17, weight: .regular, color: AppColor.labelsSecondary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(suggestionScoreLabel, size: 17, weight: .regular, color: .black)
        OnboardingStyle.styleTertiaryButton(addInsteadButton, title: L10n.tr("product.details.addInstead"))
        addInsteadButton.addTarget(self, action: #selector(addInsteadTapped), for: .touchUpInside)
        OnboardingStyle.stylePrimaryButton(addButton, title: L10n.tr("product.details.addToDiary"), systemImage: "plus")
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        saveRecipeButton.isHidden = true
        recipeSection.isHidden = true
        wantToCookRow.onTap = { [weak self] in
            self?.viewModel.wantToCookTapped()
        }
        tagsStackView.axis = .horizontal
        tagsStackView.alignment = .center
        tagsStackView.spacing = 6
        tagsStackView.adaptSpacing = true
        tagsStackView.setContentHuggingPriority(.required, for: .horizontal)
        tagsStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        OnboardingStyle.configureChatChipsCarousel(tagsScrollView)
        tagsScrollView.alwaysBounceHorizontal = false
        styleListCard(nutritionStackView)
        styleListCard(ingredientsStackView)
        styleListCard(recipeStackView)
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshTagsScroll()
    }

    private func renderTags(_ tags: [String]) {
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tags.forEach { title in
            let chip = ProductTagChipView()
            chip.configure(title)
            tagsStackView.addArrangedSubview(chip)
        }
        let isEmpty = tags.isEmpty
        tagsStackView.isHidden = isEmpty
        tagsScrollView.isHidden = isEmpty
        tagsScrollView.contentOffset = .zero
        view.setNeedsLayout()
    }

    private func refreshTagsScroll() {
        guard !tagsScrollView.isHidden else { return }
        tagsScrollView.layoutIfNeeded()
        let needsScroll = tagsScrollView.contentSize.width > tagsScrollView.bounds.width + 0.5
        tagsScrollView.isScrollEnabled = needsScroll
        tagsScrollView.alwaysBounceHorizontal = needsScroll
    }

    private func renderNutrition(_ rows: [ProductNutritionRow]) {
        nutritionStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rows.enumerated().forEach { index, row in
            let view = NutritionFactRowView()
            view.configure(title: row.title, value: row.value, dailyValue: row.dailyValue, showsSeparator: index > 0)
            nutritionStackView.addArrangedSubview(view)
        }
    }

    private func renderIngredients(_ items: [FoodIngredient]) {
        ingredientsSection.isHidden = items.isEmpty
        ingredientsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        items.enumerated().forEach { index, item in
            let view = IngredientLineView()
            view.configure(item, showsSeparator: index > 0, editable: false)
            ingredientsStackView.addArrangedSubview(view)
        }
    }

    @objc private func backTapped() {
        viewModel.backTapped()
    }

    @objc private func shareTapped() {
        viewModel.shareTapped()
    }

    @objc private func addTapped() {
        viewModel.addToDiaryTapped()
    }

    @objc private func scoreInfoTapped() {
        viewModel.scoreInfoTapped()
    }

    @objc private func addInsteadTapped() {
        viewModel.addSuggestionTapped()
    }
}
