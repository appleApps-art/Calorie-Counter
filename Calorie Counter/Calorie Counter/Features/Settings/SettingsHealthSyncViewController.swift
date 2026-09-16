import UIKit

final class SettingsHealthSyncViewController: BaseViewController {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var statusCard: AdaptiveView!
    @IBOutlet private weak var statusStackView: UIStackView!
    @IBOutlet private weak var detailsCard: AdaptiveView!
    @IBOutlet private weak var detailsTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var detailsTitleHeightConstraint: AdaptiveConstraint!
    @IBOutlet private weak var detailsTitleTopConstraint: AdaptiveConstraint!
    @IBOutlet private weak var detailsStackView: UIStackView!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var backgroundImageView: UIImageView!

    private let viewModel: SettingsViewModel
    private let onOpenHealth: () -> Void

    init(viewModel: SettingsViewModel, onOpenHealth: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onOpenHealth = onOpenHealth
        super.init(nibName: "SettingsHealthSyncViewController")
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 38
        }
    }

    override var analyticsScreen: AnalyticsScreen? { .settingsHealth }

    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundImageView.image = UIImage(named: "OnboardingBg1")
        backgroundImageView.contentMode = .scaleAspectFill
        view.sendSubviewToBack(backgroundImageView)
        view.backgroundColor = AppColor.dynamic(light: AppColor.backgroundsPrimary, dark: AppColor.gray6)
        refreshBackgroundAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: SettingsHealthSyncViewController, _) in
            controller.refreshBackgroundAppearance()
        }
        titleLabel.text = L10n.tr("settings.appleHealthSync")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(
            closeButton,
            systemName: "xmark",
            foregroundColor: AppColor.iconSecondary
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        [statusCard, detailsCard].forEach { card in
            guard let card else { return }
            SettingsSheetChrome.applyListCard(card)
        }
        viewModel.healthAuthorization.bind { [weak self] _ in
            self?.render()
        }
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.reload()
        render()
    }

    private func render() {
        let connected = viewModel.isHealthConnected()
        statusStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        detailsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let status = SettingsRowView()
        status.configure(
            title: connected
                ? L10n.tr("settings.health.connected")
                : L10n.tr("settings.health.disconnected"),
            detail: viewModel.healthSyncDetailText(),
            image: UIImage(named: "AppleHealthIcon"),
            accessory: .none,
            showsSeparator: false
        )
        statusStackView.addArrangedSubview(status)
        if connected {
            detailsTitleLabel.isHidden = false
            detailsTitleHeightConstraint.designConstant = 38
            detailsTitleTopConstraint.designConstant = 16
            detailsTitleLabel.text = L10n.tr("settings.health.received")
            OnboardingStyle.lockFigmaFont(
                detailsTitleLabel,
                size: 15,
                weight: .semibold,
                color: AppColor.labelVibrantPrimary,
                kern: -0.23
            )
            let items = viewModel.healthAuthorization.value.displayedTypes
            items.enumerated().forEach { index, item in
                let row = SettingsRowView()
                row.configure(
                    title: item.kind.title,
                    detail: item.statusTitle,
                    accessory: .disclosure,
                    showsSeparator: index < items.count - 1,
                    separatorColor: AppColor.separatorVibrant
                )
                row.onTap = { [weak self] in
                    self?.onOpenHealth()
                }
                detailsStackView.addArrangedSubview(row)
            }
            OnboardingStyle.styleDestructiveButton(
                actionButton,
                title: L10n.tr("settings.health.disconnect"),
                systemImage: "xmark.circle"
            )
        } else {
            detailsTitleLabel.isHidden = true
            detailsTitleHeightConstraint.designConstant = 0
            detailsTitleTopConstraint.designConstant = 24
            detailsStackView.addArrangedSubview(makeInCardHeader(L10n.tr("settings.health.howToReconnect")))
            let steps = [
                L10n.tr("settings.health.step1"),
                L10n.tr("settings.health.step2"),
                L10n.tr("settings.health.step3")
            ]
            let symbols = ["1.circle", "2.circle", "3.circle"]
            steps.enumerated().forEach { index, title in
                let row = SettingsRowView()
                row.configure(
                    title: title,
                    symbolName: symbols[index],
                    circledIcon: false,
                    accessory: .none,
                    showsSeparator: index < steps.count - 1,
                    separatorColor: AppColor.separatorVibrant
                )
                detailsStackView.addArrangedSubview(row)
            }
            OnboardingStyle.stylePrimaryButton(actionButton, title: L10n.tr("settings.health.connect"))
        }
    }

    private func makeInCardHeader(_ text: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let label = AdaptiveLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        OnboardingStyle.lockFigmaFont(
            label,
            size: 15,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.23
        )
        container.addSubview(label)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: .adaptHeight(38)),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: .adaptWidth(18)),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: .adaptWidth(-16)),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private func refreshBackgroundAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundImageView.image = UIImage(named: isDark ? "SettingsSheetDarkBackground" : "OnboardingBg1")
        backgroundImageView.contentMode = isDark ? .scaleToFill : .scaleAspectFill
    }

    @objc
    private func actionTapped() {
        if viewModel.isHealthConnected() {
            viewModel.disconnectHealth()
            render()
            onOpenHealth()
        } else {
            onOpenHealth()
        }
    }

    @objc
    private func closeTapped() {
        dismiss(animated: true)
    }
}
