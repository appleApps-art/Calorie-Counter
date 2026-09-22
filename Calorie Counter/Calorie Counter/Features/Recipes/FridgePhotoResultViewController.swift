import UIKit

final class FridgePhotoResultViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var selectButton: UIButton!
    @IBOutlet private weak var selectAllButton: UIButton!
    @IBOutlet private weak var listCard: AdaptiveView!
    @IBOutlet private weak var listCardHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var footerHost: UIView!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var selectBar: UIView!
    @IBOutlet private weak var closeSelectButton: UIButton!
    @IBOutlet private weak var deleteButton: UIButton!

    private let footerBlurContainer = UIView()
    private let footerBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let footerBlurMask = CAGradientLayer()
    private let footerGradientView = UIView()
    private let footerFadeGradient = CAGradientLayer()
    private let viewModel: FridgePhotoResultViewModel

    init(viewModel: FridgePhotoResultViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "FridgePhotoResultViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .fridgePhotoResult }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.backgroundsPrimary
        configureChrome()
        styleCard(listCard)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = .adaptHeight(64)
        tableView.estimatedRowHeight = .adaptHeight(64)
        tableView.clipsToBounds = true
        configureFooter()
        OnboardingStyle.styleGlassSymbolButton(closeSelectButton, systemName: "xmark")
        OnboardingStyle.styleGlassSymbolButton(
            deleteButton,
            systemName: "trash",
            foregroundColor: AppColor.accentRed
        )
        closeSelectButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteSelectedTapped), for: .touchUpInside)
        refreshChrome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let radius = listCard.layer.cornerRadius
        if tableView.layer.cornerRadius != radius {
            tableView.layer.cornerCurve = .continuous
            tableView.layer.cornerRadius = radius
        }
        updateListCardHeight()
        layoutFooter()
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] _ in
            self?.refreshChrome()
        }
        viewModel.items.bind { [weak self] _ in
            self?.tableView.reloadData()
            self?.refreshChrome()
            self?.view.setNeedsLayout()
        }
        viewModel.isSelecting.bind { [weak self] _ in
            self?.tableView.reloadData()
            self?.refreshChrome()
            self?.view.setNeedsLayout()
        }
        viewModel.selectedIDs.bind { [weak self] _ in
            self?.tableView.reloadData()
            self?.refreshChrome()
        }
    }

    @objc private func backTapped() { viewModel.backTapped() }
    @objc private func addTapped() { viewModel.addTapped() }
    @objc private func selectTapped() { viewModel.selectTapped() }
    @objc private func selectAllTapped() { viewModel.selectAllTapped() }
    @objc private func deleteSelectedTapped() { viewModel.deleteSelectedTapped() }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        let item = viewModel.items.value[indexPath.row]
        let row = PantryItemRowView()
        row.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
        ])
        row.configure(
            item,
            selecting: viewModel.isSelecting.value,
            selected: viewModel.selectedIDs.value.contains(item.id),
            showsSeparator: indexPath.row < viewModel.items.value.count - 1
        )
        row.onAccessory = { [weak self] in
            if self?.viewModel.isSelecting.value == true {
                self?.viewModel.toggleItem(item.id)
            } else {
                self?.viewModel.editTapped(item)
            }
        }
        row.onSelect = { [weak self] in
            if self?.viewModel.isSelecting.value == true {
                self?.viewModel.toggleItem(item.id)
            } else {
                self?.viewModel.editTapped(item)
            }
        }
        return cell
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard !viewModel.isSelecting.value else { return nil }
        let item = viewModel.items.value[indexPath.row]
        let action = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, done in
            self?.viewModel.delete(item)
            done(true)
        }
        action.image = UIImage(systemName: "trash")
        action.backgroundColor = AppColor.accentRed
        return UISwipeActionsConfiguration(actions: [action])
    }

    private func configureChrome() {
        OnboardingStyle.styleGlassSymbolButton(
            backButton,
            systemName: "chevron.backward",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        selectButton.addTarget(self, action: #selector(selectTapped), for: .touchUpInside)
        selectAllButton.addTarget(self, action: #selector(selectAllTapped), for: .touchUpInside)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        selectButton.setContentHuggingPriority(.required, for: .horizontal)
        selectButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        selectAllButton.setContentHuggingPriority(.required, for: .horizontal)
        selectAllButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        styleNavTextButton(selectButton, title: L10n.tr("pantry.select"))
        styleNavTextButton(selectAllButton, title: viewModel.selectAllButtonTitle)
    }

    private func refreshChrome() {
        titleLabel.text = viewModel.titleText.value
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        titleLabel.textAlignment = .natural
        titleLabel.applyLineTruncation(lines: 1)
        updateNavTextButton(selectButton, title: L10n.tr("pantry.select"))
        updateNavTextButton(selectAllButton, title: viewModel.selectAllButtonTitle)
        OnboardingStyle.stylePrimaryButton(addButton, title: viewModel.addTitle)
        let selecting = viewModel.isSelecting.value
        selectButton.isHidden = selecting
        selectAllButton.isHidden = !selecting
        addButton.isHidden = selecting
        selectBar.isHidden = !selecting
        deleteButton.isEnabled = !viewModel.selectedIDs.value.isEmpty
        deleteButton.alpha = viewModel.selectedIDs.value.isEmpty ? 0.4 : 1
        tableView.contentInset.bottom = 0
        tableView.verticalScrollIndicatorInsets.bottom = 0
        view.setNeedsLayout()
    }

    private func configureFooter() {
        footerHost.backgroundColor = .clear
        footerHost.clipsToBounds = false
        footerBlurContainer.isUserInteractionEnabled = false
        footerBlurContainer.backgroundColor = .clear
        footerBlurView.isUserInteractionEnabled = false
        footerGradientView.isUserInteractionEnabled = false
        footerGradientView.backgroundColor = .clear
        if footerBlurView.superview !== footerBlurContainer {
            footerBlurContainer.addSubview(footerBlurView)
        }
        if footerBlurContainer.superview !== footerHost {
            footerHost.insertSubview(footerBlurContainer, at: 0)
        }
        if footerGradientView.superview !== footerHost {
            footerHost.insertSubview(footerGradientView, aboveSubview: footerBlurContainer)
        }
        footerBlurMask.startPoint = CGPoint(x: 0.5, y: 1)
        footerBlurMask.endPoint = CGPoint(x: 0.5, y: 0)
        footerBlurMask.colors = [
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(0.45).cgColor,
            UIColor.clear.cgColor
        ]
        footerBlurMask.locations = [0, 0.5, 1]
        footerBlurContainer.layer.mask = footerBlurMask
        footerFadeGradient.startPoint = CGPoint(x: 0.5, y: 1)
        footerFadeGradient.endPoint = CGPoint(x: 0.5, y: 0)
        footerFadeGradient.locations = [0, 0.5, 1]
        if footerFadeGradient.superlayer !== footerGradientView.layer {
            footerGradientView.layer.addSublayer(footerFadeGradient)
        }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: FridgePhotoResultViewController, _) in
            view.refreshFooterColors()
        }
        refreshFooterColors()
    }

    private func layoutFooter() {
        guard footerHost.bounds.width > 0 else { return }
        footerBlurContainer.frame = footerHost.bounds
        footerBlurView.frame = footerBlurContainer.bounds
        footerGradientView.frame = footerHost.bounds
        footerFadeGradient.frame = footerGradientView.bounds
        footerBlurMask.frame = footerBlurContainer.bounds
        refreshFooterColors()
        footerHost.bringSubviewToFront(addButton)
        footerHost.bringSubviewToFront(selectBar)
    }

    private func refreshFooterColors() {
        footerFadeGradient.colors = AppColor.fadeColors(
            from: AppColor.backgroundsPrimary,
            traits: traitCollection
        )
    }

    private func styleNavTextButton(_ button: UIButton, title: String) {
        OnboardingStyle.styleGlassButton(
            button,
            title: title,
            foregroundColor: AppColor.labelsPrimary,
            weight: .regular
        )
        if var config = button.configuration {
            config.buttonSize = .medium
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 15, weight: .regular)
                outgoing.kern = -0.23
                return outgoing
            }
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            config.titleLineBreakMode = .byClipping
            button.configuration = config
        }
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func updateNavTextButton(_ button: UIButton, title: String) {
        if var config = button.configuration {
            config.title = title
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
        }
    }

    private func styleCard(_ card: AdaptiveView) {
        card.useLiveGlass = false
        card.applyCardShadow = false
        card.adaptCornerRadius = true
        card.designCornerRadius = 24
        card.backgroundColor = AppColor.gray6
        card.clipsToBounds = true
    }

    private func updateListCardHeight() {
        let rowHeight = CGFloat.adaptHeight(64)
        let count = CGFloat(viewModel.items.value.count)
        listCard.isHidden = count == 0
        guard count > 0 else { return }
        let maxY = footerHost.convert(footerHost.bounds.origin, to: view).y - .adaptHeight(24)
        let minY = listCard.convert(listCard.bounds.origin, to: view).y
        let available = max(rowHeight, maxY - minY)
        let next = min(count * rowHeight, available)
        if abs(listCardHeightConstraint.constant - next) > 0.5 {
            listCardHeightConstraint.constant = next
        }
        tableView.isScrollEnabled = count * rowHeight > available + 1
    }
}
