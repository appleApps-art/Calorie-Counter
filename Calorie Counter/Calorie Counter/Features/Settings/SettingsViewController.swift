import UIKit

final class SettingsViewController: BaseViewController {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var sectionsStackView: UIStackView!

    var onOpenNotifications: (() -> Void)?
    var onOpenSubscription: (() -> Void)?
    var onOpenNutritionGoals: (() -> Void)?
    var onOpenWeightGoal: (() -> Void)?
    var onOpenTheme: (() -> Void)?
    var onOpenHealth: (() -> Void)?
    var onShareApp: (() -> Void)?
    var onOpenPrivacy: (() -> Void)?
    var onOpenTerms: (() -> Void)?
    var onOpenHelp: (() -> Void)?
    var onCopyUserID: (() -> Void)?

    private let viewModel: SettingsViewModel
    private var hasRefreshedSubscription = false
    private var renderedSectionsState: SectionsState?

    private struct SectionsState: Equatable {
        let nutritionGoal: String
        let weightGoal: String
        let theme: String
        let healthStatus: String
        let userID: String
        let usesMetric: Bool
        let showsUpgrade: Bool
        let showsShareApp: Bool
    }

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "SettingsViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .settings }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.dynamic(light: AppColor.gray6, dark: AppColor.backgroundsPrimary)
        titleLabel.textAlignment = .center
        OnboardingStyle.styleGlassSymbolButton(
            backButton,
            systemName: "chevron.backward",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasRefreshedSubscription else { return }
        hasRefreshedSubscription = true
        viewModel.refreshSubscription()
    }

    override func viewWillLayoutSubviews() {
        // Observable publications are synchronous. Build once from their final
        // values before layout, rather than rebuilding for every changed field.
        renderSectionsIfNeeded()
        super.viewWillLayoutSubviews()
    }

    override func bindViewModel() {
        viewModel.nutritionGoalError.bind { [weak self] message in
            guard let self, !message.isEmpty else { return }
            let alert = UIAlertController(title: L10n.tr("settings.nutritionGoals"), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("common.done"), style: .default))
            self.present(alert, animated: true)
        }
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
            OnboardingStyle.lockFigmaFont(
                self?.titleLabel,
                size: 17,
                weight: .semibold,
                color: AppColor.labelVibrantPrimary,
                kern: -0.43
            )
        }
        viewModel.healthStatusText.bind { [weak self] _ in
            self?.view.setNeedsLayout()
        }
        viewModel.nutritionGoalText.bind { [weak self] _ in
            self?.view.setNeedsLayout()
        }
        viewModel.weightGoalText.bind { [weak self] _ in
            self?.view.setNeedsLayout()
        }
        viewModel.themeText.bind { [weak self] _ in
            self?.view.setNeedsLayout()
        }
        viewModel.userIDText.bind { [weak self] _ in
            self?.view.setNeedsLayout()
        }
        viewModel.usesMetric.bind { [weak self] _ in
            self?.view.setNeedsLayout()
        }
        viewModel.showsUpgrade.bind { [weak self] _ in
            self?.view.setNeedsLayout()
        }
        viewModel.showsShareApp.bind { [weak self] _ in
            self?.view.setNeedsLayout()
        }
    }

    private func renderSectionsIfNeeded() {
        let state = SectionsState(
            nutritionGoal: viewModel.nutritionGoalText.value,
            weightGoal: viewModel.weightGoalText.value,
            theme: viewModel.themeText.value,
            healthStatus: viewModel.healthStatusText.value,
            userID: viewModel.userIDText.value,
            usesMetric: viewModel.usesMetric.value,
            showsUpgrade: viewModel.showsUpgrade.value,
            showsShareApp: viewModel.showsShareApp.value
        )
        guard state != renderedSectionsState else { return }
        renderedSectionsState = state

        sectionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if viewModel.showsUpgrade.value {
            sectionsStackView.addArrangedSubview(
                makeSection(title: L10n.tr("settings.section.subscription"), rows: [
                    row(
                        title: L10n.tr("settings.upgradeToPro"),
                        symbolName: "star.circle",
                        action: { [weak self] in self?.onOpenSubscription?() }
                    )
                ])
            )
        }
        sectionsStackView.addArrangedSubview(
            makeSection(title: L10n.tr("settings.section.goals"), rows: [
                row(
                    title: L10n.tr("settings.nutritionGoals"),
                    detail: viewModel.nutritionGoalText.value,
                    symbolName: "fork.knife.circle",
                    action: { [weak self] in self?.onOpenNutritionGoals?() }
                ),
                row(
                    title: L10n.tr("settings.weightGoal"),
                    detail: viewModel.weightGoalText.value,
                    symbolName: "target",
                    action: { [weak self] in self?.onOpenWeightGoal?() }
                )
            ])
        )
        sectionsStackView.addArrangedSubview(
            makeSection(title: L10n.tr("settings.section.preferences"), rows: [
                unitsRow(),
                row(
                    title: L10n.tr("settings.theme"),
                    detail: viewModel.themeText.value,
                    symbolName: "moon.circle",
                    action: { [weak self] in self?.onOpenTheme?() }
                ),
                row(
                    title: L10n.tr("notifications.title"),
                    symbolName: "bell.circle",
                    action: { [weak self] in self?.onOpenNotifications?() }
                )
            ])
        )
        var general: [SettingsRowView] = [
            copyRow(),
            row(
                title: L10n.tr("settings.appleHealthSync"),
                detail: viewModel.healthStatusText.value,
                symbolName: "arrow.triangle.2.circlepath.circle",
                action: { [weak self] in self?.onOpenHealth?() }
            )
        ]
        if viewModel.showsShareApp.value {
            general.append(
                row(
                    title: L10n.tr("settings.shareApp"),
                    symbolName: "square.and.arrow.up.circle",
                    action: { [weak self] in self?.onShareApp?() }
                )
            )
        }
        general.append(contentsOf: [
            row(
                title: L10n.tr("settings.privacyPolicy"),
                symbolName: "lock.shield",
                action: { [weak self] in self?.onOpenPrivacy?() }
            ),
            row(
                title: L10n.tr("settings.termsOfService"),
                symbolName: "doc.text",
                action: { [weak self] in self?.onOpenTerms?() }
            ),
            row(
                title: L10n.tr("settings.helpSupport"),
                symbolName: "info.circle",
                action: { [weak self] in self?.onOpenHelp?() }
            )
        ])
        sectionsStackView.addArrangedSubview(
            makeSection(title: L10n.tr("settings.section.general"), rows: general)
        )
    }

    private func makeSection(title: String, rows: [SettingsRowView]) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let header = AdaptiveLabel()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.text = title
        OnboardingStyle.lockFigmaFont(
            header,
            size: 15,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.23
        )
        let card = AdaptiveView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.cardFillColor = AppColor.backgroundsPrimaryElevated
        card.adaptCornerRadius = true
        card.designCornerRadius = 24
        card.applyCardShadow = true
        card.showsDropShadow = true
        card.designShadowRadius = 4
        card.cardShadowOpacity = 0.1
        card.useLiveGlass = false
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        rows.enumerated().forEach { index, row in
            row.useSingleLineLayout()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.setShowsSeparator(index < rows.count - 1)
            stack.addArrangedSubview(row)
        }
        card.addSubview(stack)
        container.addSubview(header)
        container.addSubview(card)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: .adaptWidth(2)),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: .adaptHeight(38)),
            card.topAnchor.constraint(equalTo: header.bottomAnchor, constant: .adaptHeight(4)),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: .adaptHeight(4)),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: .adaptHeight(-4))
        ])
        return container
    }

    private func row(
        title: String,
        detail: String = "",
        symbolName: String,
        action: @escaping () -> Void
    ) -> SettingsRowView {
        let row = SettingsRowView()
        row.configure(
            title: title,
            detail: detail,
            symbolName: symbolName,
            accessory: .disclosure,
            showsSeparator: true,
            iconColor: AppColor.dynamic(light: AppColor.labelsPrimary, dark: AppColor.iconSecondary)
        )
        row.onTap = action
        return row
    }

    private func unitsRow() -> SettingsRowView {
        let row = SettingsRowView()
        row.configure(
            title: L10n.tr("settings.units"),
            symbolName: "gauge.with.dots.needle.67percent",
            accessory: .none,
            showsSeparator: true,
            iconColor: AppColor.dynamic(light: AppColor.labelsPrimary, dark: AppColor.iconSecondary)
        )
        row.configureUnits(isMetric: viewModel.usesMetric.value)
        row.onUnitsChanged = { [weak self] isMetric in
            self?.viewModel.setUsesMetric(isMetric)
        }
        return row
    }

    private func copyRow() -> SettingsRowView {
        let row = SettingsRowView()
        row.configure(
            title: L10n.tr("settings.userID"),
            detail: viewModel.userIDText.value,
            symbolName: "person.circle",
            accessory: .copy,
            showsSeparator: true,
            iconColor: AppColor.dynamic(light: AppColor.labelsPrimary, dark: AppColor.iconSecondary)
        )
        row.onCopy = { [weak self] in
            self?.onCopyUserID?()
        }
        return row
    }

    @objc
    private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
}
