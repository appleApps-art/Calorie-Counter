import UIKit

final class FoodSearchViewController: BaseViewController, UITextFieldDelegate {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var searchField: AdaptiveView!
    @IBOutlet private weak var searchIconButton: UIButton!
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var micButton: UIButton!
    @IBOutlet private weak var clearSearchButton: UIButton!
    @IBOutlet private weak var aiTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var aiCard: AdaptiveView!
    @IBOutlet private weak var aiStackView: UIStackView!
    @IBOutlet private weak var resultsTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var resultsCard: AdaptiveView!
    @IBOutlet private weak var resultsStackView: UIStackView!
    @IBOutlet private weak var aiSection: UIView!
    @IBOutlet private weak var resultsSection: UIView!
    @IBOutlet private weak var emptySection: EmptyScreenView!
    private var showsOfflineEmpty = false
    @IBOutlet private weak var browseSection: UIView!
    @IBOutlet private weak var browseStackView: UIStackView!
    @IBOutlet private weak var scopeContainer: UIView!
    @IBOutlet private weak var scopeHeightConstraint: AdaptiveConstraint!
    @IBOutlet private weak var scopeControl: RecipeHubSegmentControl!

    private let viewModel: FoodSearchViewModel
    private let micChrome = VoiceMicButtonChrome()
    private var isShowingBrowseSkeletons = false
    private var searchSkeletonRows: [FoodSearchResultRowView] = []

    init(viewModel: FoodSearchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "FoodSearchViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .foodSearch }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        backgroundImageView.image = UIImage(named: "appBackground")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.isHidden = false
        view.sendSubviewToBack(backgroundImageView)
        navigationItem.largeTitleDisplayMode = .never
        configureHeader()
        configureSearch()
        configureSections()
        scopeContainer.isHidden = !viewModel.showsScopeControl
        scopeHeightConstraint.designConstant = viewModel.showsScopeControl ? 48 : 0
        scopeControl.configure(titles: FoodSearchScope.allCases.map { L10n.tr($0.titleKey) },
                               selectedIndex: viewModel.scope.value.rawValue)
        scopeControl.onSelectIndex = { [weak self] index in
            guard let scope = FoodSearchScope(rawValue: index) else { return }
            self?.view.endEditing(true)
            self?.viewModel.selectScope(scope)
        }
        viewModel.viewDidLoad()
        applyPhase()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.refreshRecentFoods()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        aiCard.layer.borderWidth = 1
        aiCard.layer.borderColor = AppColor.teal.resolvedColor(with: traitCollection).cgColor
        aiCard.layer.cornerRadius = .adaptWidth(24)
        aiCard.layer.cornerCurve = .continuous
        micChrome.layoutIfNeeded()
    }

    override func bindViewModel() {
        viewModel.scope.bind { [weak self] scope in
            self?.scopeControl.selectedIndex = scope.rawValue
        }
        viewModel.queryText.bind { [weak self] value in
            guard self?.searchTextField.text != value else { return }
            self?.searchTextField.text = value
        }
        viewModel.isSearching.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.isLoadingBrowse.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.suggestedItems.bind { [weak self] items in
            self?.render(items, in: self?.aiStackView, card: self?.aiCard, section: self?.aiSection)
            self?.applyPhase()
        }
        viewModel.resultItems.bind { [weak self] items in
            guard let self else { return }
            self.render(items, in: self.resultsStackView, card: self.resultsCard, section: self.resultsSection)
            // Exact catalog matches must appear above the separate AI suggestions section.
            if let stack = self.resultsSection.superview as? UIStackView,
               self.aiSection.superview === stack,
               let resultsIndex = stack.arrangedSubviews.firstIndex(of: self.resultsSection),
               let aiIndex = stack.arrangedSubviews.firstIndex(of: self.aiSection) {
                let exact = items.contains {
                    SearchFoodProductsUseCase.nameRank($0.title, query: self.viewModel.queryText.value) == 0
                }
                if exact && resultsIndex > aiIndex {
                    stack.removeArrangedSubview(self.resultsSection)
                    stack.insertArrangedSubview(self.resultsSection, at: aiIndex)
                } else if !exact && aiIndex > resultsIndex {
                    stack.removeArrangedSubview(self.aiSection)
                    stack.insertArrangedSubview(self.aiSection, at: resultsIndex)
                }
            }
            self.applyPhase()
        }
        viewModel.resultsTitleText.bind { [weak self] value in
            self?.resultsTitleLabel.text = value
            self?.resultsTitleLabel.isHidden = value.isEmpty
            self?.applyPhase()
        }
        viewModel.showsEmptyResults.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.browseSections.bind { [weak self] sections in
            self?.renderBrowse(sections)
            self?.applyPhase()
        }
        viewModel.phase.bind { [weak self] _ in
            self?.applyPhase()
        }
        viewModel.isRecording.bind { [weak self] _ in
            self?.applyMic()
        }
        viewModel.canConfirmQuery.bind { [weak self] _ in
            self?.applyMic()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        viewModel.updateQuery(textField.text ?? "")
        viewModel.searchTapped()
        textField.resignFirstResponder()
        return true
    }

    @objc
    private func backTapped() {
        view.endEditing(true)
        viewModel.backTapped()
    }

    @objc
    private func clearTapped() {
        viewModel.clearQuery()
        searchTextField.becomeFirstResponder()
    }

    @objc
    private func micTapped() {
        viewModel.trailingActionTapped()
    }

    @objc
    private func queryChanged() {
        viewModel.updateQuery(searchTextField.text ?? "")
    }

    private func configureHeader() {
        titleLabel.text = viewModel.titleText
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
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    private func configureSearch() {
        searchField.useLiveGlass = true
        searchField.applyButtonGlass = true
        searchField.applyCardShadow = true
        searchField.showsDropShadow = true
        searchTextField.delegate = self
        searchTextField.borderStyle = .none
        searchTextField.backgroundColor = .clear
        searchTextField.font = .systemFont(ofSize: 17, weight: .medium)
        searchTextField.textColor = AppColor.labelVibrantPrimary
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: viewModel.placeholderText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: AppColor.labelsSecondary
            ]
        )
        searchTextField.returnKeyType = .search
        searchTextField.addTarget(self, action: #selector(queryChanged), for: .editingChanged)
        OnboardingStyle.stylePlainSymbolButton(
            searchIconButton,
            systemName: "magnifyingglass",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        micChrome.attach(micButton)
        applyMic()
        OnboardingStyle.styleGlassSymbolButton(
            clearSearchButton,
            systemName: "xmark",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        micButton.controlHaptic = .medium
        clearSearchButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
    }

    private func applyMic() {
        micChrome.apply(
            isRecording: viewModel.isRecording.value,
            canConfirm: viewModel.canConfirmQuery.value
        )
    }

    private func configureSections() {
        aiTitleLabel.attributedText = Self.sparklesTitle(L10n.tr("search.aiSuggested"))
        resultsTitleLabel.text = L10n.tr("search.results")
        OnboardingStyle.lockFigmaFont(
            resultsTitleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        aiCard.useLiveGlass = false
        aiCard.applyCardShadow = true
        aiCard.showsHairlineBorder = false
        aiCard.showsDropShadow = true
        aiCard.layer.borderWidth = 1
        aiCard.layer.borderColor = AppColor.teal.resolvedColor(with: traitCollection).cgColor
        resultsCard.useLiveGlass = false
        resultsCard.applyCardShadow = true
        resultsCard.showsHairlineBorder = false
        resultsCard.showsDropShadow = true
        configureNothingFound()
        emptySection.onAction = { [weak self] in
            guard let self else { return }
            self.view.endEditing(true)
            // Offline there is no one to ask; the button searches again instead.
            if self.showsOfflineEmpty {
                Analytics.tracker.track(.retryTapped(context: "food_search"))
                self.viewModel.searchTapped()
            } else {
                self.viewModel.askBityTapped()
            }
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(networkChanged), name: NetworkMonitor.didChange, object: nil
        )
        aiSection.isHidden = true
        resultsSection.isHidden = true
        emptySection.isHidden = true
        browseSection.isHidden = true
    }

    private func render(
        _ items: [FoodSearchItem],
        in stack: UIStackView?,
        card: AdaptiveView?,
        section: UIView?
    ) {
        guard let stack else { return }
        if stack === resultsStackView {
            searchSkeletonRows.removeAll()
        }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        items.enumerated().forEach { index, item in
            let row = FoodSearchResultRowView()
            row.configure(item, showsSeparator: index < items.count - 1)
            row.onSelect = { [weak self] id in
                self?.view.endEditing(true)
                self?.viewModel.selectItem(id: id)
            }
            stack.addArrangedSubview(row)
        }
        card?.layer.borderColor = card === aiCard
            ? AppColor.teal.resolvedColor(with: traitCollection).cgColor
            : card?.layer.borderColor
    }

    private func renderBrowse(_ sections: [FoodSearchBrowseSection]) {
        isShowingBrowseSkeletons = false
        browseStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        sections.forEach { section in
            let view = FoodSearchCategorySectionView()
            view.configure(section)
            view.onSeeMore = { [weak self] in
                self?.view.endEditing(true)
                self?.viewModel.seeMoreTapped(section.category)
            }
            view.onRetry = { [weak self] in self?.viewModel.retryBrowse(section.category) }
            view.onSelect = { [weak self] id in
                self?.view.endEditing(true)
                self?.viewModel.selectItem(id: id)
            }
            browseStackView.addArrangedSubview(view)
        }
    }

    @objc private func networkChanged() {
        if NetworkMonitor.shared.isOnline {
            if showsOfflineEmpty { viewModel.searchTapped() }
            viewModel.retryFailedBrowse()
        }
        applyPhase()
    }

    private func configureNothingFound() {
        emptySection.configure(
            title: L10n.tr("search.emptyTitle"),
            subtitle: L10n.tr("search.emptySubtitle"),
            actionTitle: L10n.tr("search.askBity")
        )
    }

    private func applyPhase() {
        let phase = viewModel.phase.value
        let isResults = phase == .results
        let isEmpty = isResults && viewModel.showsEmptyResults.value
        let isSearching = viewModel.isSearching.value
        let showsSearchSkeletons = isResults && isSearching && !isEmpty
        if isResults {
            isShowingBrowseSkeletons = false
            browseSection.isHidden = true
            emptySection.isHidden = !isEmpty
            // Offline the search still looks through the catalog and foods already seen; only when
            // that finds nothing does the screen say the rest needs the internet.
            let offlineEmpty = isEmpty && !NetworkMonitor.shared.isOnline
            if offlineEmpty != showsOfflineEmpty {
                showsOfflineEmpty = offlineEmpty
                if offlineEmpty {
                    Analytics.tracker.track(.offlineStateShown(context: "food_search"))
                    emptySection.configureOffline()
                } else {
                    configureNothingFound()
                }
            }
            aiSection.isHidden = !isResults || isEmpty || viewModel.suggestedItems.value.isEmpty
            if showsSearchSkeletons {
                showSearchSkeletonsIfNeeded()
                resultsSection.isHidden = false
            } else {
                removeSearchSkeletons()
                resultsSection.isHidden = isEmpty || viewModel.resultItems.value.isEmpty
            }
            return
        }
        removeSearchSkeletons()
        emptySection.isHidden = true
        aiSection.isHidden = true
        resultsSection.isHidden = true
        if viewModel.isLoadingBrowse.value && viewModel.browseSections.value.isEmpty {
            showBrowseSkeletonsIfNeeded()
            browseSection.isHidden = false
        } else {
            browseSection.isHidden = viewModel.browseSections.value.isEmpty
        }
    }

    private func showBrowseSkeletonsIfNeeded() {
        guard !isShowingBrowseSkeletons else { return }
        isShowingBrowseSkeletons = true
        browseStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        viewModel.visibleCatalogCategories.forEach { category in
            let view = FoodSearchCategorySectionView()
            view.showSkeleton(category: category)
            browseStackView.addArrangedSubview(view)
        }
    }

    private func showSearchSkeletonsIfNeeded() {
        let hasResults = !viewModel.resultItems.value.isEmpty || !viewModel.suggestedItems.value.isEmpty
        let count = hasResults ? 3 : 6
        if searchSkeletonRows.count != count {
            removeSearchSkeletons()
            (resultsStackView.arrangedSubviews.last as? FoodSearchResultRowView)?.setShowsSeparator(true)
            searchSkeletonRows = (0..<count).map { index in
                let row = FoodSearchResultRowView()
                row.showSkeleton(showsSeparator: index < count - 1)
                row.accessibilityElementsHidden = true
                resultsStackView.addArrangedSubview(row)
                return row
            }
        }
        resultsTitleLabel.text = L10n.tr("search.results")
        resultsTitleLabel.isHidden = false
    }

    private func removeSearchSkeletons() {
        guard !searchSkeletonRows.isEmpty else { return }
        searchSkeletonRows.forEach { $0.removeFromSuperview() }
        searchSkeletonRows.removeAll()
        (resultsStackView.arrangedSubviews.last as? FoodSearchResultRowView)?.setShowsSeparator(false)
    }

    private static func sparklesTitle(_ text: String) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let result = NSMutableAttributedString()
        if let image = OnboardingStyle.symbol("sparkles", pointSize: 15) {
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(AppColor.labelVibrantPrimary, renderingMode: .alwaysOriginal)
            attachment.bounds = CGRect(x: 0, y: -2, width: 15, height: 15)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: " ", attributes: [.font: font]))
        }
        result.append(NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: AppColor.labelVibrantPrimary,
                .kern: -0.23
            ]
        ))
        return result
    }
}
