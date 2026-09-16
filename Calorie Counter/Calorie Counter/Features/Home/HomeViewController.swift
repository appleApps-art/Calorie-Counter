import UIKit

enum HomeQuickLogAction {
    case scanFood
    case scanBarcode
    case search
    case voiceLog
}

final class HomeViewController: BaseViewController, UIScrollViewDelegate {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var mainScrollView: UIScrollView!
    @IBOutlet private weak var carouselScrollView: UIScrollView!
    @IBOutlet private weak var calorieCardView: AdaptiveView!
    @IBOutlet private weak var calorieTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriePercentLabel: AdaptiveLabel!
    @IBOutlet private weak var calorieCaptionLabel: AdaptiveLabel!
    @IBOutlet private weak var calorieRingView: RingProgressView!
    @IBOutlet private weak var foodCaptionLabel: AdaptiveLabel!
    @IBOutlet private weak var foodValueLabel: AdaptiveLabel!
    @IBOutlet private weak var remainingCaptionLabel: AdaptiveLabel!
    @IBOutlet private weak var remainingValueLabel: AdaptiveLabel!
    @IBOutlet private weak var macrosCardView: AdaptiveView!
    @IBOutlet private weak var macrosTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var carbsTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var fatsTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinPercentLabel: AdaptiveLabel!
    @IBOutlet private weak var carbsPercentLabel: AdaptiveLabel!
    @IBOutlet private weak var fatPercentLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinRingView: RingProgressView!
    @IBOutlet private weak var carbsRingView: RingProgressView!
    @IBOutlet private weak var fatRingView: RingProgressView!
    @IBOutlet private weak var fiberCaptionLabel: AdaptiveLabel!
    @IBOutlet private weak var sugarCaptionLabel: AdaptiveLabel!
    @IBOutlet private weak var sodiumCaptionLabel: AdaptiveLabel!
    @IBOutlet private weak var fiberValueLabel: AdaptiveLabel!
    @IBOutlet private weak var sugarValueLabel: AdaptiveLabel!
    @IBOutlet private weak var sodiumValueLabel: AdaptiveLabel!
    @IBOutlet private weak var burnCardView: AdaptiveView!
    @IBOutlet private weak var burnTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var burnPercentLabel: AdaptiveLabel!
    @IBOutlet private weak var burnCaptionLabel: AdaptiveLabel!
    @IBOutlet private weak var burnRingView: RingProgressView!
    @IBOutlet private weak var exerciseCaptionLabel: AdaptiveLabel!
    @IBOutlet private weak var exerciseValueLabel: AdaptiveLabel!
    @IBOutlet private weak var burnRemainingCaptionLabel: AdaptiveLabel!
    @IBOutlet private weak var burnRemainingValueLabel: AdaptiveLabel!
    @IBOutlet private weak var pageControl: UIPageControl!
    @IBOutlet private weak var diaryTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var markAllEatenButton: UIButton!
    @IBOutlet private weak var diaryAddButton: UIButton!
    @IBOutlet private weak var breakfastCard: MealCardView!
    @IBOutlet private weak var lunchCard: MealCardView!
    @IBOutlet private weak var snacksCard: MealCardView!
    @IBOutlet private weak var dinnerCard: MealCardView!
    @IBOutlet private weak var waterCardView: AdaptiveView!
    @IBOutlet private weak var waterTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var waterRangeLabel: AdaptiveLabel!
    @IBOutlet private weak var waterHintLabel: AdaptiveLabel!
    @IBOutlet private weak var waterEditButton: UIButton!
    @IBOutlet private weak var waterMinusButton: UIButton!
    @IBOutlet private weak var waterPlusButton: UIButton!
    @IBOutlet private var waterGlasses: [WaterGlassView]!

    private let viewModel: HomeViewModel
    private var lastAppliedDisplay: HomeDisplay?
    private var hasAppliedWaterFills = false
    var onQuickLog: ((HomeQuickLogAction) -> Void)?
    var onEditMeal: ((MealType, Date) -> Void)?
    var onOpenFood: ((FoodEntry) -> Void)?
    var onOpenProfile: (() -> Void)?
    var onOpenStreak: (() -> Void)?
    var displayedDate: Date { viewModel.selectedDate.value }
    private let homeHeaderView = HomeNavigationHeaderView()
    private var lastCarouselPage = 0
    private let streakButton = UIButton(type: .custom)
    private let profileButton = UIButton(type: .custom)
    private var didInstallHomeHeader = false
    private let dateTitleLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "HomeViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .home }

    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundImageView.image = UIImage(named: "appBackground")
        backgroundImageView.contentMode = .scaleAspectFill
        view.backgroundColor = .clear
        disableCardLiveGlass(in: view)
        mainScrollView.clipsToBounds = false
        carouselScrollView.delegate = self
        carouselScrollView.isPagingEnabled = true
        carouselScrollView.showsHorizontalScrollIndicator = false
        carouselScrollView.clipsToBounds = false
        if let slides = carouselScrollView.subviews.first {
            slides.clipsToBounds = false
            slides.subviews.forEach { $0.clipsToBounds = false }
        }
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = nil
        installHomeHeader()
        clearScrollChrome()
        styleStaticCopy()
        styleRings()
        styleStatPills()
        styleButtons()
        layoutHomeSections()
        installWaterStepper()
        disableCardLiveGlass(in: view)
        installStatDots()
        wireCards()
        viewModel.viewDidLoad()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: HomeViewController, _) in
            controller.lastAppliedDisplay = nil
            controller.apply(controller.viewModel.screen.value)
            controller.styleRings()
            controller.styleStatPills()
            controller.refreshHeaderButtons()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.tabBarItem.title = L10n.tr("tab.home")
        viewModel.reload()
    }

    override func bindViewModel() {
        viewModel.screen.bind { [weak self] display in
            self?.apply(display)
        }
        viewModel.streakCount.bind { [weak self] _ in
            self?.refreshHeaderButtons()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        if page != lastCarouselPage {
            lastCarouselPage = page
            Haptics.selection()
        }
        pageControl.currentPage = page
    }

    private func styleStaticCopy() {
        calorieTitleLabel.text = L10n.tr("home.calorieBudgetTitle")
        calorieCaptionLabel.text = L10n.tr("home.ofGoal")
        foodCaptionLabel.text = L10n.tr("home.foodCaption")
        remainingCaptionLabel.text = L10n.tr("home.intakeRemainingCaption")
        macrosTitleLabel.text = L10n.tr("home.macroGoalsTitle")
        proteinTitleLabel.text = L10n.tr("home.protein")
        carbsTitleLabel.text = L10n.tr("home.carbs")
        fatsTitleLabel.text = L10n.tr("home.fats")
        fiberCaptionLabel.text = L10n.tr("home.fiber")
        sugarCaptionLabel.text = L10n.tr("home.sugar")
        sodiumCaptionLabel.text = L10n.tr("home.sodium")
        burnTitleLabel.text = L10n.tr("home.burnGoalTitle")
        burnCaptionLabel.text = L10n.tr("home.ofGoal")
        exerciseCaptionLabel.text = L10n.tr("home.exerciseCaption")
        burnRemainingCaptionLabel.text = L10n.tr("home.remainingCaption")
        diaryTitleLabel.text = L10n.tr("home.foodDiary")
        waterTitleLabel.text = L10n.tr("home.waterIntake")
        let title = AppColor.labelVibrantPrimary
        let chart = AppColor.labelsPrimary
        let secondary = AppColor.labelsSecondary
        OnboardingStyle.lockFigmaFont(calorieTitleLabel, size: 15, weight: .semibold, color: title, kern: -0.23)
        OnboardingStyle.lockFigmaFont(macrosTitleLabel, size: 15, weight: .semibold, color: title, kern: -0.23)
        OnboardingStyle.lockFigmaFont(burnTitleLabel, size: 15, weight: .semibold, color: title, kern: -0.23)
        OnboardingStyle.lockFigmaFont(diaryTitleLabel, size: 15, weight: .semibold, color: title, kern: -0.23)
        diaryTitleLabel.numberOfLines = 2
        diaryTitleLabel.lineBreakMode = .byWordWrapping
        OnboardingStyle.lockFigmaFont(waterTitleLabel, size: 15, weight: .semibold, color: title, kern: -0.23)
        OnboardingStyle.lockFigmaFont(calorieCaptionLabel, size: 13, weight: .regular, color: secondary, kern: 0.07)
        OnboardingStyle.lockFigmaFont(burnCaptionLabel, size: 13, weight: .regular, color: secondary, kern: 0.07)
        OnboardingStyle.lockFigmaFont(proteinTitleLabel, size: 15, weight: .regular, color: chart, kern: -0.1)
        OnboardingStyle.lockFigmaFont(carbsTitleLabel, size: 15, weight: .regular, color: chart, kern: -0.1)
        OnboardingStyle.lockFigmaFont(fatsTitleLabel, size: 15, weight: .regular, color: chart, kern: -0.1)
        OnboardingStyle.lockFigmaFont(foodCaptionLabel, size: 12, weight: .regular, color: secondary)
        OnboardingStyle.lockFigmaFont(remainingCaptionLabel, size: 12, weight: .regular, color: secondary)
        OnboardingStyle.lockFigmaFont(exerciseCaptionLabel, size: 12, weight: .regular, color: secondary)
        OnboardingStyle.lockFigmaFont(burnRemainingCaptionLabel, size: 12, weight: .regular, color: secondary)
        OnboardingStyle.lockFigmaFont(fiberCaptionLabel, size: 13, weight: .regular, color: AppColor.iconSecondary, kern: -0.08)
        OnboardingStyle.lockFigmaFont(sugarCaptionLabel, size: 13, weight: .regular, color: AppColor.iconSecondary, kern: -0.08)
        OnboardingStyle.lockFigmaFont(sodiumCaptionLabel, size: 13, weight: .regular, color: AppColor.iconSecondary, kern: -0.08)
        pageControl.numberOfPages = 3
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = AppColor.teal
        pageControl.pageIndicatorTintColor = AppColor.pageIndicator
        pageControl.backgroundColor = .clear
        pageControl.backgroundStyle = .minimal
        pageControl.isUserInteractionEnabled = false
    }

    private func styleRings() {
        calorieRingView.lineWidth = 13
        calorieRingView.trackColor = OnboardingStyle.fillQuaternary
        calorieRingView.progressColor = AppColor.teal
        burnRingView.lineWidth = 13
        burnRingView.trackColor = OnboardingStyle.fillQuaternary
        burnRingView.progressColor = AppColor.teal
        proteinRingView.lineWidth = 8
        proteinRingView.trackColor = OnboardingStyle.fillQuaternary
        proteinRingView.progressColor = AppColor.accentBlue
        carbsRingView.lineWidth = 8
        carbsRingView.trackColor = OnboardingStyle.fillQuaternary
        carbsRingView.progressColor = AppColor.accentIndigo
        fatRingView.lineWidth = 8
        fatRingView.trackColor = OnboardingStyle.fillQuaternary
        fatRingView.progressColor = AppColor.accentMint
    }

    private func styleButtons() {
        OnboardingStyle.styleGlassButton(
            markAllEatenButton,
            title: L10n.tr("home.markAllEaten"),
            foregroundColor: AppColor.labelVibrantPrimary,
            weight: .regular
        )
        markAllEatenButton.setContentHuggingPriority(.required, for: .horizontal)
        OnboardingStyle.styleGlassSymbolButton(
            diaryAddButton,
            systemName: "plus",
            foregroundColor: AppColor.teal
        )
        OnboardingStyle.styleGlassSymbolButton(
            waterEditButton,
            systemName: "pencil",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        markAllEatenButton.addTarget(self, action: #selector(markAllEatenTapped), for: .touchUpInside)
        diaryAddButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        waterEditButton.addTarget(self, action: #selector(waterEditTapped), for: .touchUpInside)
        waterMinusButton.addTarget(self, action: #selector(waterMinusTapped), for: .touchUpInside)
        waterPlusButton.addTarget(self, action: #selector(waterPlusTapped), for: .touchUpInside)
        waterMinusButton.controlHaptic = .selection
        waterPlusButton.controlHaptic = .selection
        markAllEatenButton.controlHaptic = .medium
    }

    private func wireCards() {
        for card in [breakfastCard, lunchCard, snacksCard, dinnerCard] {
            card?.onEdit = { [weak self] mealType in
                guard let self else { return }
                self.onEditMeal?(mealType, self.viewModel.selectedDate.value)
            }
            card?.onToggleFood = { [weak self] id in
                self?.viewModel.toggleEaten(id: id)
            }
            card?.onOpenFood = { [weak self] id in
                guard let entry = self?.viewModel.foodEntry(id: id) else { return }
                self?.onOpenFood?(entry)
            }
        }
    }

    private func apply(_ display: HomeDisplay) {
        let previous = lastAppliedDisplay
        guard previous != display else { return }
        lastAppliedDisplay = display
        if previous?.dateTitle != display.dateTitle {
            dateTitleLabel.text = display.dateTitle
            OnboardingStyle.lockFigmaFont(dateTitleLabel, size: 28, weight: .bold, color: AppColor.labelVibrantPrimary, kern: 0.38)
        }
        if previous?.caloriePercentText != display.caloriePercentText {
            caloriePercentLabel.text = display.caloriePercentText
            OnboardingStyle.lockFigmaFont(caloriePercentLabel, size: 33, weight: .bold, color: AppColor.labelsPrimary, kern: 0.45)
        }
        if previous?.calorieProgress != display.calorieProgress {
            calorieRingView.progress = CGFloat(display.calorieProgress)
        }
        if previous?.foodValueText != display.foodValueText {
            foodValueLabel.text = display.foodValueText
            OnboardingStyle.lockFigmaFont(foodValueLabel, size: 15, weight: .regular, color: AppColor.labelsPrimary, kern: -0.23)
        }
        if previous?.remainingValueText != display.remainingValueText {
            remainingValueLabel.text = display.remainingValueText
            OnboardingStyle.lockFigmaFont(remainingValueLabel, size: 15, weight: .regular, color: AppColor.labelsPrimary, kern: -0.23)
        }
        if previous?.proteinPercentText != display.proteinPercentText {
            proteinPercentLabel.text = display.proteinPercentText
            OnboardingStyle.lockFigmaFont(proteinPercentLabel, size: 20.25, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        }
        if previous?.carbsPercentText != display.carbsPercentText {
            carbsPercentLabel.text = display.carbsPercentText
            OnboardingStyle.lockFigmaFont(carbsPercentLabel, size: 20.25, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        }
        if previous?.fatPercentText != display.fatPercentText {
            fatPercentLabel.text = display.fatPercentText
            OnboardingStyle.lockFigmaFont(fatPercentLabel, size: 20.25, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        }
        if previous?.proteinProgress != display.proteinProgress {
            proteinRingView.progress = CGFloat(display.proteinProgress)
        }
        if previous?.carbsProgress != display.carbsProgress {
            carbsRingView.progress = CGFloat(display.carbsProgress)
        }
        if previous?.fatProgress != display.fatProgress {
            fatRingView.progress = CGFloat(display.fatProgress)
        }
        if previous?.fiberValueText != display.fiberValueText {
            fiberValueLabel.text = display.fiberValueText
            OnboardingStyle.lockFigmaFont(fiberValueLabel, size: 13, weight: .regular, color: AppColor.labelsPrimary, kern: -0.08)
        }
        if previous?.sugarValueText != display.sugarValueText {
            sugarValueLabel.text = display.sugarValueText
            OnboardingStyle.lockFigmaFont(sugarValueLabel, size: 13, weight: .regular, color: AppColor.labelsPrimary, kern: -0.08)
        }
        if previous?.sodiumValueText != display.sodiumValueText {
            sodiumValueLabel.text = display.sodiumValueText
            OnboardingStyle.lockFigmaFont(sodiumValueLabel, size: 13, weight: .regular, color: AppColor.labelsPrimary, kern: -0.08)
        }
        if previous?.exercisePercentText != display.exercisePercentText {
            burnPercentLabel.text = display.exercisePercentText
            OnboardingStyle.lockFigmaFont(burnPercentLabel, size: 33, weight: .bold, color: AppColor.labelsPrimary, kern: 0.45)
        }
        if previous?.exerciseProgress != display.exerciseProgress {
            burnRingView.progress = CGFloat(display.exerciseProgress)
        }
        if previous?.exerciseValueText != display.exerciseValueText {
            exerciseValueLabel.text = display.exerciseValueText
            OnboardingStyle.lockFigmaFont(exerciseValueLabel, size: 15, weight: .regular, color: AppColor.labelsPrimary, kern: -0.23)
        }
        if previous?.burnRemainingText != display.burnRemainingText {
            burnRemainingValueLabel.text = display.burnRemainingText
            OnboardingStyle.lockFigmaFont(burnRemainingValueLabel, size: 15, weight: .regular, color: AppColor.labelsPrimary, kern: -0.23)
        }
        if previous?.waterRangeText != display.waterRangeText {
            waterRangeLabel.text = display.waterRangeText
            OnboardingStyle.lockFigmaFont(waterRangeLabel, size: 12, weight: .medium, color: AppColor.iconSecondary)
        }
        if previous?.waterHintText != display.waterHintText {
            waterHintLabel.text = display.waterHintText
            OnboardingStyle.lockFigmaFont(waterHintLabel, size: 12, weight: .medium, color: AppColor.iconSecondary)
        }
        zip(mealCards, display.meals).forEach { card, section in
            if previous?.meals.first(where: { $0.mealType == section.mealType }) != section {
                card.configure(section)
            }
        }
        guard previous?.waterFills != display.waterFills else { return }
        let fills = display.waterFills
        let glasses = (waterGlasses ?? []).sorted { $0.tag < $1.tag }
        let animated = hasAppliedWaterFills
        hasAppliedWaterFills = true
        glasses.enumerated().forEach { index, glass in
            let target = CGFloat(index < fills.count ? fills[index] : 0)
            guard !animated || abs(glass.fillProgress - target) > 0.001 else { return }
            let delay = animated
                ? TimeInterval(index) * 0.05
                : 0
            glass.setFillProgress(target, animated: animated, delay: delay)
        }
    }

    private var mealCards: [MealCardView] {
        [breakfastCard, lunchCard, snacksCard, dinnerCard]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHomeHeaderWidth()
    }

    private func installHomeHeader() {
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItems = nil
        navigationItem.title = nil
        navigationItem.titleView = homeHeaderView
        dateTitleLabel.isUserInteractionEnabled = false
        dateTitleLabel.backgroundColor = .clear
        dateTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        dateTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        OnboardingStyle.lockFigmaFont(dateTitleLabel, size: 28, weight: .bold, color: AppColor.labelVibrantPrimary, kern: 0.38)
        guard didInstallHomeHeader == false else {
            refreshHeaderButtons()
            return
        }
        didInstallHomeHeader = true
        homeHeaderView.backgroundColor = .clear
        dateTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        streakButton.translatesAutoresizingMaskIntoConstraints = false
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        homeHeaderView.addSubview(dateTitleLabel)
        homeHeaderView.addSubview(streakButton)
        homeHeaderView.addSubview(profileButton)
        streakButton.addTarget(self, action: #selector(streakTapped), for: .touchUpInside)
        profileButton.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        let side = CGFloat.adaptWidth(44)
        NSLayoutConstraint.activate([
            homeHeaderView.heightAnchor.constraint(equalToConstant: side),
            dateTitleLabel.leadingAnchor.constraint(equalTo: homeHeaderView.leadingAnchor),
            dateTitleLabel.centerYAnchor.constraint(equalTo: homeHeaderView.centerYAnchor),
            profileButton.trailingAnchor.constraint(equalTo: homeHeaderView.trailingAnchor),
            profileButton.centerYAnchor.constraint(equalTo: homeHeaderView.centerYAnchor),
            profileButton.widthAnchor.constraint(equalToConstant: side),
            profileButton.heightAnchor.constraint(equalToConstant: side),
            streakButton.trailingAnchor.constraint(equalTo: profileButton.leadingAnchor, constant: -.adaptWidth(8)),
            streakButton.centerYAnchor.constraint(equalTo: homeHeaderView.centerYAnchor),
            streakButton.heightAnchor.constraint(equalToConstant: side),
            streakButton.widthAnchor.constraint(greaterThanOrEqualToConstant: .adaptWidth(64)),
            dateTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: streakButton.leadingAnchor, constant: -.adaptWidth(8))
        ])
        refreshHeaderButtons()
        updateHomeHeaderWidth()
    }

    private func refreshHeaderButtons() {
        let side = CGFloat.adaptWidth(44)
        OnboardingStyle.styleGlassSymbolButton(
            profileButton,
            systemName: "person",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        profileButton.layer.cornerRadius = side / 2
        OnboardingStyle.styleGlassSymbolButton(
            streakButton,
            systemName: "flame.fill",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        let count = "\(viewModel.streakCount.value)"
        if var config = streakButton.configuration {
            config.title = count
            config.imagePadding = 4
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
            streakButton.configuration = config
        } else {
            streakButton.setTitle(count, for: .normal)
        }
        streakButton.layer.cornerRadius = side / 2
    }

    private func updateHomeHeaderWidth() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        let inset = navigationBar.layoutMargins.left + navigationBar.layoutMargins.right
        let width = min(728, max(0, navigationBar.bounds.width - inset))
        homeHeaderView.preferredWidth = width
        homeHeaderView.invalidateIntrinsicContentSize()
    }

    private func styleStatPills() {
        [
            foodCaptionLabel.superview,
            remainingCaptionLabel.superview,
            exerciseCaptionLabel.superview,
            burnRemainingCaptionLabel.superview,
            fiberCaptionLabel.superview,
            sugarCaptionLabel.superview,
            sodiumCaptionLabel.superview
        ]
        .compactMap { $0 }
        .forEach { pill in
            if let adaptive = pill as? AdaptiveView {
                adaptive.useLiveGlass = false
            }
            pill.backgroundColor = AppColor.fillQuaternary
        }
    }

    @objc
    private func streakTapped() {
        onOpenStreak?()
    }

    private func disableCardLiveGlass(in view: UIView) {
        if let adaptive = view as? AdaptiveView, adaptive.applyCardShadow {
            adaptive.useLiveGlass = false
        }
        view.subviews.forEach { disableCardLiveGlass(in: $0) }
    }

    private func clearScrollChrome() {
        carouselScrollView.backgroundColor = .clear
        if let slides = carouselScrollView.subviews.first {
            slides.backgroundColor = .clear
            slides.subviews.forEach { $0.backgroundColor = .clear }
        }
        diaryTitleLabel.superview?.backgroundColor = .clear
        mealCards.forEach { $0.backgroundColor = .clear }
        var node: UIView? = carouselScrollView.superview
        while let view = node, view !== backgroundImageView.superview {
            view.backgroundColor = .clear
            node = view.superview
        }
        if #available(iOS 26.0, *) {
            hideScrollEdgeEffects(carouselScrollView)
            mainScrollView.bottomEdgeEffect.style = .soft
            mainScrollView.topEdgeEffect.isHidden = true
            mainScrollView.leftEdgeEffect.isHidden = true
            mainScrollView.rightEdgeEffect.isHidden = true
        }
    }

    @available(iOS 26.0, *)
    private func hideScrollEdgeEffects(_ scroll: UIScrollView) {
        scroll.topEdgeEffect.isHidden = true
        scroll.bottomEdgeEffect.isHidden = true
        scroll.leftEdgeEffect.isHidden = true
        scroll.rightEdgeEffect.isHidden = true
    }

    private func layoutHomeSections() {
        guard let body = carouselScrollView.superview as? UIStackView else { return }
        body.alignment = .center
        body.spacing = 0
        carouselScrollView.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        pageControl.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        [diaryTitleLabel.superview, breakfastCard, lunchCard, snacksCard, dinnerCard, waterCardView]
            .compactMap { $0 }
            .forEach { view in
                let preferred = view.widthAnchor.constraint(equalTo: body.widthAnchor, constant: -32)
                preferred.priority = .defaultHigh
                NSLayoutConstraint.activate([
                    preferred,
                    view.widthAnchor.constraint(lessThanOrEqualTo: body.widthAnchor, constant: -32),
                    view.widthAnchor.constraint(lessThanOrEqualToConstant: 680)
                ])
            }
        body.setCustomSpacing(0, after: carouselScrollView)
        body.setCustomSpacing(0, after: pageControl)
        if let header = diaryTitleLabel.superview {
            body.setCustomSpacing(.adaptHeight(8), after: header)
        }
        [breakfastCard, lunchCard, snacksCard, dinnerCard]
            .compactMap { $0 }
            .forEach { body.setCustomSpacing(.adaptHeight(8), after: $0) }
        orderCarouselSlides()
        layoutStatPills()
        layoutWaterGlasses()
        waterTitleLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: waterEditButton.leadingAnchor,
            constant: -.adaptWidth(10)
        ).isActive = true
        waterRangeLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: waterEditButton.leadingAnchor,
            constant: -.adaptWidth(10)
        ).isActive = true
    }

    private func orderCarouselSlides() {
        guard let slides = carouselScrollView.subviews.compactMap({ $0 as? UIStackView }).first else { return }
        guard slides.arrangedSubviews.count == 3,
              let burnSlide = burnCardView.superview,
              let macrosSlide = macrosCardView.superview,
              slides.arrangedSubviews[1] === macrosSlide
        else { return }
        slides.removeArrangedSubview(burnSlide)
        slides.insertArrangedSubview(burnSlide, at: 1)
    }

    private func installWaterStepper() {
        guard let card = waterCardView else { return }
        guard let glasses = waterGlasses?.first?.superview else { return }
        OnboardingStyle.stylePlainSymbolButton(
            waterMinusButton,
            systemName: "minus",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        OnboardingStyle.stylePlainSymbolButton(
            waterPlusButton,
            systemName: "plus",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        if waterMinusButton.superview !== card, waterPlusButton.superview !== card {
            return
        }
        card.constraints
            .filter { constraint in
                constraint.firstItem === waterMinusButton
                    || constraint.secondItem === waterMinusButton
                    || constraint.firstItem === waterPlusButton
                    || constraint.secondItem === waterPlusButton
                    || (constraint.firstItem === card
                        && constraint.secondItem === waterHintLabel
                        && constraint.firstAttribute == .bottom)
                    || (constraint.firstItem === waterHintLabel
                        && constraint.firstAttribute == .top)
            }
            .forEach { $0.isActive = false }
        [waterMinusButton, waterPlusButton].forEach { button in
            button.constraints
                .filter { $0.firstAttribute == .width || $0.firstAttribute == .height }
                .forEach { $0.isActive = false }
        }
        let stepper = AdaptiveView()
        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.adaptCornerRadius = true
        stepper.applyButtonGlass = true
        stepper.showsDropShadow = true
        stepper.showsHairlineBorder = false
        stepper.designCornerRadius = 100
        card.addSubview(stepper)
        waterMinusButton.removeFromSuperview()
        waterPlusButton.removeFromSuperview()
        stepper.addSubview(waterMinusButton)
        stepper.addSubview(waterPlusButton)
        waterMinusButton.translatesAutoresizingMaskIntoConstraints = false
        waterPlusButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stepper.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -.adaptWidth(12)),
            stepper.topAnchor.constraint(
                equalTo: glasses.bottomAnchor,
                constant: .adaptHeight(12)
            ),
            stepper.widthAnchor.constraint(equalToConstant: .adaptWidth(104)),
            stepper.heightAnchor.constraint(equalToConstant: .adaptHeight(44)),
            stepper.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -.adaptHeight(12)),
            waterHintLabel.centerYAnchor.constraint(equalTo: stepper.centerYAnchor),
            waterHintLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: stepper.leadingAnchor,
                constant: -.adaptWidth(24)
            ),
            waterMinusButton.leadingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: .adaptWidth(6)),
            waterMinusButton.centerYAnchor.constraint(equalTo: stepper.centerYAnchor),
            waterMinusButton.widthAnchor.constraint(equalToConstant: .adaptWidth(36)),
            waterMinusButton.heightAnchor.constraint(equalToConstant: .adaptHeight(36)),
            waterPlusButton.leadingAnchor.constraint(equalTo: waterMinusButton.trailingAnchor, constant: .adaptWidth(20)),
            waterPlusButton.trailingAnchor.constraint(equalTo: stepper.trailingAnchor, constant: -.adaptWidth(6)),
            waterPlusButton.centerYAnchor.constraint(equalTo: stepper.centerYAnchor),
            waterPlusButton.widthAnchor.constraint(equalToConstant: .adaptWidth(36)),
            waterPlusButton.heightAnchor.constraint(equalToConstant: .adaptHeight(36))
        ])
        stepper.bringSubviewToFront(waterMinusButton)
        stepper.bringSubviewToFront(waterPlusButton)
    }

    private func layoutStatPills() {
        [foodCaptionLabel.superview?.superview, exerciseCaptionLabel.superview?.superview]
            .compactMap { $0 as? UIStackView }
            .forEach { stack in
                stack.distribution = .equalSpacing
            }
        [foodCaptionLabel, remainingCaptionLabel, exerciseCaptionLabel, burnRemainingCaptionLabel]
            .compactMap { $0 }
            .forEach { caption in
                guard let pill = caption.superview else { return }
                guard pill.constraints.contains(where: { $0.identifier == "pill-cap-trail" }) == false else { return }
                caption.heightAnchor.constraint(equalToConstant: .adaptHeight(16)).isActive = true
                let trail = caption.trailingAnchor.constraint(
                    lessThanOrEqualTo: pill.trailingAnchor,
                    constant: -.adaptWidth(12)
                )
                trail.identifier = "pill-cap-trail"
                trail.isActive = true
            }
        [foodValueLabel, remainingValueLabel, exerciseValueLabel, burnRemainingValueLabel]
            .compactMap { $0 }
            .forEach { value in
                guard let pill = value.superview else { return }
                guard pill.constraints.contains(where: { $0.identifier == "pill-bottom" }) == false else { return }
                value.heightAnchor.constraint(equalToConstant: .adaptHeight(20)).isActive = true
                let bottom = value.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -.adaptHeight(12))
                bottom.identifier = "pill-bottom"
                bottom.isActive = true
                let trail = value.trailingAnchor.constraint(
                    lessThanOrEqualTo: pill.trailingAnchor,
                    constant: -.adaptWidth(12)
                )
                trail.identifier = "pill-val-trail"
                trail.isActive = true
            }
    }

    private func layoutWaterGlasses() {
        guard let stack = waterGlasses?.first?.superview as? UIStackView else { return }
        stack.distribution = .equalSpacing
        stack.spacing = 0
        (stack as? AdaptiveStackView)?.adaptSpacing = false
        (waterGlasses ?? []).forEach { glass in
            glass.widthAnchor.constraint(equalToConstant: .adaptWidth(36)).isActive = true
            glass.heightAnchor.constraint(equalToConstant: .adaptHeight(44)).isActive = true
        }
    }

    private func installStatDots() {
        let pills: [(UILabel?, UIColor)] = [
            (foodCaptionLabel, AppColor.teal),
            (remainingCaptionLabel, AppColor.fillSecondary),
            (exerciseCaptionLabel, AppColor.teal),
            (burnRemainingCaptionLabel, AppColor.fillSecondary)
        ]
        pills.forEach { caption, color in
            guard let caption, let pill = caption.superview, pill.viewWithTag(8821) == nil else { return }
            let dot = UIView()
            dot.tag = 8821
            dot.backgroundColor = color
            dot.translatesAutoresizingMaskIntoConstraints = false
            pill.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: .adaptWidth(12)),
                dot.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: .adaptWidth(8)),
                dot.heightAnchor.constraint(equalToConstant: .adaptWidth(8))
            ])
            dot.layer.cornerRadius = .adaptWidth(4)
        }
    }

    @objc
    private func profileTapped() {
        onOpenProfile?()
    }

    @objc
    private func markAllEatenTapped() {
        viewModel.markAllEaten()
    }

    @objc
    private func addTapped() {
        presentQuickLog()
    }

    @objc
    private func waterEditTapped() {
        let sheet = GlassVolumeSheetViewController(milliliters: viewModel.screen.value.glassMilliliters) { [weak self] value in
            self?.viewModel.saveGlassVolume(Double(value))
        }
        present(sheet, animated: true)
    }

    @objc
    private func waterMinusTapped() {
        viewModel.removeLastWater()
    }

    @objc
    private func waterPlusTapped() {
        viewModel.logWaterGlass()
    }

    private func presentQuickLog() {
        let sheet = QuickLogSheetViewController { [weak self] action in
            self?.onQuickLog?(action)
        }
        present(sheet, animated: true)
    }
}

private final class HomeNavigationHeaderView: UIView {
    var preferredWidth: CGFloat = 0

    override var intrinsicContentSize: CGSize {
        let width = preferredWidth > 0 ? preferredWidth : UIView.layoutFittingExpandedSize.width
        return CGSize(width: width, height: CGFloat.adaptWidth(44))
    }
}
