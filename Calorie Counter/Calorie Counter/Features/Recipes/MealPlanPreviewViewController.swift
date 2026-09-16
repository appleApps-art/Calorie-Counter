import UIKit

final class MealPlanPreviewViewController: BaseViewController {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var shareButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var heroCard: AdaptiveView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var nameLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var calorieShareCard: AdaptiveView!
    @IBOutlet private weak var calorieShareTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var calorieShareBodyLabel: AdaptiveLabel!
    @IBOutlet private weak var calorieRingView: RingProgressView!
    @IBOutlet private weak var caloriePercentLabel: AdaptiveLabel!
    @IBOutlet private weak var daysStack: UIStackView!
    @IBOutlet private weak var mealsStack: UIStackView!
    @IBOutlet private weak var headerScrimView: UIView!
    @IBOutlet private weak var footerView: UIView!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var editButton: UIButton!
    @IBOutlet private weak var deleteButton: UIButton!

    private let swappedAlert = StatusAlertOverlay()
    private let addedAlert = StatusAlertOverlay()
    private let footerBlurContainer = UIView()
    private let footerBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let footerBlurMask = CAGradientLayer()
    private let footerGradientView = UIView()
    private let footerFadeGradient = CAGradientLayer()
    private let headerScrimImageView = UIImageView()
    private let viewModel: MealPlanPreviewViewModel

    init(viewModel: MealPlanPreviewViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "MealPlanPreviewViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .mealPlanPreview }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureChrome()
        swappedAlert.attach(to: view)
        swappedAlert.configure(title: L10n.tr("recipes.mealPlan.swapped"))
        swappedAlert.onOK = { [weak self] in
            self?.viewModel.dismissSwappedAlert()
        }
        addedAlert.attach(to: view)
        addedAlert.onOK = { [weak self] in
            self?.viewModel.dismissAddedAlert()
        }
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutFooterChrome()
        updateScrollInsets()
        layoutHeaderScrim()
    }

    override func bindViewModel() {
        viewModel.nameText.bind { [weak self] value in
            self?.nameLabel.text = value
        }
        viewModel.subtitleText.bind { [weak self] value in
            self?.subtitleLabel.text = value
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
        viewModel.days.bind { [weak self] _ in
            self?.renderDays()
        }
        viewModel.selectedDayIndex.bind { [weak self] _ in
            self?.renderDays()
        }
        viewModel.selectedDay.bind { [weak self] day in
            self?.renderMeals(day)
        }
        viewModel.swappingRecipeIndex.bind { [weak self] _ in
            self?.renderMeals(self?.viewModel.selectedDay.value)
        }
        viewModel.heroImage.bind { [weak self] image in
            self?.photoImageView.image = image
            self?.photoImageView.contentMode = .scaleAspectFill
            self?.photoImageView.clipsToBounds = true
            self?.photoImageView.layer.masksToBounds = true
        }
        viewModel.swappedAlertVisible.bind { [weak self] visible in
            self?.swappedAlert.setVisible(visible)
        }
        viewModel.addedAlertVisible.bind { [weak self] visible in
            guard let self else { return }
            if visible {
                self.addedAlert.configure(title: self.viewModel.addedAlertTitle())
            }
            self.addedAlert.setVisible(visible)
        }
    }

    private func configureChrome() {
        view.backgroundColor = AppColor.backgroundsPrimary
        backgroundImageView.image = UIImage(named: "appBackground")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        refreshBackgroundAppearance()
        view.sendSubviewToBack(backgroundImageView)
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = false
        scrollView.contentInsetAdjustmentBehavior = .never
        mealsStack.alignment = .fill
        mealsStack.clipsToBounds = false
        configureHeaderScrim()
        titleLabel.text = L10n.tr("recipes.create.mealPlan")
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
        [heroCard, calorieShareCard].forEach { card in
            card?.useLiveGlass = false
            card?.applyCardShadow = true
            card?.cardFillColor = AppColor.backgroundsPrimaryElevated
        }
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerRadius = .adaptWidth(16)
        photoImageView.layer.cornerCurve = .continuous
        OnboardingStyle.lockFigmaFont(nameLabel, size: 22, weight: .bold, color: AppColor.labelsPrimary, kern: -0.26)
        OnboardingStyle.lockFigmaFont(subtitleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(calorieShareTitleLabel, size: 15, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(calorieShareBodyLabel, size: 16, weight: .regular, color: AppColor.labelsPrimary, kern: -0.31)
        calorieShareBodyLabel.numberOfLines = 0
        OnboardingStyle.lockFigmaFont(caloriePercentLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        caloriePercentLabel.textAlignment = .center
        calorieRingView.progressColor = AppColor.accentMint
        calorieRingView.trackColor = AppColor.fillQuaternary
        calorieRingView.lineWidth = 10
        OnboardingStyle.stylePrimaryButton(
            addButton,
            title: L10n.tr("product.details.addToDiary"),
            systemImage: "plus"
        )
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        OnboardingStyle.styleTertiaryButton(editButton, title: L10n.tr("recipes.mealPlan.editWithBity"))
        editButton.configuration?.baseForegroundColor = AppColor.labelsPrimary
        editButton.configuration?.baseBackgroundColor = AppColor.dynamic(light: AppColor.fillSecondary, dark: AppColor.fillTertiary)
        editButton.configuration?.image = UIImage(
            systemName: "wand.and.sparkles",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        )
        editButton.configuration?.imagePadding = 8
        editButton.configuration?.imagePlacement = .leading
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        OnboardingStyle.styleDestructiveButton(
            deleteButton,
            title: L10n.tr("recipes.mealPlan.delete"),
            systemImage: "trash"
        )
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        configureFooter()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: MealPlanPreviewViewController, _) in
            controller.refreshBackgroundAppearance()
        }
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
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: MealPlanPreviewViewController, _) in
            view.refreshFooterColors()
        }
        refreshFooterColors()
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
        if let actions = addButton.superview {
            footerView.bringSubviewToFront(actions)
        }
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

    private func configureHeaderScrim() {
        headerScrimView.isUserInteractionEnabled = false
        headerScrimView.clipsToBounds = true
        headerScrimView.backgroundColor = AppColor.backgroundsPrimary
        headerScrimImageView.image = UIImage(named: "appBackground")
        headerScrimImageView.contentMode = .scaleAspectFill
        headerScrimImageView.clipsToBounds = true
        refreshBackgroundAppearance()
        if headerScrimImageView.superview !== headerScrimView {
            headerScrimView.addSubview(headerScrimImageView)
        }
        view.bringSubviewToFront(headerScrimView)
        if let backWrap = backButton.superview {
            view.bringSubviewToFront(backWrap)
        }
        view.bringSubviewToFront(titleLabel)
        if let shareWrap = shareButton.superview {
            view.bringSubviewToFront(shareWrap)
        }
    }

    private func layoutHeaderScrim() {
        headerScrimImageView.frame = backgroundImageView.convert(
            backgroundImageView.bounds,
            to: headerScrimView
        )
    }

    private func refreshBackgroundAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundImageView.isHidden = isDark
        headerScrimImageView.isHidden = isDark
    }

    private func renderDays() {
        daysStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let selected = viewModel.selectedDayIndex.value
        viewModel.days.value.enumerated().forEach { index, day in
            let button = UIButton(type: .system)
            button.configuration = nil
            button.setTitle(day.title, for: .normal)
            let isSelected = index == selected
            button.backgroundColor = isSelected ? AppColor.teal : AppColor.fillQuaternary
            button.setTitleColor(isSelected ? AppColor.onAccent : AppColor.labelsPrimary, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: .adaptFont(13), weight: isSelected ? .semibold : .medium)
            button.layer.cornerRadius = .adaptHeight(16)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.addAction(UIAction { [weak self] _ in
                self?.viewModel.selectDay(index)
            }, for: .touchUpInside)
            daysStack.addArrangedSubview(button)
        }
    }

    private func renderMeals(_ day: MealPlanDay?) {
        mealsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let day else { return }
        var grouped: [(MealType, [MealPlanSlot])] = []
        day.slots.forEach { slot in
            if let index = grouped.firstIndex(where: { $0.0 == slot.mealType }) {
                grouped[index].1.append(slot)
            } else {
                grouped.append((slot.mealType, [slot]))
            }
        }
        let swappingIndex = viewModel.swappingRecipeIndex.value
        grouped.forEach { mealType, slots in
            let header = AdaptiveLabel()
            header.text = mealType.localizedTitle
            header.setContentHuggingPriority(.defaultLow, for: .horizontal)
            OnboardingStyle.lockFigmaFont(header, size: 15, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.23)
            mealsStack.addArrangedSubview(header)
            slots.forEach { slot in
                let row = MealPlanMealRowView()
                row.configure(slot, isSwapping: swappingIndex == slot.recipeIndex)
                row.onSwap = { [weak self] in
                    self?.viewModel.swapTapped(slot)
                }
                row.onOpen = { [weak self] in
                    self?.viewModel.recipeTapped(slot)
                }
                mealsStack.addArrangedSubview(row)
            }
        }
    }

    @objc private func backTapped() { viewModel.backTapped() }
    @objc private func shareTapped() { viewModel.shareTapped() }
    @objc private func addTapped() { viewModel.addToDiaryTapped() }
    @objc private func editTapped() { viewModel.editWithBityTapped() }
    @objc private func deleteTapped() { viewModel.deleteTapped() }
}
