import UIKit

final class FoodSearchCategoryViewController: BaseViewController {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var emptySection: EmptyScreenView!
    @IBOutlet private weak var stackView: UIStackView!

    private let viewModel: FoodSearchCategoryViewModel
    private let paginationErrorView = EmptyScreenView()
    private var renderedItemIDs: [UUID] = []
    private var isShowingInitialSkeletons = false
    private var isShowingPaginationSkeletons = false

    init(viewModel: FoodSearchCategoryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "FoodSearchCategoryViewController")
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
        cardView.useLiveGlass = false
        cardView.applyCardShadow = true
        cardView.showsHairlineBorder = false
        cardView.showsDropShadow = true
        emptySection.configure(title: L10n.tr("search.emptyTitle"), subtitle: nil, actionTitle: nil)
        emptySection.onAction = { [weak self] in self?.viewModel.retryLoading() }
        paginationErrorView.configure(
            title: L10n.tr("search.catalogLoadFailed"), subtitle: nil,
            actionTitle: L10n.tr("search.retry"), systemImage: "arrow.clockwise"
        )
        paginationErrorView.onAction = { [weak self] in self?.viewModel.retryLoading() }
        scrollView.delegate = self
        viewModel.viewDidLoad()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func bindViewModel() {
        viewModel.items.bind { [weak self] _ in
            self?.render()
        }
        viewModel.isLoading.bind { [weak self] _ in
            self?.render()
        }
        viewModel.loadFailed.bind { [weak self] _ in
            self?.render()
        }
        viewModel.isLoadingMore.bind { [weak self] _ in
            self?.render()
        }
    }

    @objc
    private func backTapped() {
        viewModel.backTapped()
    }

    private func render() {
        let items = viewModel.items.value
        if viewModel.isLoading.value, items.isEmpty {
            showInitialSkeletonsIfNeeded()
            cardView.isHidden = false
            emptySection.isHidden = true
            return
        }
        removeInitialSkeletonsIfNeeded()
        paginationErrorView.removeFromSuperview()
        appendItemsIfNeeded(items)
        if viewModel.isLoadingMore.value {
            showPaginationSkeletonsIfNeeded()
        } else {
            removePaginationSkeletonsIfNeeded()
        }
        if viewModel.loadFailed.value {
            if items.isEmpty {
                emptySection.configure(title: L10n.tr("search.catalogLoadFailed"), subtitle: nil,
                                       actionTitle: L10n.tr("search.retry"), systemImage: "arrow.clockwise")
            } else if !viewModel.isLoadingMore.value {
                stackView.addArrangedSubview(paginationErrorView)
            }
        } else {
            emptySection.configure(title: L10n.tr("search.emptyTitle"), subtitle: nil, actionTitle: nil)
        }
        let showsList = !items.isEmpty || viewModel.isLoading.value || viewModel.isLoadingMore.value
        cardView.isHidden = !showsList
        emptySection.isHidden = showsList
    }

    private func appendItemsIfNeeded(_ items: [FoodSearchItem]) {
        if renderedItemIDs.isEmpty {
            items.enumerated().forEach { index, item in
                addItemRow(item, showsSeparator: index < items.count - 1)
            }
            renderedItemIDs = items.map(\.id)
            return
        }
        let renderedPrefix = Array(items.prefix(renderedItemIDs.count).map(\.id))
        guard items.count >= renderedItemIDs.count, renderedPrefix == renderedItemIDs else {
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            renderedItemIDs = []
            isShowingPaginationSkeletons = false
            items.enumerated().forEach { index, item in
                addItemRow(item, showsSeparator: index < items.count - 1)
            }
            renderedItemIDs = items.map(\.id)
            return
        }
        guard items.count > renderedItemIDs.count else { return }
        if let last = lastItemRow() {
            last.setShowsSeparator(true)
        }
        let start = renderedItemIDs.count
        items.suffix(from: start).enumerated().forEach { offset, item in
            addItemRow(item, showsSeparator: start + offset < items.count - 1)
        }
        renderedItemIDs = items.map(\.id)
    }

    private func addItemRow(_ item: FoodSearchItem, showsSeparator: Bool) {
        let row = FoodSearchResultRowView()
        row.configure(item, showsSeparator: showsSeparator)
        row.onSelect = { [weak self] id in
            self?.viewModel.selectItem(id: id)
        }
        if isShowingPaginationSkeletons {
            let index = stackView.arrangedSubviews.firstIndex { view in
                (view as? FoodSearchResultRowView)?.isSkeleton == true
            } ?? stackView.arrangedSubviews.count
            stackView.insertArrangedSubview(row, at: index)
        } else {
            stackView.addArrangedSubview(row)
        }
    }

    private func lastItemRow() -> FoodSearchResultRowView? {
        stackView.arrangedSubviews.reversed().compactMap { $0 as? FoodSearchResultRowView }.first { !$0.isSkeleton }
    }

    private func showInitialSkeletonsIfNeeded() {
        guard !isShowingInitialSkeletons else { return }
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        renderedItemIDs = []
        isShowingPaginationSkeletons = false
        (0..<8).forEach { index in
            let row = FoodSearchResultRowView()
            row.showSkeleton(showsSeparator: index < 7)
            stackView.addArrangedSubview(row)
        }
        isShowingInitialSkeletons = true
    }

    private func removeInitialSkeletonsIfNeeded() {
        guard isShowingInitialSkeletons else { return }
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        isShowingInitialSkeletons = false
    }

    private func showPaginationSkeletonsIfNeeded() {
        guard !isShowingPaginationSkeletons else { return }
        if let last = lastItemRow() {
            last.setShowsSeparator(true)
        }
        (0..<2).forEach { index in
            let row = FoodSearchResultRowView()
            row.showSkeleton(showsSeparator: index == 0)
            stackView.addArrangedSubview(row)
        }
        isShowingPaginationSkeletons = true
    }

    private func removePaginationSkeletonsIfNeeded() {
        guard isShowingPaginationSkeletons else { return }
        stackView.arrangedSubviews
            .compactMap { $0 as? FoodSearchResultRowView }
            .filter(\.isSkeleton)
            .forEach { row in
                stackView.removeArrangedSubview(row)
                row.removeFromSuperview()
            }
        isShowingPaginationSkeletons = false
        lastItemRow()?.setShowsSeparator(false)
    }
}

extension FoodSearchCategoryViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging || scrollView.isDecelerating else { return }
        let gap = scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.height)
        if gap < .adaptHeight(320) {
            viewModel.loadMoreIfNeeded()
        }
    }
}
