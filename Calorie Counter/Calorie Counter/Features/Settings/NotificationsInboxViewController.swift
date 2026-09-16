import UIKit

final class NotificationsInboxViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var emptySection: EmptyScreenView!

    @IBOutlet private weak var headerTop: NSLayoutConstraint!
    @IBOutlet private weak var tableTop: AdaptiveConstraint!
    private let settingsPresentation: Bool

    private let viewModel: NotificationsInboxViewModel
    private var sections: [NotificationInboxSection] = []
    private let allowRow = SettingsRowView()

    init(viewModel: NotificationsInboxViewModel, settingsPresentation: Bool = false) {
        self.settingsPresentation = settingsPresentation
        self.viewModel = viewModel
        super.init(nibName: "NotificationsInboxViewController")
        hidesBottomBarWhenPushed = true
        if settingsPresentation {
            modalPresentationStyle = .pageSheet
            sheetPresentationController?.detents = [.large()]
            sheetPresentationController?.prefersGrabberVisible = true
            sheetPresentationController?.preferredCornerRadius = 38
        }
    }

    override var analyticsScreen: AnalyticsScreen? { .notifications }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = settingsPresentation ? AppColor.backgroundsPrimary : AppColor.gray6
        if settingsPresentation, let wrapper = backButton.superview {
            headerTop.isActive = false
            wrapper.topAnchor.constraint(equalTo: view.topAnchor, constant: .adaptHeight(16)).isActive = true
            tableTop.designConstant = 22
        }
        titleLabel.textAlignment = .center
        OnboardingStyle.styleGlassSymbolButton(
            backButton,
            systemName: settingsPresentation ? "xmark" : "chevron.backward",
            foregroundColor: settingsPresentation ? AppColor.iconSecondary : AppColor.labelVibrantPrimary
        )
        if settingsPresentation {
            var configuration = UIButton.Configuration.filled()
            configuration.image = OnboardingStyle.symbolImage("xmark")
            configuration.baseForegroundColor = AppColor.iconSecondary
            configuration.baseBackgroundColor = AppColor.fillSecondary
            configuration.contentInsets = .zero
            configuration.cornerStyle = .capsule
            backButton.configuration = configuration
        }
        backButton.accessibilityLabel = L10n.tr(settingsPresentation ? "common.done" : "common.back")
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "section")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        tableView.contentInsetAdjustmentBehavior = .never
        if settingsPresentation { tableView.tableHeaderView = makeAllowHeader() }
        emptySection.configure(title: L10n.tr("search.emptyTitle"), subtitle: nil, actionTitle: nil)
        emptySection.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.reload()
    }

    override func bindViewModel() {
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
        viewModel.sections.bind { [weak self] sections in
            self?.sections = sections
            self?.emptySection.isHidden = true
            self?.tableView.isHidden = false
            self?.tableView.reloadData()
        }
        viewModel.allowsNotifications.bind { [weak self] isOn in
            self?.allowRow.configure(
                title: L10n.tr("settings.notifications.allow"),
                accessory: .none,
                showsSeparator: false
            )
            self?.allowRow.configureToggle(isOn: isOn)
        }
        viewModel.onOpenSystemSettings = {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        let size = header.systemLayoutSizeFitting(
            CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        if header.frame.size != CGSize(width: width, height: size.height) {
            header.frame.size = CGSize(width: width, height: size.height)
            tableView.tableHeaderView = header
        }
    }

    private func makeAllowHeader() -> UIView {
        let header = UIView()
        let card = AdaptiveView()
        card.translatesAutoresizingMaskIntoConstraints = false
        SettingsSheetChrome.applyListCard(card, fillColor: AppColor.fillQuaternary)
        allowRow.translatesAutoresizingMaskIntoConstraints = false
        allowRow.onToggleChanged = { [weak self] isOn in
            self?.viewModel.setAllowsNotifications(isOn)
        }
        card.addSubview(allowRow)
        header.addSubview(card)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: .adaptHeight(60)),
            card.topAnchor.constraint(equalTo: header.topAnchor),
            card.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: .adaptWidth(16)),
            card.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: .adaptWidth(-16)),
            card.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: .adaptHeight(-24)),
            allowRow.topAnchor.constraint(equalTo: card.topAnchor, constant: .adaptHeight(4)),
            allowRow.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            allowRow.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            allowRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: .adaptHeight(-4))
        ])
        return header
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "section", for: indexPath)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        let section = NotificationSectionView()
        section.translatesAutoresizingMaskIntoConstraints = false
        section.configure(sections[indexPath.row], settingsStyle: settingsPresentation)
        section.onDismiss = { [weak self] id in
            self?.viewModel.dismiss(id: id)
        }
        cell.contentView.addSubview(section)
        NSLayoutConstraint.activate([
            section.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            section.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            section.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            section.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor)
        ])
        return cell
    }

    @objc
    private func backTapped() {
        if navigationController?.viewControllers.first !== self, navigationController != nil {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
