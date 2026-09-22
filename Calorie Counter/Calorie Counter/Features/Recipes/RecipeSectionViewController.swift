import UIKit

final class RecipeSectionViewController: BaseViewController {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var gridStack: UIStackView!

    private let viewModel: RecipeSectionViewModel
    private var renderedRecipeCount = 0
    private var isShowingPaginationSkeletons = false
    private let offlineView = EmptyScreenView()

    init(viewModel: RecipeSectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "RecipeSectionViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .recipeSection }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? .black : UIColor(red: 231/255, green: 1, blue: 252/255, alpha: 1) }
        view.subviews.compactMap { $0 as? HomeBackgroundView }.forEach { $0.isHidden = true }
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
        scrollView.delegate = self
        installOfflineView()
        viewModel.viewDidLoad()
    }

    private func installOfflineView() {
        offlineView.translatesAutoresizingMaskIntoConstraints = false
        offlineView.isHidden = true
        offlineView.setContentTopInset(100)
        offlineView.setMessageWidth(300)
        offlineView.configureOffline(illustrationName: "emptyImage1") { [weak self] in
            Analytics.tracker.track(.retryTapped(context: "recipe_section"))
            self?.viewModel.viewDidLoad()
        }
        view.addSubview(offlineView)
        NSLayoutConstraint.activate([
            offlineView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            offlineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            offlineView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        NotificationCenter.default.addObserver(
            self, selector: #selector(networkChanged), name: NetworkMonitor.didChange, object: nil
        )
    }

    @objc private func networkChanged() {
        if NetworkMonitor.shared.isOnline, !offlineView.isHidden {
            viewModel.viewDidLoad()
        }
        renderContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func bindViewModel() {
        viewModel.recipes.bind { [weak self] _ in
            self?.renderContent()
        }
        viewModel.isLoading.bind { [weak self] _ in
            self?.renderContent()
        }
        viewModel.isLoadingMore.bind { [weak self] _ in
            self?.renderContent()
        }
    }

    @objc private func backTapped() { viewModel.backTapped() }

    private func renderContent() {
        let recipes = viewModel.recipes.value
        let showsOffline = !viewModel.isLoading.value && recipes.isEmpty && !NetworkMonitor.shared.isOnline
        if showsOffline, offlineView.isHidden {
            Analytics.tracker.track(.offlineStateShown(context: "recipe_section"))
        }
        offlineView.isHidden = !showsOffline
        scrollView.isHidden = showsOffline
        if viewModel.isLoading.value, recipes.isEmpty {
            renderedRecipeCount = 0
            isShowingPaginationSkeletons = false
            gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            RecipeCardGrid.appendSkeletonCards(to: gridStack, count: RecipeCardGrid.initialSkeletonCount)
            return
        }
        if recipes.count != renderedRecipeCount {
            RecipeCardGrid.removeSkeletonRows(from: gridStack)
            isShowingPaginationSkeletons = false
            gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            RecipeCardGrid.appendCards(to: gridStack, count: recipes.count) { index, card in
                card.configure(recipes[index])
                card.onSelect = { [weak self] in self?.viewModel.select(recipes[index]) }
            }
            renderedRecipeCount = recipes.count
        }
        if viewModel.isLoadingMore.value {
            if !isShowingPaginationSkeletons {
                RecipeCardGrid.appendSkeletonCards(
                    to: gridStack,
                    count: RecipeCardGrid.paginationSkeletonCount
                )
                isShowingPaginationSkeletons = true
                gridStack.layoutIfNeeded()
            }
        } else if isShowingPaginationSkeletons {
            RecipeCardGrid.removeSkeletonRows(from: gridStack)
            isShowingPaginationSkeletons = false
        }
        DispatchQueue.main.async { [weak self] in
            self?.loadMoreIfNearBottom()
        }
    }

    private func loadMoreIfNearBottom() {
        let gap = scrollView.contentSize.height - (scrollView.contentOffset.y + scrollView.bounds.height)
        if gap < .adaptHeight(320) {
            viewModel.loadMoreIfNeeded()
        }
    }
}

extension RecipeSectionViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        loadMoreIfNearBottom()
    }
}

