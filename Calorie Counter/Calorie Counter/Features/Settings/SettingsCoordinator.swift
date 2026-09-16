import MessageUI
import UIKit

final class SettingsCoordinator: NSObject, MFMailComposeViewControllerDelegate {
    private let navigationController: UINavigationController
    private let container: DIContainer
    private var viewModel: SettingsViewModel?
    private weak var settingsViewController: SettingsViewController?

    init(navigationController: UINavigationController, container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {
        let viewModel = container.makeSettingsViewModel()
        self.viewModel = viewModel
        let viewController = SettingsViewController(viewModel: viewModel)
        settingsViewController = viewController
        viewController.onOpenNotifications = { [weak self] in
            self?.openNotifications()
        }
        viewController.onOpenSubscription = { [weak self] in
            self?.openSubscription()
        }
        viewController.onOpenNutritionGoals = { [weak self] in
            self?.openNutritionGoals()
        }
        viewController.onOpenWeightGoal = { [weak self] in
            self?.openWeightGoal()
        }
        viewController.onOpenTheme = { [weak self] in
            self?.openTheme()
        }
        viewController.onOpenHealth = { [weak self] in
            self?.openHealthSync()
        }
        viewController.onShareApp = { [weak self] in
            self?.shareApp()
        }
        viewController.onOpenHelp = { [weak self] in
            self?.openHelp()
        }
        viewController.onCopyUserID = { [weak self] in
            self?.copyUserID()
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func openNotifications() {
        var inboxStore: NotificationInboxStoring = container.notificationInboxStore
#if DEBUG
        if QALaunchConfiguration.isActive, QALaunchConfiguration.route == .settingsNotifications {
            inboxStore = QANotificationInboxStore(filled: QALaunchConfiguration.seed == .filled)
        }
#endif
        let inbox = NotificationsInboxViewController(
            viewModel: NotificationsInboxViewModel(
                inboxStore: inboxStore,
                permissionUseCase: container.requestNotificationPermissionUseCase
            ),
            settingsPresentation: true
        )
        present(inbox)
    }

    private func openSubscription() {
        guard let presenter = presenter() else { return }
        container.makeSubscriptionCoordinator().presentPaywall(
            from: presenter,
            placement: .settings
        )
    }

    private func openNutritionGoals() {
        guard let viewModel else { return }
        let goals = GoalType.allCases
        let selected = viewModel.profile.value.goalType
        let sheet = SettingsOptionPickerViewController(
            title: L10n.tr("settings.nutritionGoals"),
            options: goals.map {
                SettingsOptionPickerViewController.Option(
                    title: viewModel.nutritionTitle(for: $0),
                    isSelected: $0 == selected
                )
            },
            analyticsScreen: .settingsNutritionGoals
        ) { [weak viewModel] index in
            guard goals.indices.contains(index) else { return }
            viewModel?.saveNutritionGoal(goals[index])
        }
        present(sheet)
    }

    private func openWeightGoal() {
        guard let viewModel else { return }
        let kilograms = viewModel.resolvedWeightGoalKilograms()
            ?? viewModel.profile.value.weightKg
        let sheet = SettingsWeightGoalViewController(
            isMetric: viewModel.usesMetric.value,
            kilograms: kilograms
        ) { [weak viewModel] kilograms in
            viewModel?.saveWeightGoal(kilograms)
        }
        present(sheet)
    }

    private func openTheme() {
        guard let viewModel else { return }
        let modes = AppearanceMode.allCases
        let selected = viewModel.appearanceMode.value
        let sheet = SettingsOptionPickerViewController(
            title: L10n.tr("settings.theme"),
            options: modes.map {
                SettingsOptionPickerViewController.Option(
                    title: $0.localizedTitle,
                    isSelected: $0 == selected
                )
            },
            analyticsScreen: .settingsTheme
        ) { [weak viewModel] index in
            guard modes.indices.contains(index) else { return }
            viewModel?.saveAppearance(modes[index])
            AppAppearance.apply(modes[index])
        }
        present(sheet)
    }

    private func openHealthSync() {
        guard let viewModel else { return }
        let sheet = SettingsHealthSyncViewController(viewModel: viewModel) { [weak self] in
            self?.openHealthApp()
        }
        present(sheet)
    }

    private func shareApp() {
        guard let presenter = presenter() else { return }
        let activity = UIActivityViewController(
            activityItems: [L10n.tr("settings.share.text")],
            applicationActivities: nil
        )
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
        }
        presenter.present(activity, animated: true)
    }

    private func openHelp() {
        guard let presenter = presenter() else { return }
        let address = L10n.tr("settings.support.email")
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([address])
            presenter.present(mail, animated: true)
            return
        }
        guard let url = URL(string: "mailto:\(address)") else { return }
        UIApplication.shared.open(url)
    }

    private func copyUserID() {
        UIPasteboard.general.string = viewModel?.userIDText.value
    }

    private func openHealthApp() {
        guard let url = URL(string: "x-apple-health://") else { return }
        UIApplication.shared.open(url)
    }

    private func present(_ viewController: UIViewController) {
        presenter()?.present(viewController, animated: true)
    }

    private func presenter() -> UIViewController? {
        settingsViewController ?? navigationController.topViewController
    }

    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true)
    }
}

#if DEBUG
extension SettingsCoordinator {
    func qaOpen(_ route: QARoute) {
        switch route {
        case .settingsNutrition:
            openNutritionGoals()
        case .settingsWeight:
            openWeightGoal()
        case .settingsTheme:
            openTheme()
        case .settingsNotifications:
            openNotifications()
        case .settingsHealth:
            openHealthSync()
        default:
            break
        }
    }
}
#endif
