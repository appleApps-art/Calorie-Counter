import UIKit

final class RewardsViewController: BaseViewController {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var levelCardView: RewardLevelCardView!
    @IBOutlet private weak var badgesStackView: AdaptiveStackView!

    var onSelectBadge: ((BadgeProgress) -> Void)?

    private let viewModel: RewardsViewModel
    private var badgeViews: [RewardBadgeView] = []
    private var renderedColumnCount = 0
    private var displayedBadges: [BadgeProgress] = []

    init(viewModel: RewardsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "RewardsViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .rewards }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureChrome()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        backButton.isHidden = (navigationController?.viewControllers.count ?? 1) <= 1
        viewModel.reload()
    }

    override func bindViewModel() {
        viewModel.screen.bind { [weak self] state in
            guard let self, let state else { return }
            self.levelCardView.configure(state)
            self.renderBadges(state.badges)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !displayedBadges.isEmpty, renderedColumnCount != badgeColumnCount {
            renderBadges(displayedBadges)
        }
    }

    private var badgeColumnCount: Int {
        let availableWidth = badgesStackView.bounds.width > 0
            ? badgesStackView.bounds.width : max(1, view.bounds.width - 32)
        let minimumWidth: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 150 : 118
        return max(1, min(5, Int((availableWidth + 8) / (minimumWidth + 8))))
    }

    private func configureChrome() {
        view.backgroundColor = AppColor.gray6
        titleLabel.text = L10n.tr("rewards.title")
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        titleLabel.textAlignment = .center
        OnboardingStyle.styleBackButton(backButton)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        badgesStackView.axis = .vertical
        badgesStackView.alignment = .fill
        badgesStackView.distribution = .fill
        badgesStackView.spacing = 8
        badgesStackView.adaptSpacing = true
    }

    private func renderBadges(_ badges: [BadgeProgress]) {
        displayedBadges = badges
        let columns = badgeColumnCount
        if badgeViews.count != badges.count || renderedColumnCount != columns {
            renderedColumnCount = columns
            badgesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            badgeViews.removeAll()
            var index = 0
            while index < badges.count {
                let row = AdaptiveStackView()
                row.axis = .horizontal
                row.alignment = .fill
                row.distribution = .fillEqually
                row.spacing = 8
                row.adaptSpacing = true
                let end = min(index + columns, badges.count)
                for _ in index..<end {
                    let cell = RewardBadgeView()
                    cell.addTarget(self, action: #selector(badgeTapped(_:)), for: .touchUpInside)
                    row.addArrangedSubview(cell)
                    badgeViews.append(cell)
                }
                for _ in end..<(index + columns) {
                    row.addArrangedSubview(UIView())
                }
                badgesStackView.addArrangedSubview(row)
                index = end
            }
        }
        zip(badgeViews, badges).forEach { view, progress in
            view.configure(progress)
        }
    }

    @objc private func badgeTapped(_ sender: RewardBadgeView) {
        guard let progress = sender.progress else { return }
        onSelectBadge?(progress)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
}
