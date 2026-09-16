import UIKit

final class RewardsCoordinator {
    private let navigationController: UINavigationController
    private let container: DIContainer

    init(navigationController: UINavigationController, container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func makeRoot() -> UIViewController {
        let viewModel = container.makeRewardsViewModel()
        let list = RewardsViewController(viewModel: viewModel)
        list.onSelectBadge = { [weak self] progress in
            self?.showDetail(progress)
        }
        return list
    }

    private func showDetail(_ progress: BadgeProgress) {
        let detail = RewardDetailViewController(progress: progress)
        detail.modalPresentationStyle = .overFullScreen
        detail.modalTransitionStyle = .coverVertical
        if progress.isComplete {
            detail.onViewed = { [weak self] in
                try? self?.container.markBadgeSeenUseCase.execute(progress.badge)
            }
        }
        navigationController.present(detail, animated: true)
    }
}
