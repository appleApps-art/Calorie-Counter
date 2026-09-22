import UIKit

final class ProgressCoordinator {
    private let navigationController: UINavigationController
    private let container: DIContainer
    private weak var progressViewModel: ProgressViewModel?
    private weak var photosViewController: ProgressPhotosViewController?

    init(navigationController: UINavigationController, container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func makeRoot() -> UIViewController {
        let viewModel = container.makeProgressViewModel()
        progressViewModel = viewModel
        viewModel.onLog = { [weak self] in
            self?.openLogSheet()
        }
        viewModel.onSeeAllPhotos = { [weak self] in
            self?.openPhotos()
        }
        viewModel.onAddPhoto = { [weak self] in
            self?.openProgressPhoto()
        }
        viewModel.onUpgrade = { [weak self] in
            self?.openPaywall()
        }
        viewModel.onRequirePremium = { [weak self] then in
            self?.openPaywall(then: then)
        }
        viewModel.onLogWeight = { [weak self] in
            self?.openLogWeight()
        }
        viewModel.onLogExercise = { [weak self] in
            self?.openLogExercise()
        }
        viewModel.onCaptureProgressPhoto = { [weak self] in
            self?.openProgressPhoto()
        }
        return ProgressViewController(viewModel: viewModel)
    }

    func openLogSheet() {
        let sheet = ProgressLogSheetViewController { [weak self] action in
            self?.progressViewModel?.handleLog(action)
        }
        navigationController.present(sheet, animated: true)
    }

    func openPhotos() {
        let viewController = ProgressPhotosViewController(sections: progressViewModel?.photoSections.value ?? [])
        photosViewController = viewController
        viewController.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewController.onLogNew = { [weak self] in
            self?.openProgressPhoto()
        }
        viewController.onAppear = { [weak self, weak viewController] in
            self?.progressViewModel?.reload()
            viewController?.update(sections: self?.progressViewModel?.photoSections.value ?? [])
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    func openPaywall(then action: (() -> Void)? = nil) {
        guard let presenter = navigationController.topViewController else { return }
        PremiumGate.requirePremium(
            isPremium: container.subscriptionService.currentStatus().isPremium,
            coordinator: container.makeSubscriptionCoordinator(),
            from: presenter,
            placement: .main
        ) { [weak self] in
            self?.progressViewModel?.viewDidLoad()
            action?()
        }
    }

    func openLogWeight() {
        let kilograms = initialKilograms()
        let viewModel = LogWeightViewModel(
            logWeightUseCase: container.logWeightUseCase,
            initialKilograms: kilograms
        )
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onSaved = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onChangeDate = { [weak self, weak viewModel] date in
            self?.openChangeDate(date: date, maximumDate: Date()) { selected in
                viewModel?.updateDate(selected)
            }
        }
        let viewController = LogWeightViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    func openLogExercise() {
        let recordedWeight = (try? container.fetchWeightHistoryUseCase.execute())?
            .filter { $0.date <= Date() && $0.weightKilograms.isFinite && $0.weightKilograms > 0 }
            .max { $0.date < $1.date }?.weightKilograms
        let profileWeight = (try? container.fetchOnboardingStateUseCase.execute())?.weightKg
        let viewModel = LogWorkoutViewModel(
            logWorkoutUseCase: container.logWorkoutUseCase,
            bodyWeightKilograms: recordedWeight ?? profileWeight
        )
        viewModel.onBack = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onSaved = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onChangeDate = { [weak self, weak viewModel] date in
            self?.openChangeDate(date: date, maximumDate: Date()) { selected in
                viewModel?.updateDate(selected)
            }
        }
        let viewController = LogWorkoutViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    func openProgressPhoto() {
        let viewModel = ProgressPhotoCameraViewModel(
            saveProgressPhotoUseCase: container.saveProgressPhotoUseCase
        )
        viewModel.onClose = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        viewModel.onFinished = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        let viewController = ProgressPhotoCameraViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    func openChangeDate(date: Date, maximumDate: Date? = nil, onSelect: @escaping (Date) -> Void) {
        let viewController = ChangeDateSheetViewController(date: date, maximumDate: maximumDate)
        viewController.modalPresentationStyle = .pageSheet
        viewController.sheetPresentationController?.applyFigmaInspectorDetent(522)
        viewController.onClose = { [weak viewController] in
            viewController?.dismiss(animated: true)
        }
        viewController.onSelect = { [weak viewController] selected in
            onSelect(selected)
            viewController?.dismiss(animated: true)
        }
        navigationController.present(viewController, animated: true)
    }

    private func initialKilograms() -> Double {
        if let latest = try? container.fetchWeightHistoryUseCase.execute().last {
            return latest.weightKilograms
        }
        if let profile = try? container.fetchOnboardingStateUseCase.execute(),
           let weight = profile.weightKg {
            return weight
        }
        return 60
    }
}
