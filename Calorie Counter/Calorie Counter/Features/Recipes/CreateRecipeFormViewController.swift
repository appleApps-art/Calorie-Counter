import UIKit

final class CreateRecipeFormViewController: BaseViewController, UITextFieldDelegate, UITextViewDelegate, UICalendarSelectionMultiDateDelegate, UIScrollViewDelegate {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var sourceTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var pantrySourceButton: UIButton!
    @IBOutlet private weak var customSourceButton: UIButton!
    @IBOutlet private weak var sourceTrack: AdaptiveView!
    @IBOutlet private weak var pantryCard: AdaptiveView!
    @IBOutlet private weak var pantryTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var pantryEmptyLabel: AdaptiveLabel!
    @IBOutlet private weak var pantryChipsStack: UIStackView!
    @IBOutlet private weak var customSection: UIStackView!
    @IBOutlet private weak var searchField: AdaptiveView!
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var micButton: UIButton!
    @IBOutlet private weak var suggestionsCard: AdaptiveView!
    @IBOutlet private weak var suggestionsStack: UIStackView!
    @IBOutlet private weak var productsCard: AdaptiveView!
    @IBOutlet private weak var productsTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var customChipsStack: UIStackView!
    @IBOutlet private weak var mealCard: AdaptiveView!
    @IBOutlet private weak var mealTypeLabel: AdaptiveLabel!
    @IBOutlet private weak var mealTypeStack: UIStackView!
    @IBOutlet private weak var cookCard: AdaptiveView!
    @IBOutlet private weak var cookLabel: AdaptiveLabel!
    @IBOutlet private weak var cookStack: UIStackView!
    @IBOutlet private weak var caloriesCard: AdaptiveView!
    @IBOutlet private weak var caloriesLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesValueLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesSlider: UISlider!
    @IBOutlet private weak var cuisineCard: AdaptiveView!
    @IBOutlet private weak var cuisineLabel: AdaptiveLabel!
    @IBOutlet private weak var cuisineStack: UIStackView!
    @IBOutlet private weak var dietCard: AdaptiveView!
    @IBOutlet private weak var dietLabel: AdaptiveLabel!
    @IBOutlet private weak var dietStack: UIStackView!
    @IBOutlet private weak var datesCard: AdaptiveView!
    @IBOutlet private weak var datesTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var datesValueLabel: AdaptiveLabel!
    @IBOutlet private weak var calendarContainer: UIView!
    @IBOutlet private weak var detailsCard: AdaptiveView!
    @IBOutlet private weak var detailsTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var detailsTextView: UITextView!
    @IBOutlet private weak var detailsPlaceholderLabel: AdaptiveLabel!
    @IBOutlet private weak var createButton: UIButton!
    @IBOutlet private weak var loadingCover: UIView!
    @IBOutlet private weak var loadingLabel: AdaptiveLabel!
    @IBOutlet private weak var loadingAnimationView: GIFImageView!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var scrollBottomConstraint: NSLayoutConstraint!

    private let viewModel: CreateRecipeFormViewModel
    private let calendarView = UICalendarView()
    private var calendarSelection: UICalendarSelectionMultiDate?
    private let sourceFillView = UIView()
    private let sourceIndicatorView = UIView()
    private let micChrome = VoiceMicButtonChrome()
    private var lastChipLayoutWidth: CGFloat = 0
    private var canRender = false
    private var isAnimatingContent = false

    init(viewModel: CreateRecipeFormViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "CreateRecipeFormViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? {
        viewModel.kind == .recipe ? .recipesCreateRecipe : .recipesCreateMealPlan
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.dynamic(light: AppColor.canvas, dark: AppColor.backgroundsPrimary)
        navigationItem.largeTitleDisplayMode = .never
        titleLabel.text = viewModel.titleText
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        titleLabel.textAlignment = .center
        OnboardingStyle.styleGlassSymbolButton(
            backButton,
            systemName: "chevron.backward",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        sourceTitleLabel.text = L10n.tr("recipes.create.ingredientSource")
        OnboardingStyle.lockFigmaFont(
            sourceTitleLabel,
            size: 15,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.23
        )
        sourceTitleLabel.textAlignment = .left
        configureSourceButton(pantrySourceButton, title: L10n.tr("recipes.create.myPantry"), action: #selector(pantrySourceTapped))
        configureSourceButton(customSourceButton, title: L10n.tr("recipes.create.customIngredients"), action: #selector(customSourceTapped))
        configureSourceTrack()
        styleFilterCard(pantryCard)
        styleFilterCard(productsCard)
        styleFilterCard(mealCard)
        styleFilterCard(cookCard)
        styleFilterCard(caloriesCard)
        styleFilterCard(cuisineCard)
        styleFilterCard(dietCard)
        styleFilterCard(datesCard)
        styleElevatedCard(detailsCard)
        configureChipScrolls()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (screen: CreateRecipeFormViewController, _) in
            screen.styleFilterCard(screen.pantryCard)
            screen.styleFilterCard(screen.productsCard)
            screen.styleFilterCard(screen.mealCard)
            screen.styleFilterCard(screen.cookCard)
            screen.styleFilterCard(screen.caloriesCard)
            screen.styleFilterCard(screen.cuisineCard)
            screen.styleFilterCard(screen.dietCard)
            screen.styleFilterCard(screen.datesCard)
            screen.styleElevatedCard(screen.detailsCard)
            screen.layoutSourceTrack()
        }
        pantryEmptyLabel.text = L10n.tr("recipes.create.pantryEmpty")
        OnboardingStyle.lockFigmaFont(pantryEmptyLabel, size: 16, weight: .regular, color: AppColor.labelsPrimary, kern: -0.31)
        pantryEmptyLabel.numberOfLines = 0
        OnboardingStyle.lockFigmaFont(
            pantryTitleLabel,
            size: 15,
            weight: .semibold,
            color: AppColor.labelsPrimary,
            kern: -0.23
        )
        OnboardingStyle.lockFigmaFont(
            productsTitleLabel,
            size: 15,
            weight: .semibold,
            color: AppColor.labelsPrimary,
            kern: -0.23
        )
        mealTypeLabel.text = L10n.tr(
            viewModel.kind == .mealPlan ? "recipes.create.mealsToInclude" : "recipes.filters.mealType"
        )
        styleSection(mealTypeLabel)
        styleSection(cookLabel, L10n.tr("recipes.filters.cookTime"))
        styleSection(caloriesLabel, L10n.tr("recipes.filters.calories"))
        styleSection(cuisineLabel, L10n.tr("recipes.filters.cuisine"))
        styleSection(dietLabel, L10n.tr("recipes.filters.diet"))
        datesTitleLabel.text = L10n.tr("recipes.create.selectDates")
        OnboardingStyle.lockFigmaFont(datesTitleLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        detailsTitleLabel.text = L10n.tr(
            viewModel.kind == .mealPlan ? "recipes.create.planDetails" : "recipes.create.recipeDetails"
        )
        OnboardingStyle.lockFigmaFont(detailsTitleLabel, size: 17, weight: .regular, color: AppColor.labelsSecondary, kern: -0.43)
        detailsPlaceholderLabel.text = L10n.tr("recipes.create.detailsPlaceholder")
        OnboardingStyle.lockFigmaFont(
            detailsPlaceholderLabel,
            size: 17,
            weight: .medium,
            color: AppColor.textMuted,
            kern: -0.43
        )
        detailsTextView.delegate = self
        detailsTextView.font = .systemFont(ofSize: .adaptFont(17), weight: .medium)
        detailsTextView.textColor = AppColor.labelsPrimary
        detailsTextView.backgroundColor = .clear
        detailsTextView.textContainerInset = .zero
        detailsTextView.textContainer.lineFragmentPadding = 0
        caloriesSlider.minimumValue = 0
        caloriesSlider.maximumValue = Float(RecipeSearchFilters.calorieCeiling)
        caloriesSlider.minimumTrackTintColor = AppColor.teal
        caloriesSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        caloriesSlider.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside])
        OnboardingStyle.lockFigmaFont(
            caloriesValueLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        searchField.useLiveGlass = true
        searchField.applyButtonGlass = true
        searchField.applyCardShadow = true
        searchTextField.delegate = self
        searchTextField.placeholder = L10n.tr("recipes.filters.addIngredients")
        searchTextField.font = .systemFont(ofSize: .adaptFont(17), weight: .medium)
        searchTextField.textColor = AppColor.labelVibrantPrimary
        searchTextField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.subviews.compactMap { $0 as? UIImageView }.first?.tintColor = AppColor.iconSecondary
        micChrome.attach(micButton)
        applyMic()
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        micButton.controlHaptic = .medium
        OnboardingStyle.stylePrimaryButton(
            createButton,
            title: L10n.tr("recipes.create.title"),
            systemImage: "sparkles"
        )
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        cookCard.isHidden = viewModel.kind != .recipe
        caloriesCard.isHidden = viewModel.kind != .recipe
        datesCard.isHidden = viewModel.kind != .mealPlan
        suggestionsCard.isHidden = true
        suggestionsStack.isHidden = true
        loadingCover.backgroundColor = AppColor.teal
        loadingCover.isHidden = true
        loadingCover.alpha = 1
        loadingLabel.text = L10n.tr(
            viewModel.kind == .recipe ? "recipes.create.loadingRecipe" : "recipes.create.loadingMealPlan"
        )
        loadingLabel.numberOfLines = 0
        loadingLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            loadingLabel,
            size: 22,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.26
        )
        loadingLabel.textAlignment = .center
        loadingAnimationView.contentMode = .scaleAspectFill
        loadingAnimationView.clipsToBounds = true
        loadingCover.bringSubviewToFront(loadingLabel)
        setupKeyboardAvoidance()
        setupKeyboardDismiss()
        if viewModel.kind == .mealPlan {
            setupCalendar()
            renderDates()
        }
        viewModel.onCreateFinished = { [weak self] recipe, plan in
            self?.handleCreateFinished(recipe: recipe, plan: plan)
        }
        viewModel.viewDidLoad()
        canRender = true
        render()
        view.layoutIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if viewModel.kind == .mealPlan {
            calendarView.frame = calendarContainer.bounds
        }
        if !isAnimatingContent {
            layoutSourceTrack()
        }
        micChrome.layoutIfNeeded()
        relayoutProductChipsIfNeeded()
    }

    override func bindViewModel() {
        viewModel.source.bind { [weak self] _ in
            self?.applySource(animated: self?.shouldAnimateUpdates == true)
        }
        viewModel.pantryItems.bind { [weak self] _ in
            self?.applyPantrySection(animated: self?.shouldAnimateUpdates == true)
        }
        viewModel.selectedPantryIds.bind { [weak self] _ in
            self?.applyPantrySection(animated: self?.shouldAnimateUpdates == true)
        }
        viewModel.customIngredients.bind { [weak self] _ in
            self?.applyCustomSection(animated: self?.shouldAnimateUpdates == true)
        }
        viewModel.ingredientQuery.bind { [weak self] text in
            guard let self else { return }
            if self.searchTextField.text != text {
                self.searchTextField.text = text
            }
        }
        viewModel.mealTypeKey.bind { [weak self] _ in self?.renderMealChips() }
        viewModel.selectedMealKeys.bind { [weak self] _ in self?.renderMealChips() }
        viewModel.cookMinutes.bind { [weak self] _ in self?.renderCookChips() }
        viewModel.maxCalories.bind { [weak self] value in
            self?.applyCalories(value)
        }
        viewModel.cuisineKey.bind { [weak self] _ in self?.renderCuisineChips() }
        viewModel.dietKey.bind { [weak self] _ in self?.renderDietChips() }
        viewModel.detailsText.bind { [weak self] text in
            guard let self else { return }
            if self.detailsTextView.text != text {
                self.detailsTextView.text = text
            }
            self.detailsPlaceholderLabel.isHidden = !text.isEmpty
        }
        viewModel.selectedDates.bind { [weak self] _ in self?.renderDates() }
        viewModel.isLoading.bind { [weak self] loading in
            guard let self, !loading else { return }
            self.hideCreateLoading()
        }
        viewModel.isRecording.bind { [weak self] _ in
            self?.applyMic()
        }
        viewModel.canConfirmIngredient.bind { [weak self] _ in
            self?.applyMic()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        viewModel.addCustomIngredient(textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        scrollFocusedFieldVisible()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        scrollFocusedFieldVisible()
    }

    func textViewDidChange(_ textView: UITextView) {
        viewModel.updateDetails(textView.text ?? "")
    }

    func multiDateSelection(
        _ selection: UICalendarSelectionMultiDate,
        didSelectDate dateComponents: DateComponents
    ) {
        publishCalendarDates(selection)
    }

    func multiDateSelection(
        _ selection: UICalendarSelectionMultiDate,
        didDeselectDate dateComponents: DateComponents
    ) {
        publishCalendarDates(selection)
    }

    @objc private func backTapped() { viewModel.backTapped() }
    @objc private func pantrySourceTapped() { viewModel.selectSource(.pantry) }
    @objc private func customSourceTapped() { viewModel.selectSource(.custom) }
    @objc private func searchChanged() { viewModel.updateIngredientQuery(searchTextField.text ?? "") }
    @objc private func micTapped() { viewModel.toggleVoiceTapped() }
    @objc private func createTapped() {
        startCreateLoading()
        viewModel.createTapped()
    }
    @objc private func sliderChanged() {
        let value = Int(caloriesSlider.value.rounded())
        updateCaloriesHeader(value)
        guard !caloriesSlider.isTracking else { return }
        viewModel.updateCalories(value)
    }

    @objc private func sliderEnded() {
        viewModel.updateCalories(Int(caloriesSlider.value.rounded()))
    }

    private func setupCalendar() {
        calendarView.calendar = Calendar.current
        calendarView.locale = .autoupdatingCurrent
        calendarView.tintColor = AppColor.teal
        calendarView.backgroundColor = .clear
        calendarView.wantsDateDecorations = false
        let selection = UICalendarSelectionMultiDate(delegate: self)
        calendarSelection = selection
        calendarView.selectionBehavior = selection
        calendarContainer.addSubview(calendarView)
    }

    private func publishCalendarDates(_ selection: UICalendarSelectionMultiDate) {
        let dates = selection.selectedDates.compactMap { Calendar.current.date(from: $0) }
        viewModel.updateDates(dates)
    }

    private func renderDates() {
        guard viewModel.kind == .mealPlan else { return }
        datesValueLabel.text = viewModel.dateRangeText
        OnboardingStyle.lockFigmaFont(
            datesValueLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        let next = viewModel.selectedDates.value.map {
            Calendar.current.dateComponents([.year, .month, .day], from: $0)
        }
        let current = (calendarSelection?.selectedDates ?? []).map {
            Calendar.current.dateComponents([.year, .month, .day], from: Calendar.current.date(from: $0) ?? Date.distantPast)
        }
        if Set(current.map(Self.dayKey)) != Set(next.map(Self.dayKey)) {
            calendarSelection?.setSelectedDates(next, animated: false)
        }
    }

    private static func dayKey(_ components: DateComponents) -> String {
        "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private var shouldAnimateUpdates: Bool {
        canRender && view.window != nil
    }

    private func render() {
        guard canRender else { return }
        applySource(animated: false)
        applyPantrySection(animated: false)
        applyCustomSection(animated: false)
        renderMealChips()
        renderCookChips()
        applyCalories(viewModel.maxCalories.value)
        renderCuisineChips()
        renderDietChips()
    }

    private func renderMealChips() {
        guard canRender else { return }
        fill(mealTypeStack, keys: viewModel.mealTypeOptions) { key in
            if self.viewModel.kind == .mealPlan {
                return self.viewModel.selectedMealKeys.value.contains(key)
            }
            return self.viewModel.mealTypeKey.value == key
        } action: { [weak self] key in
            self?.viewModel.selectMealType(key)
        }
    }

    private func renderCookChips() {
        guard canRender else { return }
        cookStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        viewModel.cookOptions.forEach { key, minutes in
            cookStack.addArrangedSubview(
                chip(title: L10n.tr(key), selected: viewModel.cookMinutes.value == minutes) { [weak self] in
                    self?.viewModel.selectCookTime(minutes)
                }
            )
        }
    }

    private func renderCuisineChips() {
        guard canRender else { return }
        fillWrapped(cuisineStack, keys: viewModel.cuisineOptions) { key in
            self.viewModel.cuisineKey.value == key
        } action: { [weak self] key in
            self?.viewModel.selectCuisine(key)
        }
    }

    private func renderDietChips() {
        guard canRender else { return }
        fillWrapped(dietStack, keys: viewModel.dietOptions) { key in
            self.viewModel.dietKey.value == key
        } action: { [weak self] key in
            self?.viewModel.selectDiet(key)
        }
    }

    private func applySource(animated: Bool) {
        guard canRender else { return }
        let pantrySelected = viewModel.source.value == .pantry
        styleSource(pantrySourceButton, selected: pantrySelected)
        styleSource(customSourceButton, selected: !pantrySelected)
        if pantrySelected {
            if visibleChipTitles(in: pantryChipsStack).isEmpty, !viewModel.selectedPantryNames.isEmpty {
                UIView.performWithoutAnimation {
                    self.syncPantryChips()
                }
            }
        } else if visibleChipTitles(in: customChipsStack).isEmpty, !viewModel.customIngredients.value.isEmpty {
            UIView.performWithoutAnimation {
                self.syncCustomChips()
            }
        }
        let changes = {
            self.pantryCard.isHidden = !pantrySelected
            self.customSection.isHidden = pantrySelected
            self.layoutSourceTrack()
        }
        if animated {
            animateFormLayout(changes)
        } else {
            UIView.performWithoutAnimation(changes)
        }
    }

    private func applyPantrySection(animated: Bool) {
        guard canRender else { return }
        let titles = viewModel.selectedPantryNames
        applyChipTitles(
            pantryChipsStack,
            titles: titles,
            animated: animated,
            alongside: {
                self.pantryTitleLabel.text = L10n.format("recipes.create.yourProducts", titles.count)
                self.pantryEmptyLabel.isHidden = !self.viewModel.pantryItems.value.isEmpty
                self.pantryChipsStack.isHidden = self.viewModel.pantryItems.value.isEmpty
            }
        ) { [weak self] name in
            if let item = self?.viewModel.pantryItems.value.first(where: { $0.name == name }) {
                self?.viewModel.removePantryItem(item.id)
            }
        }
    }

    private func applyCustomSection(animated: Bool) {
        guard canRender else { return }
        let titles = viewModel.customIngredients.value
        applyChipTitles(
            customChipsStack,
            titles: titles,
            animated: animated,
            alongside: {
                self.productsTitleLabel.text = L10n.format("recipes.create.products", titles.count)
            }
        ) { [weak self] name in
            self?.viewModel.removeCustomIngredient(name)
        }
    }

    private func applyChipTitles(
        _ stack: UIStackView,
        titles: [String],
        animated: Bool,
        alongside: @escaping () -> Void,
        remove: @escaping (String) -> Void
    ) {
        let visible = visibleChipTitles(in: stack)
        if visible.isEmpty {
            let fill = {
                alongside()
                self.syncProductChips(stack, titles: titles, remove: remove)
            }
            if animated {
                animateFormLayout(fill)
            } else {
                UIView.performWithoutAnimation(fill)
            }
            return
        }
        let visibleSet = Set(visible)
        let removed = visibleSet.subtracting(titles)
        let added = titles.filter { !visibleSet.contains($0) }
        if added.isEmpty {
            collapseChips(in: stack, titles: removed, animated: animated, alongside: alongside)
            return
        }
        let fill = {
            alongside()
            self.syncProductChips(stack, titles: titles, remove: remove)
        }
        if animated {
            animateFormLayout(fill)
        } else {
            UIView.performWithoutAnimation(fill)
        }
    }

    private func visibleChipTitles(in stack: UIStackView) -> [String] {
        var titles: [String] = []
        for case let row as UIStackView in stack.arrangedSubviews {
            for case let button as UIButton in row.arrangedSubviews where !button.isHidden {
                titles.append(chipTitle(button))
            }
        }
        return titles
    }

    private func collapseChips(
        in stack: UIStackView,
        titles: Set<String>,
        animated: Bool,
        alongside: @escaping () -> Void
    ) {
        guard !titles.isEmpty else {
            alongside()
            return
        }
        var buttons: [UIButton] = []
        for case let row as UIStackView in stack.arrangedSubviews {
            for case let button as UIButton in row.arrangedSubviews where !button.isHidden {
                if titles.contains(chipTitle(button)) {
                    buttons.append(button)
                }
            }
        }
        guard !buttons.isEmpty else {
            alongside()
            return
        }
        let widths = buttons.map { button -> NSLayoutConstraint in
            button.clipsToBounds = true
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            clearProductChipWidthLocks(button)
            let width = button.bounds.width > 1 ? button.bounds.width : productChipWidth(button)
            let constraint = button.widthAnchor.constraint(equalToConstant: width)
            constraint.priority = .required
            constraint.isActive = true
            return constraint
        }
        var emptyingRows: [UIStackView] = []
        for case let row as UIStackView in stack.arrangedSubviews {
            let hasRemaining = row.arrangedSubviews.contains { view in
                guard let button = view as? UIButton else { return false }
                if buttons.contains(button) { return false }
                return !button.isHidden
            }
            if !hasRemaining {
                emptyingRows.append(row)
            }
        }
        let rowHeights = emptyingRows.map { row -> NSLayoutConstraint in
            row.clipsToBounds = true
            let constraint = row.heightAnchor.constraint(equalToConstant: max(row.bounds.height, 1))
            constraint.priority = .required
            constraint.isActive = true
            return constraint
        }
        var siblingLocks: [NSLayoutConstraint] = []
        for case let row as UIStackView in stack.arrangedSubviews {
            for case let button as UIButton in row.arrangedSubviews where !buttons.contains(button) && !button.isHidden {
                button.setContentHuggingPriority(.required, for: .horizontal)
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
                clearProductChipWidthLocks(button)
                let width = button.bounds.width > 1 ? button.bounds.width : productChipWidth(button)
                let constraint = button.widthAnchor.constraint(equalToConstant: width)
                constraint.priority = .required
                constraint.isActive = true
                siblingLocks.append(constraint)
            }
        }
        let apply = {
            alongside()
            buttons.forEach { $0.alpha = 0 }
            widths.forEach { $0.constant = 0 }
            rowHeights.forEach { $0.constant = 0 }
            stack.layoutIfNeeded()
            self.view.layoutIfNeeded()
        }
        let cleanup = {
            buttons.forEach { $0.removeFromSuperview() }
            emptyingRows.forEach { row in
                stack.removeArrangedSubview(row)
                row.removeFromSuperview()
            }
            siblingLocks.forEach { $0.isActive = false }
        }
        if animated {
            isAnimatingContent = true
            UIView.animate(
                withDuration: 0.22,
                delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState],
                animations: apply,
                completion: { _ in
                    UIView.performWithoutAnimation(cleanup)
                    self.isAnimatingContent = false
                }
            )
        } else {
            UIView.performWithoutAnimation {
                apply()
                cleanup()
            }
        }
    }

    private func animateFormLayout(_ changes: @escaping () -> Void) {
        view.layoutIfNeeded()
        isAnimatingContent = true
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
            animations: {
                changes()
                self.view.layoutIfNeeded()
            },
            completion: { _ in
                self.isAnimatingContent = false
                self.layoutSourceTrack()
            }
        )
    }

    private func startCreateLoading() {
        loadingAnimationView.playsOnce = false
        loadingAnimationView.onFinished = nil
        loadingAnimationView.onReachedEnd = nil
        loadingAnimationView.loadGIF(named: "Loading2")
        loadingCover.isHidden = false
        loadingCover.isUserInteractionEnabled = true
        view.bringSubviewToFront(loadingCover)
        loadingCover.bringSubviewToFront(loadingLabel)
        loadingAnimationView.startAnimatingGIF()
    }

    private func hideCreateLoading() {
        loadingAnimationView.onReachedEnd = nil
        loadingAnimationView.stopAnimatingGIF()
        loadingAnimationView.onFinished = nil
        loadingCover.isHidden = true
        loadingCover.isUserInteractionEnabled = false
    }

    private func handleCreateFinished(recipe: Recipe?, plan: MealPlan?) {
        hideCreateLoading()
        viewModel.endLoading()
        if let recipe {
            viewModel.onCreatedRecipe?(recipe)
            return
        }
        if let plan {
            viewModel.onCreatedMealPlan?(plan)
        }
    }

    private func applyCalories(_ value: Int) {
        updateCaloriesHeader(value)
        guard !caloriesSlider.isTracking else { return }
        let next = Float(value)
        if abs(caloriesSlider.value - next) > 0.5 {
            caloriesSlider.value = next
        }
    }

    private func updateCaloriesHeader(_ value: Int) {
        caloriesValueLabel.text = L10n.format("recipes.filters.caloriesValue", 0, value)
    }

    private func configureSourceButton(_ button: UIButton, title: String, action: Selector) {
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

    private func configureSourceTrack() {
        sourceTrack.useLiveGlass = false
        sourceTrack.applyCardShadow = false
        sourceTrack.adaptCornerRadius = false
        sourceTrack.backgroundColor = .clear
        sourceTrack.clipsToBounds = false
        sourceTrack.layer.masksToBounds = false
        sourceFillView.translatesAutoresizingMaskIntoConstraints = true
        sourceFillView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sourceFillView.backgroundColor = AppColor.backgroundsPrimaryElevated
        sourceFillView.clipsToBounds = true
        sourceFillView.layer.masksToBounds = true
        sourceFillView.isUserInteractionEnabled = false
        sourceFillView.layer.cornerCurve = .continuous
        sourceIndicatorView.isHidden = true
        sourceIndicatorView.clipsToBounds = true
        sourceIndicatorView.layer.masksToBounds = true
        sourceIndicatorView.backgroundColor = AppColor.teal
        sourceIndicatorView.isUserInteractionEnabled = false
        sourceIndicatorView.layer.cornerCurve = .continuous
        if sourceFillView.superview !== sourceTrack {
            sourceTrack.insertSubview(sourceFillView, at: 0)
        }
        if sourceIndicatorView.superview !== sourceFillView {
            sourceFillView.addSubview(sourceIndicatorView)
        }
        if let stack = pantrySourceButton.superview {
            stack.isUserInteractionEnabled = true
            (stack as? UIStackView)?.alignment = .fill
            (stack as? UIStackView)?.distribution = .fillEqually
            (stack as? UIStackView)?.spacing = .adaptWidth(4)
            sourceTrack.bringSubviewToFront(stack)
        }
    }

    private func layoutSourceTrack() {
        guard sourceFillView.superview === sourceTrack, sourceTrack.bounds.width > 0, sourceTrack.bounds.height > 0 else { return }
        let radius = sourceTrack.bounds.height / 2
        sourceTrack.layer.cornerRadius = radius
        sourceTrack.layer.cornerCurve = .continuous
        sourceTrack.layer.masksToBounds = false
        OnboardingStyle.applyCardFallbackShadow(sourceTrack.layer, traits: traitCollection)
        sourceTrack.layer.shadowPath = UIBezierPath(roundedRect: sourceTrack.bounds, cornerRadius: radius).cgPath
        sourceFillView.frame = sourceTrack.bounds
        sourceFillView.clipsToBounds = true
        sourceFillView.layer.masksToBounds = true
        sourceFillView.layer.cornerRadius = radius
        sourceFillView.backgroundColor = AppColor.backgroundsPrimaryElevated
        if sourceIndicatorView.superview !== sourceFillView {
            sourceFillView.addSubview(sourceIndicatorView)
        }
        guard let selected = viewModel.source.value == .pantry ? pantrySourceButton : customSourceButton else { return }
        let raw = selected.convert(selected.bounds, to: sourceFillView)
        let frame = raw.intersection(sourceFillView.bounds)
        guard frame.width > 4, frame.height > 4, frame.height <= sourceFillView.bounds.height + 1 else {
            sourceIndicatorView.isHidden = true
            sourceIndicatorView.frame = .zero
            return
        }
        sourceIndicatorView.isHidden = false
        sourceIndicatorView.frame = frame
        sourceIndicatorView.layer.cornerRadius = frame.height / 2
        sourceIndicatorView.backgroundColor = AppColor.teal
    }

    private func setupKeyboardDismiss() {
        [view, scrollView].forEach { host in
            let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            dismissTap.cancelsTouchesInView = false
            dismissTap.delegate = self
            host.addGestureRecognizer(dismissTap)
        }
    }

    private func setupKeyboardAvoidance() {
        scrollView.keyboardDismissMode = .onDrag
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        view.keyboardLayoutGuide.usesBottomSafeArea = true
        scrollBottomConstraint.isActive = false
        scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor).isActive = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }

    @objc private func keyboardFrameChanged() {
        scrollFocusedFieldVisible()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView === self.scrollView else { return }
        view.endEditing(true)
    }

    private func scrollFocusedFieldVisible() {
        let target: UIView
        if searchTextField.isFirstResponder {
            target = searchField
        } else if detailsTextView.isFirstResponder {
            target = detailsCard
        } else {
            return
        }
        view.layoutIfNeeded()
        let rect = target.convert(target.bounds, to: scrollView)
        let padding = CGFloat.adaptHeight(16)
        let padded = CGRect(
            x: rect.minX,
            y: rect.minY - padding,
            width: rect.width,
            height: rect.height + padding * 2
        )
        scrollView.scrollRectToVisible(padded, animated: true)
    }

    private func styleFilterCard(_ view: AdaptiveView) {
        view.useLiveGlass = false
        view.applyCardShadow = true
        view.cardFillColor = AppColor.backgroundsPrimaryElevated
    }

    private func styleElevatedCard(_ view: AdaptiveView) {
        view.useLiveGlass = false
        view.applyCardShadow = true
        view.cardFillColor = AppColor.backgroundsPrimaryElevated
    }

    private func configureChipScrolls() {
        [mealTypeStack, cookStack].forEach { stack in
            (stack as? AdaptiveStackView)?.adaptSpacing = false
            stack.axis = .horizontal
            stack.alignment = .fill
            stack.distribution = .fill
            stack.spacing = .adaptWidth(8)
            if let scroll = stack.superview as? UIScrollView {
                OnboardingStyle.configureChatChipsCarousel(scroll)
            }
        }
    }

    private func styleSource(_ button: UIButton, selected: Bool) {
        button.configuration = nil
        button.backgroundColor = .clear
        let title = button === pantrySourceButton
            ? L10n.tr("recipes.create.myPantry")
            : L10n.tr("recipes.create.customIngredients")
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

    private func styleSection(_ label: AdaptiveLabel, _ text: String? = nil) {
        if let text {
            label.text = text
        }
        OnboardingStyle.lockFigmaFont(label, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
    }

    private func applyMic() {
        micChrome.apply(
            isRecording: viewModel.isRecording.value,
            canConfirm: viewModel.canConfirmIngredient.value
        )
    }

    private func fill(
        _ stack: UIStackView,
        keys: [String],
        selected: (String) -> Bool,
        action: @escaping (String) -> Void
    ) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.axis = .horizontal
        stack.distribution = .fill
        keys.forEach { key in
            stack.addArrangedSubview(
                chip(title: L10n.tr(key), selected: selected(key)) { action(key) }
            )
        }
    }

    private func fillWrapped(
        _ stack: UIStackView,
        keys: [String],
        selected: (String) -> Bool,
        action: @escaping (String) -> Void
    ) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.axis = .vertical
        stack.distribution = .fill
        stack.spacing = .adaptHeight(12)
        stride(from: 0, to: keys.count, by: 3).forEach { index in
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .fill
            row.distribution = .fill
            row.spacing = .adaptWidth(8)
            keys[index..<min(index + 3, keys.count)].forEach { key in
                let button = chip(title: L10n.tr(key), selected: selected(key)) { action(key) }
                if key == "recipes.filters.any" {
                    button.setContentHuggingPriority(.required, for: .horizontal)
                    button.setContentCompressionResistancePriority(.required, for: .horizontal)
                } else {
                    button.setContentHuggingPriority(.defaultLow, for: .horizontal)
                    button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                }
                row.addArrangedSubview(button)
            }
            stack.addArrangedSubview(row)
        }
    }

    private func relayoutProductChipsIfNeeded() {
        guard !isAnimatingContent else { return }
        let stack: UIStackView
        let titles: [String]
        if !pantryCard.isHidden {
            stack = pantryChipsStack
            titles = viewModel.selectedPantryNames
        } else {
            stack = customChipsStack
            titles = viewModel.customIngredients.value
        }
        let width = floor(stack.bounds.width)
        guard width > 1 else { return }
        let titlesChanged = visibleChipTitles(in: stack) != titles
        if !titlesChanged, abs(width - lastChipLayoutWidth) < 1 { return }
        lastChipLayoutWidth = width
        if pantryCard.isHidden {
            syncCustomChips()
        } else {
            syncPantryChips()
        }
    }

    private func syncPantryChips() {
        syncProductChips(pantryChipsStack, titles: viewModel.selectedPantryNames) { [weak self] name in
            if let item = self?.viewModel.pantryItems.value.first(where: { $0.name == name }) {
                self?.viewModel.removePantryItem(item.id)
            }
        }
    }

    private func syncCustomChips() {
        syncProductChips(customChipsStack, titles: viewModel.customIngredients.value) { [weak self] name in
            self?.viewModel.removeCustomIngredient(name)
        }
    }

    private func rememberChipLayoutWidth(_ width: CGFloat) {
        guard width.isFinite, width > 1, width < 10_000 else { return }
        lastChipLayoutWidth = width
    }

    private func syncProductChips(
        _ stack: UIStackView,
        titles: [String],
        remove: @escaping (String) -> Void
    ) {
        var kept: [String: UIButton] = [:]
        for case let row as UIStackView in stack.arrangedSubviews {
            for view in row.arrangedSubviews {
                row.removeArrangedSubview(view)
                view.removeFromSuperview()
                guard let button = view as? UIButton else { continue }
                let title = chipTitle(button)
                if kept[title] == nil, titles.contains(title) {
                    button.isHidden = false
                    kept[title] = button
                }
            }
        }
        stack.arrangedSubviews.forEach { row in
            stack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = .adaptHeight(8)
        guard !titles.isEmpty else { return }
        let buttons = titles.map { title in
            let button = kept[title] ?? productChip(title: title) { remove(title) }
            prepareProductChip(button)
            return button
        }
        let spacing = CGFloat.adaptWidth(8)
        let maxWidth = productChipsAvailableWidth(in: stack)
        rememberChipLayoutWidth(maxWidth)
        let naturals = buttons.map(ProductChipFlow.fittedWidth)
        let rows = ProductChipFlow.wrap(widths: naturals, maxWidth: maxWidth, spacing: spacing)
        rows.forEach { indexes in
            let row = makeChipRow()
            indexes.forEach { index in
                let button = buttons[index]
                lockProductChipWidth(button, min(naturals[index], maxWidth))
                row.addArrangedSubview(button)
            }
            finishChipRow(row)
            stack.addArrangedSubview(row)
        }
    }

    private func finishChipRow(_ row: UIStackView) {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
    }

    private func chipTitle(_ button: UIButton) -> String {
        if let identifier = button.accessibilityIdentifier, !identifier.isEmpty {
            return identifier
        }
        return button.configuration?.title ?? button.currentTitle ?? ""
    }

    private func productChipsAvailableWidth(in stack: UIStackView) -> CGFloat {
        let stackWidth = floor(stack.bounds.width)
        if stackWidth > 1 { return stackWidth }
        let parentWidth = floor(stack.superview?.bounds.width ?? 0)
        if parentWidth > 1 { return parentWidth }
        return max(1, floor(view.bounds.width - .adaptWidth(64)))
    }

    private func prepareProductChip(_ button: UIButton) {
        button.clipsToBounds = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        clearProductChipWidthLocks(button)
    }

    private func clearProductChipWidthLocks(_ button: UIButton) {
        button.constraints
            .filter { $0.firstAttribute == .width && $0.secondItem == nil }
            .forEach { constraint in
                constraint.isActive = false
                button.removeConstraint(constraint)
            }
    }

    private func lockProductChipWidth(_ button: UIButton, _ width: CGFloat) {
        clearProductChipWidthLocks(button)
        let constraint = button.widthAnchor.constraint(equalToConstant: max(1, ceil(width)))
        constraint.priority = .required
        constraint.isActive = true
    }

    private func productChipWidth(_ button: UIButton) -> CGFloat {
        ProductChipFlow.fittedWidth(button)
    }

    private func makeChipRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = .adaptWidth(8)
        row.alignment = .center
        row.distribution = .fill
        return row
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.title = title
        config.titleLineBreakMode = .byClipping
        config.contentInsets = NSDirectionalEdgeInsets(
            top: .adaptHeight(7),
            leading: .adaptWidth(12),
            bottom: .adaptHeight(7),
            trailing: .adaptWidth(12)
        )
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = .systemFont(ofSize: .adaptFont(15), weight: .regular)
            attributes.kern = -0.23
            return attributes
        }
        config.baseForegroundColor = selected ? .black : AppColor.labelsPrimary
        config.baseBackgroundColor = selected ? AppColor.teal : AppColor.fillQuaternary
        button.configuration = config
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.controlHaptic = .selection
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func productChip(title: String, action: @escaping () -> Void) -> UIButton {
        ProductChipFlow.makeChip(title: title, action: action)
    }
}

extension CreateRecipeFormViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var hit: UIView? = touch.view
        while let current = hit {
            if current is UITextField || current is UITextView {
                return false
            }
            hit = current.superview
        }
        return true
    }
}
