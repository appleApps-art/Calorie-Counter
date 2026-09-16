import UIKit

final class ChatHistoryViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var searchField: AdaptiveView!
    @IBOutlet private weak var searchIconButton: UIButton!
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var micButton: UIButton!
    @IBOutlet private weak var clearSearchButton: UIButton!
    @IBOutlet private weak var chipsScrollView: UIScrollView!
    @IBOutlet private weak var allChip: UIButton!
    @IBOutlet private weak var nutritionChip: UIButton!
    @IBOutlet private weak var mealsChip: UIButton!
    @IBOutlet private weak var swapsChip: UIButton!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var emptySection: EmptyScreenView!
    @IBOutlet private weak var clearAllButton: UIButton!

    var onSelectConversation: ((UUID) -> Void)?

    private let viewModel: ChatHistoryViewModel
    private var sections: [ChatHistorySection] = []
    private let micChrome = VoiceMicButtonChrome()

    init(viewModel: ChatHistoryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "ChatHistoryViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .aiChatHistory }

    override func viewDidLoad() {
        configureHeader()
        configureSearch()
        configureChips()
        configureTable()
        configureClearAll()
        super.viewDidLoad()
        view.backgroundColor = AppColor.gray6
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        clearSearchButton.addTarget(self, action: #selector(clearSearchTapped), for: .touchUpInside)
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        micButton.controlHaptic = .medium
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        allChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        nutritionChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        mealsChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        swapsChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        allChip.tag = -1
        nutritionChip.tag = AIChatCategory.nutrition.rawValue
        mealsChip.tag = AIChatCategory.meals.rawValue
        swapsChip.tag = AIChatCategory.swaps.rawValue
        clearAllButton.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentHistoryErrorIfNeeded()
    }

    private func presentHistoryErrorIfNeeded() {
        guard viewIfLoaded?.window != nil, presentedViewController == nil,
              let message = viewModel.errorMessage.value else { return }
        viewModel.errorMessage.value = nil
        let alert = UIAlertController(title: L10n.tr("ai.history.errorTitle"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.close"), style: .cancel))
        present(alert, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopDictation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyChipsFade()
        micChrome.layoutIfNeeded()
    }

    override func bindViewModel() {
        viewModel.errorMessage.bind { [weak self] _ in
            self?.presentHistoryErrorIfNeeded()
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
        viewModel.searchText.bind { [weak self] value in
            guard self?.searchTextField.text != value else { return }
            self?.searchTextField.text = value
        }
        viewModel.isRecording.bind { [weak self] _ in
            self?.applyMic()
        }
        viewModel.canConfirmVoice.bind { [weak self] _ in
            self?.applyMic()
        }
        viewModel.selectedFilter.bind { [weak self] _ in
            self?.refreshChips()
        }
        viewModel.sections.bind { [weak self] sections in
            self?.sections = sections
            self?.tableView.reloadData()
            self?.applyEmptyState()
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === chipsScrollView else { return }
        applyChipsFade()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "section", for: indexPath)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.clipsToBounds = false
        cell.contentView.clipsToBounds = false
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        let section = ChatHistorySectionView()
        section.translatesAutoresizingMaskIntoConstraints = false
        section.configure(sections[indexPath.row])
        section.onSelect = { [weak self] row in
            self?.onSelectConversation?(row.id)
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

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @objc
    private func backTapped() {
        view.endEditing(true)
        navigationController?.popViewController(animated: true)
    }

    @objc
    private func clearSearchTapped() {
        viewModel.clearSearch()
        view.endEditing(true)
    }

    @objc
    private func micTapped() {
        viewModel.toggleVoiceTapped()
    }

    private func applyMic() {
        micChrome.apply(
            isRecording: viewModel.isRecording.value,
            canConfirm: viewModel.canConfirmVoice.value
        )
    }

    @objc
    private func searchChanged() {
        viewModel.updateSearch(searchTextField.text ?? "")
    }

    @objc
    private func chipTapped(_ sender: UIButton) {
        if sender.tag < 0 {
            viewModel.selectFilter(.all)
        } else if let category = AIChatCategory(rawValue: sender.tag) {
            viewModel.selectFilter(.category(category))
        }
    }

    @objc
    private func clearAllTapped() {
        let alert = UIAlertController(
            title: L10n.tr("ai.history.clearTitle"),
            message: L10n.tr("ai.history.clearMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.tr("common.confirm"), style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true) { [weak self] in
                self?.viewModel.deleteAll()
            }
        })
        present(alert, animated: true)
    }

    @objc
    private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func configureHeader() {
        titleLabel.textAlignment = .center
        OnboardingStyle.styleGlassSymbolButton(
            backButton,
            systemName: "chevron.backward",
            foregroundColor: AppColor.labelVibrantPrimary
        )
    }

    private func configureSearch() {
        searchField.useLiveGlass = true
        searchField.applyButtonGlass = true
        searchField.applyCardShadow = true
        searchField.showsDropShadow = true
        searchTextField.borderStyle = .none
        searchTextField.backgroundColor = .clear
        searchTextField.font = .systemFont(ofSize: 17, weight: .medium)
        searchTextField.textColor = AppColor.labelVibrantPrimary
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: L10n.tr("ai.history.search"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: AppColor.footerLabel
            ]
        )
        searchTextField.returnKeyType = .search
        OnboardingStyle.stylePlainSymbolButton(
            searchIconButton,
            systemName: "magnifyingglass",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        micChrome.attach(micButton)
        applyMic()
        OnboardingStyle.styleGlassSymbolButton(
            clearSearchButton,
            systemName: "xmark",
            foregroundColor: AppColor.labelVibrantPrimary
        )
    }

    private func configureChips() {
        OnboardingStyle.configureChatChipsCarousel(chipsScrollView)
        chipsScrollView.delegate = self
        refreshChips()
    }

    private func configureTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .interactive
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "section")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        emptySection.configure(title: L10n.tr("search.emptyTitle"), subtitle: nil, actionTitle: nil)
        emptySection.isHidden = true
    }

    private func configureClearAll() {
        OnboardingStyle.styleGlassButton(
            clearAllButton,
            title: L10n.tr("ai.history.clear"),
            foregroundColor: AppColor.accentRed,
            weight: .regular
        )
        clearAllButton.controlHaptic = .warning
    }

    private func refreshChips() {
        let selected = viewModel.selectedFilter.value
        OnboardingStyle.styleChatCategoryChip(
            allChip,
            emoji: "",
            title: L10n.tr("ai.history.filter.all"),
            selected: selected == .all
        )
        zip(
            [nutritionChip, mealsChip, swapsChip],
            AIChatCategory.allCases
        ).forEach { button, category in
            guard let button else { return }
            let isSelected: Bool
            if case .category(let current) = selected {
                isSelected = current == category
            } else {
                isSelected = false
            }
            OnboardingStyle.styleChatCategoryChip(
                button,
                emoji: category.emoji,
                title: L10n.tr(category.titleKey),
                selected: isSelected
            )
        }
    }

    private func applyEmptyState() {
        let isEmpty = sections.isEmpty
        emptySection.isHidden = !isEmpty
        tableView.isHidden = isEmpty
        clearAllButton.isHidden = !viewModel.hasHistory
        emptySection.configure(
            title: L10n.tr(viewModel.hasHistory ? "search.emptyTitle" : "ai.history.empty"),
            subtitle: nil, actionTitle: nil
        )
    }

    private func applyChipsFade() {
        OnboardingStyle.applyChatChipsEdgeFade(to: chipsScrollView)
    }
}
