import UIKit

final class MyPantryViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var selectButton: UIButton!
    @IBOutlet private weak var selectAllButton: UIButton!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var emptySection: EmptyScreenView!
    @IBOutlet private weak var suggestionSection: UIView!
    @IBOutlet private weak var suggestionCard: AdaptiveView!
    @IBOutlet private weak var suggestionTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var suggestionRecipeLabel: AdaptiveLabel!
    @IBOutlet private weak var suggestionSubtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var suggestionImageView: UIImageView!
    @IBOutlet private weak var suggestionChevron: UIImageView!
    @IBOutlet private weak var listCard: AdaptiveView!
    @IBOutlet private weak var listCardHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var selectBar: UIView!
    @IBOutlet private weak var closeSelectButton: UIButton!
    @IBOutlet private weak var deleteButton: UIButton!

    private let footerBlurContainer = UIView()
    private let footerBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let footerBlurMask = CAGradientLayer()
    private let footerGradientView = UIView()
    private let footerFadeGradient = CAGradientLayer()
    private let viewModel: MyPantryViewModel

    init(viewModel: MyPantryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "MyPantryViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .myPantry }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.dynamic(light: AppColor.canvas, dark: AppColor.backgroundsPrimary)
        configureEmpty()
        configureChrome()
        suggestionSubtitleLabel.text = L10n.tr("pantry.cookWithIngredients")
        applySectionHeader(suggestionTitleLabel, symbol: "sparkles", title: L10n.tr("pantry.aiSuggestion"))
        OnboardingStyle.lockFigmaFont(
            suggestionRecipeLabel,
            size: 15,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.23
        )
        OnboardingStyle.lockFigmaFont(
            suggestionSubtitleLabel,
            size: 12,
            weight: .medium,
            color: AppColor.iconSecondary
        )
        suggestionRecipeLabel.applyLineTruncation(lines: 1)
        suggestionSubtitleLabel.applyLineTruncation(lines: 1)
        suggestionImageView.clipsToBounds = true
        suggestionImageView.layer.cornerCurve = .continuous
        suggestionImageView.layer.cornerRadius = .adaptWidth(12)
        suggestionImageView.backgroundColor = AppColor.fillVibrantTertiary
        suggestionChevron.image = OnboardingStyle.symbol("chevron.right", pointSize: 17, weight: .medium)
        suggestionChevron.tintColor = AppColor.iconSecondary
        suggestionCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(suggestionTapped)))
        styleCard(suggestionCard)
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
        configureSelectFooter()
        OnboardingStyle.styleGlassSymbolButton(closeSelectButton, systemName: "xmark")
        OnboardingStyle.styleGlassSymbolButton(
            deleteButton,
            systemName: "trash",
            foregroundColor: AppColor.accentRed
        )
        closeSelectButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteSelectedTapped), for: .touchUpInside)
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let radius = listCard.layer.cornerRadius
        if tableView.layer.cornerRadius != radius {
            tableView.layer.cornerCurve = .continuous
            tableView.layer.cornerRadius = radius
        }
        updateListCardHeight()
        layoutSelectFooter()
    }

    override func bindViewModel() {
        viewModel.items.bind { [weak self] _ in
            self?.refreshChrome()
            self?.tableView.reloadData()
            self?.view.setNeedsLayout()
        }
        viewModel.suggestion.bind { [weak self] recipe in
            self?.suggestionSection.isHidden = recipe == nil
            self?.suggestionRecipeLabel.text = recipe?.title
            OnboardingStyle.lockFigmaFont(
                self?.suggestionRecipeLabel,
                size: 15,
                weight: .semibold,
                color: AppColor.labelVibrantPrimary,
                kern: -0.23
            )
            RemoteImageLoader.shared.display(recipe?.imageURL, in: self?.suggestionImageView ?? UIImageView(), placeholder: nil)
            self?.view.setNeedsLayout()
        }
        viewModel.isSelecting.bind { [weak self] _ in
            self?.refreshChrome()
            self?.tableView.reloadData()
            self?.view.setNeedsLayout()
        }
        viewModel.selectedIDs.bind { [weak self] _ in
            self?.refreshChrome()
            self?.tableView.reloadData()
        }
        viewModel.showsDeleteAlert.bind { [weak self] visible in
            self?.updateDeleteAlert(visible: visible)
        }
    }

    @objc private func backTapped() { viewModel.backTapped() }
    @objc private func addTapped() { viewModel.addTapped() }
    @objc private func selectTapped() { viewModel.selectModeTapped() }
    @objc private func selectAllTapped() { viewModel.selectAllTapped() }
    @objc private func suggestionTapped() { viewModel.suggestionTapped() }
    @objc private func deleteSelectedTapped() { viewModel.deleteSelectedTapped() }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
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
                self?.viewModel.itemTapped(item)
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
            self?.viewModel.deleteTapped(item)
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
        OnboardingStyle.styleGlassSymbolButton(
            addButton,
            systemName: "plus",
            foregroundColor: AppColor.tabSelected
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
        refreshChrome()
    }

    private func refreshChrome() {
        titleLabel.text = viewModel.navTitle
        titleLabel.contentMode = .left
        titleLabel.textAlignment = .left
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        titleLabel.textAlignment = .left
        titleLabel.applyLineTruncation(lines: 1)
        updateNavTextButton(selectButton, title: L10n.tr("pantry.select"))
        updateNavTextButton(selectAllButton, title: viewModel.selectAllButtonTitle)
        let selecting = viewModel.isSelecting.value
        let isEmpty = viewModel.items.value.isEmpty
        contentStack.isHidden = isEmpty
        emptySection.isHidden = !isEmpty
        selectButton.isHidden = selecting || isEmpty
        selectButton.setContentHuggingPriority((selecting || isEmpty) ? .defaultLow : .required, for: .horizontal)
        selectButton.setContentCompressionResistancePriority((selecting || isEmpty) ? .fittingSizeLevel : .required, for: .horizontal)
        addButton.isHidden = selecting
        addButton.superview?.isHidden = selecting
        selectAllButton.isHidden = !selecting
        selectBar.isHidden = !selecting
    }

    private func configureEmpty() {
        emptySection.clipsToBounds = false
        emptySection.setContentTopInset(100)
        emptySection.setMessageWidth(230)
        emptySection.setActionBottomInset(24)
        emptySection.configure(
            title: L10n.tr("pantry.emptyTitle"),
            subtitle: L10n.tr("pantry.emptySubtitle"),
            actionTitle: L10n.tr("recipes.createRecipe"),
            systemImage: "wand.and.sparkles",
            illustrationName: "emptyImagePantry"
        )
        emptySection.onAction = { [weak self] in
            self?.viewModel.createRecipeTapped()
        }
    }

    private func configureSelectFooter() {
        selectBar.backgroundColor = .clear
        selectBar.clipsToBounds = false
        selectBar.isUserInteractionEnabled = true
        footerBlurContainer.isUserInteractionEnabled = false
        footerBlurContainer.backgroundColor = .clear
        footerBlurView.isUserInteractionEnabled = false
        footerGradientView.isUserInteractionEnabled = false
        footerGradientView.backgroundColor = .clear
        if footerBlurView.superview !== footerBlurContainer {
            footerBlurContainer.addSubview(footerBlurView)
        }
        if footerBlurContainer.superview !== selectBar {
            selectBar.insertSubview(footerBlurContainer, at: 0)
        }
        if footerGradientView.superview !== selectBar {
            selectBar.insertSubview(footerGradientView, aboveSubview: footerBlurContainer)
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
        selectBar.bringSubviewToFront(closeSelectButton)
        selectBar.bringSubviewToFront(deleteButton)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: MyPantryViewController, _) in
            view.refreshSelectFooterColors()
        }
        refreshSelectFooterColors()
    }

    private func layoutSelectFooter() {
        guard selectBar.bounds.width > 0 else { return }
        footerBlurContainer.frame = selectBar.bounds
        footerBlurView.frame = footerBlurContainer.bounds
        footerGradientView.frame = selectBar.bounds
        footerFadeGradient.frame = footerGradientView.bounds
        footerBlurMask.frame = footerBlurContainer.bounds
        refreshSelectFooterColors()
    }

    private func refreshSelectFooterColors() {
        footerFadeGradient.colors = AppColor.fadeColors(
            from: AppColor.backgroundsPrimary,
            traits: traitCollection
        )
    }

    private func updateDeleteAlert(visible: Bool) {
        guard visible else { return }
        presentDeleteAlertIfNeeded()
    }

    private func presentDeleteAlertIfNeeded() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: L10n.format("pantry.deleteTitle", viewModel.selectedIDs.value.count),
            message: L10n.tr("pantry.deleteMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("pantry.cancel"), style: .cancel) { [weak self] _ in
            self?.viewModel.cancelDelete()
        })
        alert.addAction(UIAlertAction(title: L10n.tr("pantry.delete"), style: .destructive) { [weak self] _ in
            self?.viewModel.confirmDelete()
        })
        present(alert, animated: true)
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
        } else {
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
            button.titleLabel?.lineBreakMode = .byClipping
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
        card.applyCardShadow = true
        card.adaptCornerRadius = true
        card.designCornerRadius = 24
        card.cardFillColor = AppColor.backgroundsPrimaryElevated
    }

    private func applySectionHeader(_ label: AdaptiveLabel?, symbol: String, title: String) {
        guard let label else { return }
        let image = OnboardingStyle.symbol(symbol, pointSize: 15, weight: .semibold)
        let text = NSMutableAttributedString()
        if let image {
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(AppColor.labelVibrantPrimary, renderingMode: .alwaysOriginal)
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: " "))
        }
        text.append(NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: AppColor.labelVibrantPrimary,
                .kern: -0.23
            ]
        ))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        text.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: 0, length: text.length)
        )
        label.attributedText = text
        label.adaptFontSize = false
        label.textAlignment = .center
    }

    private func updateListCardHeight() {
        let rowHeight = CGFloat.adaptHeight(64)
        let count = CGFloat(viewModel.items.value.count)
        listCard.isHidden = count == 0
        guard count > 0 else { return }
        let bottomInset: CGFloat = .adaptHeight(16)
        let maxY = view.safeAreaLayoutGuide.layoutFrame.maxY - bottomInset
        let minY = listCard.convert(listCard.bounds.origin, to: view).y
        let available = max(rowHeight, maxY - minY)
        let next = min(count * rowHeight, available)
        if abs(listCardHeightConstraint.constant - next) > 0.5 {
            listCardHeightConstraint.constant = next
        }
        tableView.isScrollEnabled = count * rowHeight > available + 1
    }
}
