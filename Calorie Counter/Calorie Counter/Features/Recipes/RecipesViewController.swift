import UIKit

final class RecipesViewController: BaseViewController, UITextFieldDelegate, UIScrollViewDelegate {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var pantryButton: UIButton!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var searchField: AdaptiveView!
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var micButton: UIButton!
    @IBOutlet private weak var filterButton: UIButton!
    @IBOutlet private weak var suggestionsView: AdaptiveView!
    @IBOutlet private weak var suggestionsStack: UIStackView!
    @IBOutlet private weak var segmentControl: RecipeHubSegmentControl!
    @IBOutlet private weak var hubSlotView: UIStackView!
    @IBOutlet private weak var chipsScroll: UIScrollView!
    @IBOutlet private weak var chipsStack: UIStackView!
    @IBOutlet private weak var chipsHeightConstraint: AdaptiveConstraint!
    @IBOutlet private weak var browseStack: UIStackView!
    @IBOutlet private weak var gridStack: UIStackView!
    @IBOutlet private weak var emptySection: EmptyScreenView!
    @IBOutlet private weak var scrollView: UIScrollView!

    private let viewModel: RecipesViewModel
    private var isShowingBrowseSkeletons = false
    private var showsOfflineEmpty = false
    private var reportedOfflineContext: String?
    private var isShowingSearchSkeletons = false
    private var renderedGridContent: RecipeGridContent?
    private var isShowingPaginationSkeletons = false
    private var pulseWaves: [UIView] = []
    private var browseRenderID = 0
    private var gridRenderID = 0
    private let headerBackdropView = UIView()
    private let headerFadeGradient = CAGradientLayer()
    private let headerBlurView = TabBarBackgroundBlurView()
    private let contentGapBelowHub: CGFloat = 12

    init(viewModel: RecipesViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "RecipesViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .recipes }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self, selector: #selector(networkChanged), name: NetworkMonitor.didChange, object: nil
        )
        view.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? .black : UIColor(red: 231/255, green: 1, blue: 252/255, alpha: 1) }
        view.subviews.compactMap { $0 as? HomeBackgroundView }.forEach { $0.isHidden = true }
        configureChrome()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.reloadVisible()
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
            OnboardingStyle.lockFigmaFont(
                self?.titleLabel,
                size: 28,
                weight: .bold,
                color: AppColor.labelVibrantPrimary,
                kern: 0.38
            )
        }
        viewModel.queryText.bind { [weak self] value in
            guard self?.searchTextField.text != value else { return }
            self?.searchTextField.text = value
        }
        viewModel.selectedTab.bind { [weak self] tab in
            self?.segmentControl.selectedTab = tab
            self?.applyPhase()
        }
        viewModel.browseSections.bind { [weak self] sections in
            self?.renderBrowse(sections)
            self?.applyPhase()
        }
        viewModel.visibleSavedRecipes.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.visibleMealPlans.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.resultRecipes.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.suggestionTitles.bind { [weak self] titles in
            self?.renderSuggestions(titles)
        }
        viewModel.filterChips.bind { [weak self] chips in
            self?.renderChips(chips)
        }
        viewModel.isLoading.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.isRecording.bind { [weak self] _ in
            self?.styleTrailingButton()
        }
        viewModel.canConfirmQuery.bind { [weak self] _ in
            self?.styleTrailingButton()
        }
        viewModel.showsFilterResults.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.showsEmptyResults.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.isLoadingMoreResults.bind { [weak self] _ in
            self?.applyPhase()
        }
    }

    private func configureChrome() {
        OnboardingStyle.styleGlassSymbolButton(
            pantryButton,
            systemName: "refrigerator",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        OnboardingStyle.styleGlassSymbolButton(
            addButton,
            systemName: "plus",
            foregroundColor: AppColor.tabSelected
        )
        pantryButton.addTarget(self, action: #selector(pantryTapped), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        searchField.useLiveGlass = true
        searchField.applyButtonGlass = true
        searchField.applyCardShadow = true
        searchTextField.delegate = self
        searchTextField.borderStyle = .none
        searchTextField.backgroundColor = .clear
        searchTextField.font = .systemFont(ofSize: 17, weight: .medium)
        searchTextField.textColor = AppColor.labelVibrantPrimary
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: L10n.tr("recipes.searchPlaceholder"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: AppColor.footerLabel
            ]
        )
        searchTextField.returnKeyType = .search
        searchTextField.addTarget(self, action: #selector(queryChanged), for: .editingChanged)
        searchField.subviews.compactMap { $0 as? UIImageView }.first?.tintColor = AppColor.iconSecondary
        styleTrailingButton()
        OnboardingStyle.styleGlassSymbolButton(
            filterButton,
            systemName: "line.3.horizontal.decrease",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        micButton.addTarget(self, action: #selector(trailingActionTapped), for: .touchUpInside)
        filterButton.addTarget(self, action: #selector(filtersTapped), for: .touchUpInside)
        segmentControl.onSelect = { [weak self] tab in
            self?.viewModel.selectTab(tab)
        }
        suggestionsView.useLiveGlass = false
        suggestionsView.applyCardShadow = true
        suggestionsView.isHidden = true
        emptySection.onAction = { [weak self] in
            self?.emptyActionTapped()
        }
        emptySection.clipsToBounds = false
        (chipsStack as? AdaptiveStackView)?.adaptSpacing = false
        chipsStack.axis = .horizontal
        chipsStack.alignment = .fill
        chipsStack.distribution = .fill
        chipsStack.spacing = .adaptWidth(4)
        OnboardingStyle.pinChipCarouselFullBleed(chipsScroll, to: view)
        chipsScroll.delegate = self
        installHeaderChrome()
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        scrollView.clipsToBounds = true
        scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 26.0, *) {
            scrollView.topEdgeEffect.isHidden = true
            scrollView.bottomEdgeEffect.isHidden = false
            scrollView.bottomEdgeEffect.style = .soft
            scrollView.leftEdgeEffect.isHidden = true
            scrollView.rightEdgeEffect.isHidden = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        OnboardingStyle.applyChatChipsEdgeFade(to: chipsScroll)
        layoutHeaderChrome()
        updateEmptyActionClearance()
        if viewModel.canConfirmQuery.value, micButton.bounds.height > 1 {
            micButton.layer.cornerRadius = micButton.bounds.height / 2
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === self.scrollView {
            loadMoreResultsIfNearBottom()
            return
        }
        guard scrollView === chipsScroll else { return }
        OnboardingStyle.applyChatChipsEdgeFade(to: chipsScroll)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        viewModel.searchTapped()
        return true
    }

    @objc private func queryChanged() {
        viewModel.updateQuery(searchTextField.text ?? "")
    }

    @objc private func pantryTapped() { viewModel.pantryTapped() }
    @objc private func addTapped() { viewModel.addTapped() }
    @objc private func filtersTapped() { viewModel.filtersTapped() }
    @objc private func trailingActionTapped() { viewModel.trailingActionTapped() }

    private func styleTrailingButton() {
        stopListeningAnimation()
        searchField.clipsToBounds = false
        searchField.layer.masksToBounds = false
        if viewModel.canConfirmQuery.value {
            styleConfirmButton()
            return
        }
        OnboardingStyle.stylePlainSymbolButton(
            micButton,
            systemName: "microphone",
            foregroundColor: viewModel.isRecording.value ? AppColor.teal : AppColor.iconSecondary
        )
        micButton.clipsToBounds = false
        micButton.layer.masksToBounds = false
        if viewModel.isRecording.value {
            startListeningAnimation()
        }
    }

    private func styleConfirmButton() {
        let check = UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )?.withTintColor(AppColor.onAccent, renderingMode: .alwaysOriginal)
        micButton.configuration = nil
        micButton.setTitle(nil, for: .normal)
        micButton.setImage(check, for: .normal)
        micButton.tintColor = AppColor.onAccent
        micButton.backgroundColor = AppColor.teal
        micButton.clipsToBounds = true
        micButton.layer.masksToBounds = true
        micButton.imageView?.contentMode = .center
        micButton.imageView?.clipsToBounds = false
        micButton.imageView?.tintColor = AppColor.onAccent
        micButton.layer.cornerCurve = .continuous
        micButton.layer.shadowOpacity = 0
        micButton.layer.cornerRadius = micButton.bounds.height / 2
        if micButton.bounds.height < 1 {
            micButton.layer.cornerRadius = .adaptWidth(14)
        }
        micButton.controlHaptic = .medium
        OnboardingStyle.applyPressFeedback(micButton)
    }

    private func startListeningAnimation() {
        installPulseWavesIfNeeded()
        pulseWaves.forEach { $0.isHidden = false }
        micButton.layoutIfNeeded()
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = 1.14
        pulse.duration = 0.72
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        if let imageView = micButton.imageView {
            imageView.layer.add(pulse, forKey: "micPulse")
        } else {
            micButton.layer.add(pulse, forKey: "micPulse")
        }
        pulseWaves.enumerated().forEach { index, wave in
            wave.layer.cornerRadius = wave.bounds.height / 2
            wave.layer.cornerCurve = .continuous
            let group = CAAnimationGroup()
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.72
            scale.toValue = 1.55
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.4
            fade.toValue = 0
            group.animations = [scale, fade]
            group.duration = 1.15
            group.repeatCount = .infinity
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.38
            wave.layer.add(group, forKey: "wave")
        }
    }

    private func stopListeningAnimation() {
        micButton.imageView?.layer.removeAnimation(forKey: "micPulse")
        micButton.layer.removeAnimation(forKey: "micPulse")
        micButton.imageView?.transform = .identity
        micButton.transform = .identity
        pulseWaves.forEach { wave in
            wave.layer.removeAllAnimations()
            wave.isHidden = true
        }
    }

    private func installPulseWavesIfNeeded() {
        guard pulseWaves.isEmpty else { return }
        (0..<2).forEach { _ in
            let wave = UIView()
            wave.isUserInteractionEnabled = false
            wave.backgroundColor = .clear
            wave.layer.borderWidth = 1.5
            wave.layer.borderColor = AppColor.teal.withAlphaComponent(0.5).cgColor
            wave.translatesAutoresizingMaskIntoConstraints = false
            micButton.insertSubview(wave, at: 0)
            NSLayoutConstraint.activate([
                wave.centerXAnchor.constraint(equalTo: micButton.centerXAnchor),
                wave.centerYAnchor.constraint(equalTo: micButton.centerYAnchor),
                wave.widthAnchor.constraint(equalTo: micButton.widthAnchor),
                wave.heightAnchor.constraint(equalTo: micButton.heightAnchor)
            ])
            pulseWaves.append(wave)
        }
    }

    private func emptyActionTapped() {
        if showsOfflineEmpty {
            Analytics.tracker.track(.retryTapped(context: "recipes"))
            viewModel.reloadVisible()
            return
        }
        if viewModel.selectedTab.value == .mealPlans, !viewModel.showsFilterResults.value, !viewModel.isSearchingLocally {
            viewModel.createMealPlanTapped()
        } else {
            viewModel.createRecipeTapped()
        }
    }

    private func configureSavedStyleEmpty(title: String, subtitle: String, actionTitle: String) {
        emptySection.setContentTopInset(100)
        emptySection.setMessageWidth(372)
        emptySection.configure(
            title: title,
            subtitle: subtitle,
            actionTitle: actionTitle,
            systemImage: "plus",
            illustrationName: "emptyImage2",
            titleNumberOfLines: 1
        )
        updateEmptyActionClearance()
    }

    /// Recipes to browse and search come from the backend; saved recipes and meal plans never need it.
    private func configureOfflineEmpty() {
        showsOfflineEmpty = true
        let context = viewModel.showsFilterResults.value ? "recipes_search" : "recipes_browse"
        if reportedOfflineContext != context {
            reportedOfflineContext = context
            Analytics.tracker.track(.offlineStateShown(context: context))
        }
        emptySection.setContentTopInset(100)
        emptySection.setMessageWidth(300)
        emptySection.configureOffline(illustrationName: "emptyImage1")
        emptySection.layoutIfNeeded()
        updateEmptyActionClearance()
    }

    @objc private func networkChanged() {
        if NetworkMonitor.shared.isOnline, showsOfflineEmpty {
            viewModel.reloadVisible()
        }
        applyPhase()
    }

    private func configureFilterEmpty() {
        emptySection.setContentTopInset(100)
        emptySection.setMessageWidth(230)
        emptySection.configure(
            title: L10n.tr("recipes.emptyFoundTitle"),
            subtitle: L10n.tr("recipes.emptyFoundSubtitle"),
            actionTitle: L10n.tr("recipes.createRecipe"),
            systemImage: "plus",
            illustrationName: "emptyImage1"
        )
        emptySection.layoutIfNeeded()
        updateEmptyActionClearance()
    }

    private func installHeaderChrome() {
        headerBackdropView.backgroundColor = .clear
        headerBackdropView.isUserInteractionEnabled = false
        if headerBackdropView.superview !== view {
            view.addSubview(headerBackdropView)
        }
        if headerFadeGradient.superlayer !== headerBackdropView.layer {
            headerBackdropView.layer.addSublayer(headerFadeGradient)
        }
        headerFadeGradient.startPoint = CGPoint(x: 0.5, y: 0)
        headerFadeGradient.endPoint = CGPoint(x: 0.5, y: 1)
        refreshHeaderFadeColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: RecipesViewController, _) in
            controller.refreshHeaderFadeColors()
        }
        headerBlurView.flipsVertically = true
        headerBlurView.isUserInteractionEnabled = false
        if headerBlurView.superview !== view {
            view.addSubview(headerBlurView)
        }
        raiseHeaderChrome()
    }

    private func raiseHeaderChrome() {
        view.bringSubviewToFront(headerBackdropView)
        view.bringSubviewToFront(headerBlurView)
        if let hubSlotView {
            view.bringSubviewToFront(hubSlotView)
        }
        view.bringSubviewToFront(suggestionsView)
        view.bringSubviewToFront(searchField)
        view.bringSubviewToFront(filterButton.superview ?? filterButton)
        view.bringSubviewToFront(titleLabel)
        view.bringSubviewToFront(pantryButton.superview ?? pantryButton)
        view.bringSubviewToFront(addButton.superview ?? addButton)
    }

    private func layoutHeaderChrome() {
        guard let hubSlotView else { return }
        raiseHeaderChrome()
        let hubFrame = hubSlotView.convert(hubSlotView.bounds, to: view)
        let overhang = CGFloat.adaptHeight(8)
        let fadeHeight = max(0, hubFrame.maxY + overhang)
        headerBackdropView.frame = CGRect(
            x: view.bounds.minX,
            y: view.bounds.minY,
            width: view.bounds.width,
            height: fadeHeight
        )
        headerFadeGradient.frame = headerBackdropView.bounds
        let fadeStart = fadeHeight > 0 ? hubFrame.maxY / fadeHeight : 1
        headerFadeGradient.locations = [0, NSNumber(value: Double(fadeStart)), 1]
        refreshHeaderFadeColors()
        headerBlurView.isHidden = hubSlotView.isHidden || hubFrame.height < 1 || overhang < 1
        headerBlurView.frame = CGRect(
            x: view.bounds.minX,
            y: hubFrame.maxY,
            width: view.bounds.width,
            height: overhang
        )
        updateScrollHeaderInset(hubMaxY: hubFrame.maxY)
    }

    private func refreshHeaderFadeColors() {
        headerFadeGradient.colors = AppColor.fadeColors(
            from: view.backgroundColor ?? AppColor.canvas,
            traits: traitCollection
        )
    }

    private func updateScrollHeaderInset(hubMaxY: CGFloat) {
        let topInset = max(0, hubMaxY + contentGapBelowHub - scrollView.frame.minY)
        if scrollView.contentInset.top != topInset {
            let wasAtTop = scrollView.contentOffset.y <= -scrollView.contentInset.top + 1
            scrollView.contentInset.top = topInset
            if wasAtTop {
                scrollView.contentOffset.y = -topInset
            }
        }
        if scrollView.verticalScrollIndicatorInsets.top != topInset {
            scrollView.verticalScrollIndicatorInsets.top = topInset
        }
        let bottomInset = tabBarOverlapInset()
        if scrollView.contentInset.bottom != bottomInset {
            scrollView.contentInset.bottom = bottomInset
        }
        if scrollView.verticalScrollIndicatorInsets.bottom != bottomInset {
            scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    private func tabBarOverlapInset() -> CGFloat {
        guard let tabBar = tabBarController?.tabBar, tabBar.isHidden == false else { return 0 }
        let tabTop = view.convert(tabBar.bounds.origin, from: tabBar).y
        return max(0, view.bounds.maxY - tabTop)
    }

    private func updateEmptyActionClearance() {
        guard emptySection.isHidden == false else { return }
        guard let tabBar = tabBarController?.tabBar, tabBar.isHidden == false else {
            emptySection.setActionBottomInset(0)
            return
        }
        let tabTop = view.convert(tabBar.bounds.origin, from: tabBar).y
        let emptyBottom = view.convert(CGPoint(x: 0, y: emptySection.bounds.maxY), from: emptySection).y
        let clearance = CGFloat.adaptHeight(24) + CGFloat.adaptHeight(8)
        emptySection.setActionBottomInsetPoints(max(0, emptyBottom - (tabTop - clearance)))
    }

    private func applyPhase() {
        showsOfflineEmpty = false
        defer { if !showsOfflineEmpty { reportedOfflineContext = nil } }
        let offline = !NetworkMonitor.shared.isOnline
        let filtering = viewModel.showsFilterResults.value
        segmentControl.isHidden = viewModel.hidesTabs
        chipsScroll.isHidden = viewModel.filterChips.value.isEmpty
        chipsHeightConstraint.designConstant = viewModel.filterChips.value.isEmpty ? 0 : 34
        if filtering {
            browseStack.isHidden = true
            if viewModel.isLoading.value, viewModel.resultRecipes.value.isEmpty {
                emptySection.isHidden = true
                gridStack.isHidden = false
                showSearchSkeletonsIfNeeded()
                scrollView.isHidden = false
                return
            }
            isShowingSearchSkeletons = false
            let empty = viewModel.showsEmptyResults.value
            emptySection.isHidden = !empty
            gridStack.isHidden = empty
            if empty, offline {
                configureOfflineEmpty()
            } else if empty {
                configureFilterEmpty()
            } else {
                renderGrid(recipes: viewModel.resultRecipes.value)
            }
            renderPaginationSkeletons()
            scrollView.isHidden = !emptySection.isHidden
            return
        }
        isShowingSearchSkeletons = false
        removePaginationSkeletons()
        switch viewModel.selectedTab.value {
        case .all:
            emptySection.isHidden = true
            gridStack.isHidden = true
            if viewModel.isLoading.value, viewModel.browseSections.value.isEmpty {
                browseStack.isHidden = false
                showBrowseSkeletonsIfNeeded()
            } else if viewModel.browseSections.value.isEmpty, offline {
                browseStack.isHidden = true
                emptySection.isHidden = false
                configureOfflineEmpty()
            } else {
                browseStack.isHidden = viewModel.browseSections.value.isEmpty
            }
        case .saved:
            browseStack.isHidden = true
            let recipes = viewModel.visibleSavedRecipes.value
            emptySection.isHidden = !recipes.isEmpty
            gridStack.isHidden = recipes.isEmpty
            if recipes.isEmpty, viewModel.isSearchingLocally {
                configureFilterEmpty()
            } else if recipes.isEmpty {
                configureSavedStyleEmpty(
                    title: L10n.tr("recipes.savedEmptyTitle"),
                    subtitle: L10n.tr("recipes.savedEmptySubtitle"),
                    actionTitle: L10n.tr("recipes.createRecipe")
                )
            } else {
                renderGrid(recipes: recipes)
            }
        case .mealPlans:
            browseStack.isHidden = true
            let plans = viewModel.visibleMealPlans.value
            emptySection.isHidden = !plans.isEmpty
            gridStack.isHidden = plans.isEmpty
            if plans.isEmpty, viewModel.isSearchingLocally {
                configureFilterEmpty()
            } else if plans.isEmpty {
                configureSavedStyleEmpty(
                    title: L10n.tr("recipes.mealPlanEmptyTitle"),
                    subtitle: L10n.tr("recipes.mealPlanEmptySubtitle"),
                    actionTitle: L10n.tr("recipes.createMealPlan")
                )
            } else {
                renderPlans(plans)
            }
        }
        scrollView.isHidden = !emptySection.isHidden
    }

    private func showBrowseSkeletonsIfNeeded() {
        guard !isShowingBrowseSkeletons else { return }
        isShowingBrowseSkeletons = true
        browseStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        RecipeBrowseSectionKind.catalogSections.forEach { kind in
            let view = RecipeBrowseSectionView()
            view.showSkeleton(kind: kind)
            browseStack.addArrangedSubview(view)
        }
    }

    private func renderPaginationSkeletons() {
        guard viewModel.isLoadingMoreResults.value else {
            removePaginationSkeletons()
            DispatchQueue.main.async { [weak self] in
                self?.loadMoreResultsIfNearBottom()
            }
            return
        }
        guard !isShowingPaginationSkeletons else { return }
        isShowingPaginationSkeletons = true
        gridStack.isHidden = false
        RecipeCardGrid.appendSkeletonCards(to: gridStack, count: RecipeCardGrid.paginationSkeletonCount)
    }

    private func removePaginationSkeletons() {
        guard isShowingPaginationSkeletons else { return }
        isShowingPaginationSkeletons = false
        RecipeCardGrid.removeSkeletonRows(from: gridStack)
    }

    private func loadMoreResultsIfNearBottom() {
        guard viewModel.showsFilterResults.value, !scrollView.isHidden else { return }
        let gap = scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.height)
        if gap < .adaptHeight(320) {
            viewModel.loadMoreResultsIfNeeded()
        }
    }

    private func showSearchSkeletonsIfNeeded() {
        guard !isShowingSearchSkeletons else { return }
        isShowingSearchSkeletons = true
        renderedGridContent = nil
        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        RecipeCardGrid.appendSkeletonCards(to: gridStack, count: RecipeCardGrid.initialSkeletonCount)
    }

    private func renderBrowse(_ sections: [RecipeBrowseSection]) {
        browseRenderID += 1
        let renderID = browseRenderID
        if sections.isEmpty {
            if !viewModel.isLoading.value {
                isShowingBrowseSkeletons = false
                browseStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            }
            return
        }
        Task { @MainActor [weak self] in
            guard let self, self.browseRenderID == renderID else { return }
            for (index, section) in sections.enumerated() {
                guard self.browseRenderID == renderID else { return }
                await self.applyBrowseSection(section, at: index, renderID: renderID)
            }
            guard self.browseRenderID == renderID else { return }
            while self.browseStack.arrangedSubviews.count > sections.count {
                let extra = self.browseStack.arrangedSubviews.last!
                self.browseStack.removeArrangedSubview(extra)
                extra.removeFromSuperview()
            }
            self.isShowingBrowseSkeletons = false
        }
    }

    private func applyBrowseSection(
        _ section: RecipeBrowseSection,
        at index: Int,
        renderID: Int
    ) async {
        let recipes = Array(section.recipes.prefix(2))
        let view: RecipeBrowseSectionView
        if index < browseStack.arrangedSubviews.count,
           let existing = browseStack.arrangedSubviews[index] as? RecipeBrowseSectionView {
            view = existing
        } else {
            view = RecipeBrowseSectionView()
            browseStack.addArrangedSubview(view)
        }
        view.applySectionChrome(section)
        view.onSeeMore = { [weak self] in
            self?.viewModel.seeMoreTapped(section.id)
        }
        view.onSelect = { [weak self] recipe in
            self?.viewModel.selectRecipe(recipe)
        }
        for (cardIndex, recipe) in recipes.enumerated() {
            guard browseRenderID == renderID else { return }
            view.upsertCard(recipe, at: cardIndex)
            await Task.yield()
        }
        guard browseRenderID == renderID else { return }
        view.trimCards(to: recipes.count)
    }

    private func renderGrid(recipes: [Recipe]) {
        guard renderedGridContent != .recipes(recipes) else { return }
        renderedGridContent = .recipes(recipes)
        gridRenderID += 1
        let renderID = gridRenderID
        if recipes.isEmpty {
            gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            isShowingSearchSkeletons = false
            return
        }
        Task { @MainActor [weak self] in
            guard let self, self.gridRenderID == renderID else { return }
            var start = 0
            var rowIndex = 0
            while start < recipes.count {
                guard self.gridRenderID == renderID else { return }
                self.applyGridRow(itemCount: recipes.count, start: start, at: rowIndex) { card, index in
                    let recipe = recipes[index]
                    card.configure(recipe)
                    card.onSelect = { [weak self] in
                        self?.viewModel.selectRecipe(recipe)
                    }
                }
                start += 2
                rowIndex += 1
                await Task.yield()
            }
            guard self.gridRenderID == renderID else { return }
            self.trimGridRows(to: (recipes.count + 1) / 2)
            self.isShowingSearchSkeletons = false
        }
    }

    private func trimGridRows(to neededRows: Int) {
        while gridStack.arrangedSubviews.count > neededRows {
            let extra = gridStack.arrangedSubviews.last!
            gridStack.removeArrangedSubview(extra)
            extra.removeFromSuperview()
        }
    }

    private func applyGridRow(
        itemCount: Int,
        start: Int,
        at rowIndex: Int,
        configure: (RecipeCardView, Int) -> Void
    ) {
        let row: UIStackView
        if rowIndex < gridStack.arrangedSubviews.count,
           let existing = gridStack.arrangedSubviews[rowIndex] as? UIStackView {
            row = existing
        } else {
            row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = .adaptWidth(8)
            gridStack.addArrangedSubview(row)
        }
        row.tag = 0
        configure(gridCard(in: row, at: 0), start)
        if start + 1 < itemCount {
            configure(gridCard(in: row, at: 1), start + 1)
            while row.arrangedSubviews.count > 2 {
                let extra = row.arrangedSubviews.last!
                row.removeArrangedSubview(extra)
                extra.removeFromSuperview()
            }
        } else {
            while row.arrangedSubviews.count > 1 {
                let extra = row.arrangedSubviews.last!
                row.removeArrangedSubview(extra)
                extra.removeFromSuperview()
            }
            row.addArrangedSubview(UIView())
        }
    }

    private func gridCard(in row: UIStackView, at index: Int) -> RecipeCardView {
        let card: RecipeCardView
        if index < row.arrangedSubviews.count, let existing = row.arrangedSubviews[index] as? RecipeCardView {
            card = existing
        } else {
            if index < row.arrangedSubviews.count {
                let placeholder = row.arrangedSubviews[index]
                row.removeArrangedSubview(placeholder)
                placeholder.removeFromSuperview()
                card = RecipeCardView()
                row.insertArrangedSubview(card, at: index)
            } else {
                card = RecipeCardView()
                row.addArrangedSubview(card)
            }
        }
        return card
    }

    private func renderPlans(_ plans: [MealPlan]) {
        guard renderedGridContent != .plans(plans) else { return }
        renderedGridContent = .plans(plans)
        gridRenderID += 1
        stride(from: 0, to: plans.count, by: 2).enumerated().forEach { rowIndex, start in
            applyGridRow(itemCount: plans.count, start: start, at: rowIndex) { card, index in
                let plan = plans[index]
                card.configure(plan)
                card.onSelect = { [weak self] in
                    self?.viewModel.selectMealPlan(plan)
                }
            }
        }
        trimGridRows(to: (plans.count + 1) / 2)
    }

    private func renderSuggestions(_ titles: [String]) {
        suggestionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        suggestionsView.isHidden = titles.isEmpty
        titles.forEach { title in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(AppColor.labelsPrimary, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: .adaptFont(17), weight: .regular)
            button.contentHorizontalAlignment = .leading
            button.addAction(UIAction { [weak self] _ in
                self?.viewModel.selectSuggestion(title)
            }, for: .touchUpInside)
            suggestionsStack.addArrangedSubview(button)
        }
    }

    private func renderChips(_ chips: [RecipeFilterChip]) {
        chipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chips.forEach { chip in
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .capsule
            config.title = chip.title
            config.titleLineBreakMode = .byTruncatingTail
            config.image = UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            )
            config.imagePlacement = .trailing
            config.imagePadding = 4
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
            config.baseForegroundColor = AppColor.backgroundsPrimary
            config.baseBackgroundColor = AppColor.labelsPrimary
            button.configuration = config
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.controlHaptic = .selection
            button.addAction(UIAction { [weak self] _ in
                self?.viewModel.removeFilterChip(chip)
            }, for: .touchUpInside)
            chipsStack.addArrangedSubview(button)
        }
        view.layoutIfNeeded()
        OnboardingStyle.applyChatChipsEdgeFade(to: chipsScroll)
    }
}

#if DEBUG
extension RecipesViewController {
    var qaHeaderBlurView: UIView { headerBlurView }
    var qaScrollView: UIScrollView { scrollView }
    var qaHubSlotView: UIView? { hubSlotView }

    func qaSelectHub(_ tab: RecipeHubTab) {
        viewModel.selectTab(tab)
    }

    func qaSearch(_ query: String) {
        searchTextField.text = query
        viewModel.updateQuery(query)
        viewModel.searchTapped()
    }
}
#endif

private enum RecipeGridContent: Equatable {
    case recipes([Recipe])
    case plans([MealPlan])
}
