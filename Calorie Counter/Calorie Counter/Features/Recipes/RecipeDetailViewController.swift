import Lottie
import UIKit

final class RecipeDetailViewController: BaseViewController {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var shareButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var heroCard: AdaptiveView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var nameLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var chipsStack: UIStackView!
    @IBOutlet private weak var tabTrack: AdaptiveView!
    @IBOutlet private weak var nutritionTabButton: UIButton!
    @IBOutlet private weak var ingredientsTabButton: UIButton!
    @IBOutlet private weak var instructionsTabButton: UIButton!
    @IBOutlet private weak var nutritionSection: UIStackView!
    @IBOutlet private weak var scoreCard: AdaptiveView!
    @IBOutlet private weak var scoreCircleView: AdaptiveView!
    @IBOutlet private weak var scoreGradeLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreSummaryLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreLinkButton: UIButton!
    @IBOutlet private weak var calorieShareCard: AdaptiveView!
    @IBOutlet private weak var calorieShareTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var calorieShareBodyLabel: AdaptiveLabel!
    @IBOutlet private weak var calorieRingView: RingProgressView!
    @IBOutlet private weak var caloriePercentLabel: AdaptiveLabel!
    @IBOutlet private weak var nutritionHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var nutritionStackView: UIStackView!
    @IBOutlet private weak var ingredientsSection: UIView!
    @IBOutlet private weak var ingredientsStackView: UIStackView!
    @IBOutlet private weak var instructionsSection: UIView!
    @IBOutlet private weak var stepsStackView: UIStackView!
    @IBOutlet private weak var sectionLoaderHost: UIView!
    @IBOutlet private weak var sectionLoaderView: LottieAnimationView!
    @IBOutlet private weak var footerView: UIView!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var saveButton: UIButton!

    private let savedAlert = StatusAlertOverlay()
    private let shareOverlay = CustomLoadingOverlayView()
    private let tabFillView = UIView()
    private let tabIndicatorView = UIView()
    private let footerBlurContainer = UIView()
    private let footerBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let footerBlurMask = CAGradientLayer()
    private let footerGradientView = UIView()
    private let footerFadeGradient = CAGradientLayer()
    private let viewModel: RecipeDetailViewModel
    private let detailsFailureStack = UIStackView()

    init(viewModel: RecipeDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "RecipeDetailViewController")
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
        shareOverlay.attach(to: view)
        viewModel.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutTabChrome()
        layoutFooterChrome()
        updateScrollInsets()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func bindViewModel() {
        viewModel.onDetailsUnavailable = { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            let alert = UIAlertController(title: L10n.tr("recipes.details.unavailableTitle"),
                                          message: L10n.tr("recipes.details.unavailableBody"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("recipes.details.retry"), style: .default) { [weak self] _ in
                self?.viewModel.retryDetails()
            })
            alert.addAction(UIAlertAction(title: L10n.tr("common.close"), style: .cancel))
            self.present(alert, animated: true)
        }

        viewModel.nameText.bind { [weak self] value in
            self?.nameLabel.text = value
        }
        viewModel.subtitleText.bind { [weak self] value in
            self?.subtitleLabel.text = value
            self?.subtitleLabel.isHidden = value.isEmpty
        }
        viewModel.chips.bind { [weak self] chips in
            self?.renderChips(chips)
        }
        viewModel.selectedTab.bind { [weak self] _ in
            self?.updateTabContent()
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
        viewModel.calorieShareTitleText.bind { [weak self] value in
            self?.calorieShareTitleLabel.text = value
        }
        viewModel.calorieShareBodyText.bind { [weak self] value in
            self?.calorieShareBodyLabel.text = value
        }
        viewModel.calorieShareProgress.bind { [weak self] value in
            self?.calorieRingView.progress = value
        }
        viewModel.calorieSharePercentText.bind { [weak self] value in
            self?.caloriePercentLabel.text = value
        }
        viewModel.nutritionRows.bind { [weak self] rows in
            self?.renderNutrition(rows)
        }
        viewModel.ingredients.bind { [weak self] items in
            self?.renderIngredients(items)
            self?.updateTabContent()
        }
        viewModel.steps.bind { [weak self] steps in
            self?.renderSteps(steps)
            self?.updateTabContent()
        }
        viewModel.heroImage.bind { [weak self] image in
            self?.photoImageView.image = image
            self?.photoImageView.contentMode = .scaleAspectFill
            self?.photoImageView.clipsToBounds = true
            self?.photoImageView.layer.masksToBounds = true
        }
        viewModel.isDetailsLoading.bind { [weak self] _ in
            self?.updateTabContent()
        }
        viewModel.isDetailsReady.bind { [weak self] _ in
            self?.updateTabContent()
        }
        viewModel.detailsUnavailable.bind { [weak self] _ in
            self?.updateTabContent()
        }
        viewModel.isSaved.bind { [weak self] saved in
            self?.applySaveButtonAppearance(isSaved: saved)
        }
        viewModel.savedAlertVisible.bind { [weak self] visible in
            self?.savedAlert.setVisible(visible)
        }
        viewModel.pendingConfirmText.bind { [weak self] message in
            guard let self, let message else { return }
            self.presentConfirmAlert(message: message)
        }
        viewModel.isSharePreparing.bind { [weak self] preparing in
            self?.shareOverlay.setVisible(preparing)
        }
    }

    private func configureChrome() {
        view.backgroundColor = AppColor.dynamic(light: AppColor.gray6, dark: .black)
        backgroundImageView.alpha = 0.18
        backgroundImageView.image = UIImage(named: "appBackground")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        refreshBackgroundAppearance()
        view.sendSubviewToBack(backgroundImageView)
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        scrollView.contentInsetAdjustmentBehavior = .never
        [backButton.superview, titleLabel, shareButton.superview, footerView]
            .compactMap { $0 }
            .forEach { view.bringSubviewToFront($0) }
        titleLabel.text = L10n.tr("recipes.generic")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(
            backButton,
            systemName: "chevron.backward",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        OnboardingStyle.styleGlassSymbolButton(
            shareButton,
            systemName: "square.and.arrow.up",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        [heroCard, scoreCard, calorieShareCard].forEach { card in
            card?.useLiveGlass = false
            card?.applyCardShadow = true
            card?.cardFillColor = AppColor.backgroundsPrimaryElevated
        }
        configureTabTrack()
        configureFooter()
        configureDetailsFailure()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: RecipeDetailViewController, _) in
            controller.refreshBackgroundAppearance()
            controller.refreshFooterColors()
            controller.layoutTabChrome()
        }
        scoreCircleView.useLiveGlass = false
        scoreCircleView.applyCardShadow = false
        scoreCircleView.clipsToBounds = true
        scoreCircleView.backgroundColor = AppColor.accentMint
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.masksToBounds = true
        photoImageView.layer.cornerRadius = .adaptWidth(16)
        photoImageView.layer.cornerCurve = .continuous
        OnboardingStyle.lockFigmaFont(nameLabel, size: 22, weight: .bold, color: AppColor.labelsPrimary, kern: -0.26)
        OnboardingStyle.lockFigmaFont(subtitleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(scoreGradeLabel, size: 17, weight: .semibold, color: .black)
        scoreGradeLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(scoreTitleLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(scoreSummaryLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(calorieShareTitleLabel, size: 15, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(calorieShareBodyLabel, size: 16, weight: .regular, color: AppColor.labelsPrimary, kern: -0.31)
        calorieShareBodyLabel.numberOfLines = 0
        OnboardingStyle.lockFigmaFont(caloriePercentLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        caloriePercentLabel.textAlignment = .center
        calorieRingView.progressColor = AppColor.accentMint
        calorieRingView.trackColor = AppColor.fillQuaternary
        calorieRingView.lineWidth = 10
        calorieRingView.clipsToBounds = true
        OnboardingStyle.styleBorderlessButton(scoreLinkButton, title: L10n.tr("product.details.scoreLink"))
        scoreLinkButton.setTitleColor(AppColor.dynamic(light: AppColor.tabSelected, dark: AppColor.teal), for: .normal)
        scoreLinkButton.titleLabel?.font = .systemFont(ofSize: .adaptFont(13), weight: .regular)
        scoreLinkButton.contentHorizontalAlignment = .leading
        scoreLinkButton.addTarget(self, action: #selector(scoreInfoTapped), for: .touchUpInside)
        nutritionHeaderLabel.text = L10n.tr("product.details.nutritionFacts")
        OnboardingStyle.lockFigmaFont(nutritionHeaderLabel, size: 15, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.23)
        configureTab(nutritionTabButton, title: L10n.tr("recipes.details.nutrition"), action: #selector(nutritionTabTapped))
        configureTab(ingredientsTabButton, title: L10n.tr("product.details.ingredients"), action: #selector(ingredientsTabTapped))
        configureTab(instructionsTabButton, title: L10n.tr("recipes.details.instructions"), action: #selector(instructionsTabTapped))
        OnboardingStyle.stylePrimaryButton(
            addButton,
            title: viewModel.addButtonTitle,
            systemImage: "plus"
        )
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        addButton.isHidden = !viewModel.showsAddToDiary
        applySaveButtonAppearance(isSaved: viewModel.isSaved.value)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        chipsStack.axis = .horizontal
        chipsStack.alignment = .center
        chipsStack.spacing = .adaptWidth(6)
        styleListCard(nutritionStackView)
        styleListCard(ingredientsStackView)
        styleListCard(stepsStackView)
        configureSectionLoader()
        updateTabContent()
    }

    private func configureTab(_ button: UIButton, title: String, action: Selector) {
        button.configuration = nil
        button.setTitle(title, for: .normal)
        button.backgroundColor = .clear
        button.clipsToBounds = true
        button.layer.cornerRadius = 0
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.textAlignment = .center
        button.addTarget(self, action: action, for: .touchUpInside)
        button.controlHaptic = .light
    }

    private func refreshBackgroundAppearance() {
        backgroundImageView.isHidden = traitCollection.userInterfaceStyle == .dark
    }

    private func configureTabTrack() {
        tabTrack.useLiveGlass = false
        tabTrack.applyCardShadow = false
        tabTrack.adaptCornerRadius = false
        tabTrack.backgroundColor = .clear
        tabTrack.clipsToBounds = false
        tabTrack.layer.masksToBounds = false
        tabFillView.translatesAutoresizingMaskIntoConstraints = true
        tabFillView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tabFillView.backgroundColor = AppColor.gray6
        tabFillView.clipsToBounds = true
        tabFillView.layer.masksToBounds = true
        tabFillView.isUserInteractionEnabled = false
        tabFillView.layer.cornerCurve = .continuous
        tabIndicatorView.clipsToBounds = true
        tabIndicatorView.layer.masksToBounds = true
        tabIndicatorView.backgroundColor = AppColor.teal
        tabIndicatorView.isUserInteractionEnabled = false
        tabIndicatorView.layer.cornerCurve = .continuous
        if tabFillView.superview !== tabTrack {
            tabTrack.insertSubview(tabFillView, at: 0)
        }
        if tabIndicatorView.superview !== tabFillView {
            tabFillView.addSubview(tabIndicatorView)
        }
        if let stack = nutritionTabButton.superview {
            stack.isUserInteractionEnabled = true
            stack.isHidden = false
            (stack as? UIStackView)?.alignment = .fill
            (stack as? UIStackView)?.distribution = .fillEqually
            (stack as? UIStackView)?.spacing = .adaptWidth(4)
            tabTrack.bringSubviewToFront(stack)
        }
        [nutritionTabButton, ingredientsTabButton, instructionsTabButton].forEach { button in
            button.isHidden = false
            button.isEnabled = true
            button.isUserInteractionEnabled = true
        }
        tabTrack.isHidden = false
        tabTrack.isUserInteractionEnabled = true
    }

    private func configureSectionLoader() {
        sectionLoaderHost.isHidden = true
        sectionLoaderHost.isUserInteractionEnabled = false
        sectionLoaderHost.backgroundColor = .clear
        sectionLoaderView.isUserInteractionEnabled = false
        sectionLoaderView.backgroundColor = .clear
        sectionLoaderView.isOpaque = false
        sectionLoaderView.contentMode = .scaleAspectFit
        sectionLoaderView.loopMode = .loop
        sectionLoaderView.backgroundBehavior = .pauseAndRestore
        sectionLoaderView.animation = LottieAnimation.named("CustomLoadingTransparent")
    }

    private func configureFooter() {
        footerView.backgroundColor = .clear
        footerView.clipsToBounds = false
        footerView.layer.cornerRadius = 0
        footerView.layer.maskedCorners = []
        footerView.layer.mask = nil
        footerBlurContainer.isUserInteractionEnabled = false
        footerBlurContainer.backgroundColor = .clear
        footerBlurView.isUserInteractionEnabled = false
        footerGradientView.isUserInteractionEnabled = false
        footerGradientView.backgroundColor = .clear
        if footerBlurView.superview !== footerBlurContainer {
            footerBlurContainer.addSubview(footerBlurView)
        }
        if footerBlurContainer.superview !== footerView {
            footerView.insertSubview(footerBlurContainer, at: 0)
        }
        if footerGradientView.superview !== footerView {
            footerView.insertSubview(footerGradientView, aboveSubview: footerBlurContainer)
        }
        footerBlurMask.startPoint = CGPoint(x: 0.5, y: 1)
        footerBlurMask.endPoint = CGPoint(x: 0.5, y: 0)
        footerBlurMask.colors = [
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(0.45).cgColor,
            UIColor.clear.cgColor
        ]
        footerBlurMask.locations = [0, 0.5, 0.95238]
        footerBlurContainer.layer.mask = footerBlurMask
        footerFadeGradient.startPoint = CGPoint(x: 0.5, y: 1)
        footerFadeGradient.endPoint = CGPoint(x: 0.5, y: 0)
        footerFadeGradient.locations = [0, 0.5, 0.95238]
        if footerFadeGradient.superlayer !== footerGradientView.layer {
            footerGradientView.layer.addSublayer(footerFadeGradient)
        }
        if let actions = addButton.superview {
            footerView.bringSubviewToFront(actions)
        }
        refreshFooterColors()
    }

    private func layoutTabChrome() {
        guard tabFillView.superview === tabTrack, tabTrack.bounds.width > 0, tabTrack.bounds.height > 0 else { return }
        let radius = tabTrack.bounds.height / 2
        tabTrack.layer.cornerRadius = radius
        tabTrack.layer.cornerCurve = .continuous
        tabTrack.layer.masksToBounds = false
        OnboardingStyle.applyCardFallbackShadow(tabTrack.layer, traits: traitCollection)
        if tabTrack.bounds.width > 0, tabTrack.bounds.height > 0 {
            tabTrack.layer.shadowPath = UIBezierPath(roundedRect: tabTrack.bounds, cornerRadius: radius).cgPath
        }
        tabFillView.frame = tabTrack.bounds
        tabFillView.clipsToBounds = true
        tabFillView.layer.masksToBounds = true
        tabFillView.layer.cornerRadius = radius
        tabFillView.backgroundColor = AppColor.gray6
        if tabIndicatorView.superview !== tabFillView {
            tabFillView.addSubview(tabIndicatorView)
        }
        let selected = selectedTabButton()
        let raw = selected.convert(selected.bounds, to: tabFillView)
        let frame = raw.intersection(tabFillView.bounds)
        guard frame.width > 4, frame.height > 4, frame.height <= tabFillView.bounds.height + 1 else {
            tabIndicatorView.frame = .zero
            return
        }
        tabIndicatorView.frame = frame
        tabIndicatorView.layer.cornerRadius = frame.height / 2
        tabIndicatorView.backgroundColor = AppColor.teal
    }

    private func layoutFooterChrome() {
        guard footerView.bounds.width > 0 else { return }
        footerView.layer.cornerRadius = 0
        footerBlurContainer.frame = footerView.bounds
        footerBlurView.frame = footerBlurContainer.bounds
        footerGradientView.frame = footerView.bounds
        footerFadeGradient.frame = footerGradientView.bounds
        footerBlurMask.frame = footerBlurContainer.bounds
        refreshFooterColors()
    }

    private func refreshFooterColors() {
        footerFadeGradient.colors = AppColor.fadeColors(
            from: AppColor.backgroundsPrimary,
            traits: traitCollection
        )
    }

    private func updateScrollInsets() {
        let overlap = footerView.bounds.height - view.safeAreaInsets.bottom
        let inset = max(overlap, 0)
        scrollView.contentInset.bottom = inset
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }

    private func selectedTabButton() -> UIButton {
        switch viewModel.selectedTab.value {
        case .nutrition: return nutritionTabButton
        case .ingredients: return ingredientsTabButton
        case .instructions: return instructionsTabButton
        }
    }

    private func updateTabContent() {
        let tab = viewModel.selectedTab.value
        styleTab(nutritionTabButton, selected: tab == .nutrition)
        styleTab(ingredientsTabButton, selected: tab == .ingredients)
        styleTab(instructionsTabButton, selected: tab == .instructions)
        [nutritionTabButton, ingredientsTabButton, instructionsTabButton].forEach { button in
            button.isHidden = false
            button.isEnabled = true
            button.isUserInteractionEnabled = true
        }
        let ready = viewModel.isDetailsReady.value
        let failed = viewModel.detailsUnavailable.value && !ready
        let showLoader = !ready && !failed
        nutritionSection.isHidden = tab != .nutrition || !ready
        ingredientsSection.isHidden = tab != .ingredients || !ready
        instructionsSection.isHidden = tab != .instructions || !ready
        sectionLoaderHost.isHidden = ready
        sectionLoaderView.isHidden = !showLoader
        detailsFailureStack.isHidden = !failed
        addButton.isEnabled = !viewModel.isDetailsLoading.value
        saveButton.isEnabled = !viewModel.isDetailsLoading.value
        shareButton.isEnabled = !viewModel.isDetailsLoading.value
        if showLoader {
            if sectionLoaderView.isAnimationPlaying == false {
                sectionLoaderView.play()
            }
        } else {
            sectionLoaderView.stop()
        }
        tabTrack.setNeedsLayout()
        view.setNeedsLayout()
    }

    private func configureDetailsFailure() {
        sectionLoaderHost.isUserInteractionEnabled = true
        let message = UILabel()
        message.text = L10n.tr("recipes.details.unavailableBody")
        message.textColor = AppColor.labelsSecondary
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.numberOfLines = 0
        message.textAlignment = .center
        let retry = UIButton(type: .system)
        retry.setTitle(L10n.tr("recipes.details.retry"), for: .normal)
        retry.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        retry.tintColor = AppColor.dynamic(light: AppColor.tabSelected, dark: AppColor.teal)
        retry.addAction(UIAction { [weak self] _ in self?.viewModel.retryDetails() }, for: .touchUpInside)
        retry.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        detailsFailureStack.axis = .vertical
        detailsFailureStack.alignment = .fill
        detailsFailureStack.spacing = 12
        detailsFailureStack.addArrangedSubview(message)
        detailsFailureStack.addArrangedSubview(retry)
        detailsFailureStack.translatesAutoresizingMaskIntoConstraints = false
        sectionLoaderHost.addSubview(detailsFailureStack)
        NSLayoutConstraint.activate([
            detailsFailureStack.leadingAnchor.constraint(equalTo: sectionLoaderHost.leadingAnchor, constant: 20),
            detailsFailureStack.trailingAnchor.constraint(equalTo: sectionLoaderHost.trailingAnchor, constant: -20),
            detailsFailureStack.centerYAnchor.constraint(equalTo: sectionLoaderHost.centerYAnchor)
        ])
        updateTabContent()
    }

    private func styleTab(_ button: UIButton, selected: Bool) {
        button.configuration = nil
        button.backgroundColor = .clear
        let title: String
        if button === nutritionTabButton {
            title = L10n.tr("recipes.details.nutrition")
        } else if button === ingredientsTabButton {
            title = L10n.tr("product.details.ingredients")
        } else {
            title = L10n.tr("recipes.details.instructions")
        }
        let color: UIColor = selected ? .black : AppColor.labelsPrimary
        let font = UIFont.systemFont(ofSize: 13, weight: selected ? .semibold : .medium)
        button.setTitle(title, for: .normal)
        button.setAttributedTitle(
            NSAttributedString(
                string: title,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .kern: -0.08
                ]
            ),
            for: .normal
        )
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = font
        button.titleLabel?.textAlignment = .center
    }

    private func renderChips(_ chips: [RecipeMetaChip]) {
        chipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chipsStack.isHidden = chips.isEmpty
        chips.forEach { chip in
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .capsule
            config.baseBackgroundColor = .black
            config.baseForegroundColor = .white
            config.image = UIImage(
                systemName: chip.symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            )
            config.title = chip.title
            config.imagePadding = 4
            config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var next = incoming
                next.font = .systemFont(ofSize: 15, weight: .regular)
                return next
            }
            button.configuration = config
            button.isUserInteractionEnabled = false
            chipsStack.addArrangedSubview(button)
        }
    }

    private func renderNutrition(_ rows: [ProductNutritionRow]) {
        nutritionStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rows.enumerated().forEach { index, row in
            let view = NutritionFactRowView()
            view.configure(
                title: row.title,
                value: row.value,
                dailyValue: row.dailyValue,
                showsSeparator: index > 0,
                separatorColor: AppColor.separatorVibrant
            )
            nutritionStackView.addArrangedSubview(view)
        }
    }

    private func renderIngredients(_ items: [FoodIngredient]) {
        ingredientsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        items.enumerated().forEach { index, item in
            let view = NutritionFactRowView()
            view.configure(
                title: item.name,
                value: ProductDetailsMath.formatIngredientAmount(item),
                dailyValue: nil,
                showsSeparator: index > 0,
                separatorColor: AppColor.separatorVibrant
            )
            ingredientsStackView.addArrangedSubview(view)
        }
    }

    private func renderSteps(_ steps: [String]) {
        stepsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        steps.enumerated().forEach { index, step in
            let view = RecipeStepRowView()
            view.configure(index: index + 1, text: step, showsSeparator: index > 0, mutedIndex: true)
            stepsStackView.addArrangedSubview(view)
        }
    }

    private func styleListCard(_ stack: UIStackView) {
        stack.backgroundColor = AppColor.backgroundsPrimaryElevated
        stack.layer.cornerRadius = .adaptWidth(24)
        stack.layer.cornerCurve = .continuous
        stack.clipsToBounds = true
        OnboardingStyle.applyCardFallbackShadow(stack.layer)
    }

    private func presentConfirmAlert(message: String) {
        let alert = UIAlertController(title: L10n.tr("recipes.applySwapTitle"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel) { [weak self] _ in
            self?.viewModel.rejectPendingSwap()
        })
        alert.addAction(UIAlertAction(title: L10n.tr("common.confirm"), style: .default) { [weak self] _ in
            self?.viewModel.confirmPendingSwap()
        })
        present(alert, animated: true)
    }

    @objc private func backTapped() { viewModel.backTapped() }
    @objc private func shareTapped() { viewModel.shareTapped() }
    @objc private func nutritionTabTapped() { viewModel.selectTab(.nutrition) }
    @objc private func ingredientsTabTapped() { viewModel.selectTab(.ingredients) }
    @objc private func instructionsTabTapped() { viewModel.selectTab(.instructions) }
    @objc private func scoreInfoTapped() { viewModel.scoreInfoTapped() }
    @objc private func addTapped() { viewModel.addToDiaryTapped() }
    @objc private func saveTapped() { viewModel.saveTapped() }

    private func applySaveButtonAppearance(isSaved: Bool) {
        // Clear the English nib title so UIKit cannot restore it on state changes.
        saveButton.setAttributedTitle(nil, for: .normal)
        saveButton.setTitle(L10n.tr(isSaved ? "common.saved" : "common.save"), for: .normal)
        OnboardingStyle.styleTertiaryButton(
            saveButton,
            title: L10n.tr(isSaved ? "common.saved" : "common.save")
        )
        saveButton.configuration?.baseForegroundColor = AppColor.labelsPrimary
        saveButton.configuration?.baseBackgroundColor = AppColor.dynamic(light: AppColor.fillSecondary, dark: AppColor.fillTertiary)
        saveButton.configuration?.image = UIImage(
            systemName: isSaved ? "bookmark.fill" : "bookmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        )
        saveButton.configuration?.imagePadding = 8
        saveButton.configuration?.imagePlacement = .leading
    }
}
