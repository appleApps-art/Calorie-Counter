import PhotosUI
import UniformTypeIdentifiers
import UIKit

final class AIAssistantViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var historyButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var chipsScrollView: UIScrollView!
    @IBOutlet private weak var nutritionChip: UIButton!
    @IBOutlet private weak var mealsChip: UIButton!
    @IBOutlet private weak var swapsChip: UIButton!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var composerFadeView: UIView!
    @IBOutlet private weak var composerField: AdaptiveView!
    @IBOutlet private weak var plusButton: UIButton!
    @IBOutlet private weak var inputField: UITextView!
    @IBOutlet private weak var micButton: UIButton!
    @IBOutlet private weak var sendButton: UIButton!
    @IBOutlet private weak var composerBar: UIView!
    @IBOutlet private weak var composerBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var attachDismissButton: UIButton!
    @IBOutlet private weak var attachMenuView: AIChatAttachMenuView!

    var onHistory: (() -> Void)?
    var onOpenRecipeDetails: ((MealSuggestionOption, MealType) -> Void)?
    var showsHistoryButton = true
    var showsBackButton = true
    var showsNewChatButton = false

    private let viewModel: AIAssistantViewModel
    private var items: [AIChatItem] = []
    private let composerFadeGradient = CAGradientLayer()
    private var appearingMessageIDs = Set<UUID>()
    private let inputPlaceholder = UILabel()
    private var composerHeight: NSLayoutConstraint!
    private var inputHeight: NSLayoutConstraint!

    private let micChrome = VoiceMicButtonChrome()

    init(viewModel: AIAssistantViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "AIAssistantViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .aiAssistant }

    override var keyboardDismissExcludedViews: [UIView] {
        // The background dismissal gesture can move the keyboard-anchored button before
        // it receives touchUpInside. The send action owns keyboard dismissal.
        [sendButton].compactMap { $0 }
    }

    override func viewDidLoad() {
        configureHeader()
        configureChips()
        configureTable()
        configureComposer()
        super.viewDidLoad()
        view.backgroundColor = AppColor.backgroundsPrimary
        inputField.delegate = self
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)
        attachDismissButton.addTarget(self, action: #selector(hideAttachMenu), for: .touchUpInside)
        attachMenuView.onCamera = { [weak self] in
            self?.hideAttachMenu()
            self?.presentCamera()
        }
        attachMenuView.onGallery = { [weak self] in
            self?.hideAttachMenu()
            self?.presentGallery()
        }
        attachMenuView.onFiles = { [weak self] in
            self?.hideAttachMenu()
            self?.presentFiles()
        }
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        micButton.controlHaptic = .medium
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        historyButton.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)
        nutritionChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        mealsChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        swapsChip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        nutritionChip.tag = AIChatCategory.nutrition.rawValue
        mealsChip.tag = AIChatCategory.meals.rawValue
        swapsChip.tag = AIChatCategory.swaps.rawValue
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: AIAssistantViewController, _) in
            controller.layoutComposerFade()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.resetIfHistoryCleared()
    }

    func restorePersistedConversation(id: UUID? = nil) {
        viewModel.restorePersistedConversation(id: id)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyChipsFade()
        layoutComposerFade()
        updateComposerOverlayInsets()
        micChrome.layoutIfNeeded()
        resizeComposer()
    }

    override func bindViewModel() {
        viewModel.onLimitReached = { [weak self] retry in
            guard let self else { return }
            view.endEditing(true)
            PremiumPrompt.requirePremium(from: self, then: retry)
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
        viewModel.inputText.bind { [weak self] value in
            guard self?.inputField.text != value else { return }
            self?.inputField.text = value
            self?.resizeComposer()
        }
        viewModel.isSending.bind { [weak self] isSending in
            self?.sendButton.isEnabled = !isSending
            self?.inputField.isEditable = !isSending
            self?.inputField.backgroundColor = .clear
            self?.historyButton.isEnabled = !isSending
            if self?.showsNewChatButton == true {
                self?.backButton.isEnabled = !isSending
            }
        }
        viewModel.isRecording.bind { [weak self] _ in
            self?.applyMic()
        }
        viewModel.canConfirmVoice.bind { [weak self] _ in
            self?.applyMic()
        }
        viewModel.messages.bind { [weak self] items in
            self?.applyMessages(items)
        }
        viewModel.selectedCategory.bind { [weak self] _ in
            self?.refreshChips()
        }
        viewModel.pendingWaterConfirmText.bind { [weak self] message in
            guard let self, let message else { return }
            self.presentWaterConfirmAlert(message: message)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === chipsScrollView else { return }
        applyChipsFade()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        switch items[indexPath.row].kind {
        case .recipe:
            return .adaptHeight(360)
        case .swap:
            return .adaptHeight(220)
        case .loggedMeal:
            return .adaptHeight(280)
        case .mealPlan:
            return .adaptHeight(220)
        case .typing:
            return .adaptHeight(52)
        case .user, .assistant, .system:
            return .adaptHeight(68)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: AIChatRowCell.reuseIdentifier, for: indexPath) as! AIChatRowCell
        cell.display(makeContent(for: item))
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard items.indices.contains(indexPath.row) else { return }
        let id = items[indexPath.row].id
        guard appearingMessageIDs.contains(id) else { return }
        appearingMessageIDs.remove(id)
        cell.contentView.alpha = 0
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            cell.contentView.alpha = 1
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        viewModel.updateInput(textView.text ?? "")
        resizeComposer()
    }

    private func resizeComposer() {
        guard composerHeight != nil, inputField.bounds.width > 0 else { return }
        inputPlaceholder.isHidden = !inputField.text.isEmpty
        let line = inputField.font?.lineHeight ?? 21
        let measured = inputField.sizeThatFits(CGSize(width: inputField.bounds.width, height: .greatestFiniteMagnitude)).height
        let textHeight = min(ceil(line * 4), max(ceil(line), ceil(measured)))
        if abs(inputHeight.constant - textHeight) > 0.5 {
            inputHeight.constant = textHeight
        }
        let height = max(48, textHeight + 20)
        if abs(composerHeight.constant - height) > 0.5 {
            composerHeight.constant = height
            view.setNeedsLayout()
        }
        inputField.isScrollEnabled = measured > ceil(line * 4) + 0.5
        if inputField.isFirstResponder {
            inputField.scrollRangeToVisible(inputField.selectedRange)
        }
    }


    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.9) else { return }
            DispatchQueue.main.async {
                self?.sendPhoto(data)
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        guard let image, let data = image.jpegData(compressionQuality: 0.9) else { return }
        sendPhoto(data)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url), UIImage(data: data) != nil else {
            presentMessage(L10n.tr("photo.error.noImage"))
            return
        }
        sendPhoto(data)
    }

    @objc
    private func inputChanged() {
        viewModel.updateInput(inputField.text ?? "")
    }

    @objc
    private func sendTapped() {
        guard !viewModel.isSending.value else { return }
        let text = inputField.text ?? ""
        viewModel.updateInput(text)
        hideAttachMenu()
        viewModel.sendTapped()
        view.endEditing(true)
    }

    @objc
    private func plusTapped() {
        if attachMenuView.isHidden {
            showAttachMenu()
        } else {
            hideAttachMenu()
        }
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
    private func backTapped() {
        if showsNewChatButton {
            guard !viewModel.isSending.value else { return }
            view.endEditing(true)
            hideAttachMenu()
            viewModel.startNewConversation()
            return
        }
        view.endEditing(true)
        hideAttachMenu()
        if presentingViewController != nil, navigationController?.viewControllers.first === self {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc
    private func historyTapped() {
        guard !viewModel.isSending.value else { return }
        onHistory?()
    }

    @objc
    private func chipTapped(_ sender: UIButton) {
        guard let category = AIChatCategory(rawValue: sender.tag) else { return }
        hideAttachMenu()
        viewModel.selectCategory(category)
    }

    @objc
    private func dismissKeyboard() {
        view.endEditing(true)
        hideAttachMenu()
    }

    @objc
    private func hideAttachMenu() {
        attachMenuView.isHidden = true
        attachDismissButton.isHidden = true
    }

    private func showAttachMenu() {
        view.endEditing(true)
        attachDismissButton.isHidden = false
        attachMenuView.isHidden = false
        view.bringSubviewToFront(attachDismissButton)
        view.bringSubviewToFront(attachMenuView)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentMessage(L10n.tr("photo.error.cameraUnavailable"))
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentGallery() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentFiles() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func presentMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.done"), style: .default))
        present(alert, animated: true)
    }

    private func sendPhoto(_ data: Data) {
        do {
            let prepared = try FoodPhotoImagePreprocessor.prepareJPEGBase64(from: data)
            viewModel.attachPreparedImage(base64: prepared.base64, mimeType: prepared.mimeType)
        } catch {
            presentMessage(error.localizedDescription)
        }
    }

    private func configureHeader() {
        titleLabel.textAlignment = .center
        OnboardingStyle.styleGlassSymbolButton(
            backButton,
            systemName: showsNewChatButton ? "square.and.pencil" : "chevron.backward",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        OnboardingStyle.styleGlassSymbolButton(
            historyButton,
            systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        if showsNewChatButton {
            backButton.accessibilityLabel = L10n.tr("ai.chat.newChat")
            backButton.accessibilityIdentifier = "ai.chat.newChat"
        }
        backButton.isHidden = !showsBackButton && !showsNewChatButton
        backButton.superview?.isHidden = !showsBackButton && !showsNewChatButton
        historyButton.accessibilityIdentifier = "ai.chat.history"
        historyButton.isHidden = !showsHistoryButton
        historyButton.superview?.isHidden = !showsHistoryButton
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
        tableView.backgroundColor = AppColor.backgroundsPrimary
        tableView.keyboardDismissMode = .interactive
        tableView.register(AIChatRowCell.self, forCellReuseIdentifier: AIChatRowCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.contentInset.bottom = .adaptHeight(8)
        tableView.verticalScrollIndicatorInsets.bottom = .adaptHeight(8)
    }

    private func configureComposer() {
        configureComposerFade()
        composerField.useLiveGlass = true
        composerField.applyCardShadow = true
        composerField.showsDropShadow = true
        // A text editor needs a passive glass surface, not a button's interactive lens.
        composerField.applyButtonGlass = false
        composerHeight = composerField.heightAnchor.constraint(equalToConstant: 48)
        composerHeight.isActive = true
        inputField.backgroundColor = .clear
        inputField.isOpaque = false
        inputField.font = .systemFont(ofSize: 17, weight: .medium)
        inputField.textColor = AppColor.labelVibrantPrimary
        inputHeight = inputField.heightAnchor.constraint(equalToConstant: ceil(inputField.font!.lineHeight))
        inputHeight.isActive = true
        inputField.textContainerInset = .zero
        inputField.textContainer.lineFragmentPadding = 0
        inputField.isScrollEnabled = false
        inputField.returnKeyType = .default
        inputPlaceholder.text = L10n.tr("ai.chat.placeholder")
        inputPlaceholder.font = inputField.font
        inputPlaceholder.textColor = AppColor.footerLabel
        inputPlaceholder.isUserInteractionEnabled = false
        inputPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        inputField.addSubview(inputPlaceholder)
        NSLayoutConstraint.activate([
            inputPlaceholder.leadingAnchor.constraint(equalTo: inputField.leadingAnchor),
            inputPlaceholder.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            inputPlaceholder.widthAnchor.constraint(equalTo: inputField.widthAnchor)
        ])
        OnboardingStyle.stylePlainSymbolButton(plusButton, systemName: "plus", foregroundColor: AppColor.labelVibrantPrimary)
        micChrome.attach(micButton)
        applyMic()
        OnboardingStyle.styleTealSymbolButton(sendButton, systemName: "arrow.up")
        composerBottomConstraint.isActive = false
        composerBar.bottomAnchor.constraint(
            lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -.adaptHeight(16)
        ).isActive = true
        composerBar.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor,
            constant: -.adaptHeight(8)
        ).isActive = true
    }

    private func configureComposerFade() {
        composerFadeView.isUserInteractionEnabled = false
        composerFadeView.backgroundColor = .clear
        composerFadeGradient.startPoint = CGPoint(x: 0.5, y: 1)
        composerFadeGradient.endPoint = CGPoint(x: 0.5, y: 0)
        if composerFadeGradient.superlayer !== composerFadeView.layer {
            composerFadeView.layer.addSublayer(composerFadeGradient)
        }
    }

    private func layoutComposerFade() {
        composerFadeGradient.frame = composerFadeView.bounds
        composerFadeGradient.colors = AppColor.fadeColors(
            from: AppColor.backgroundsPrimary,
            traits: traitCollection
        )
        composerFadeGradient.locations = [0, 0.5, 0.95238]
    }

    private func updateComposerOverlayInsets() {
        let barFrame = composerBar.convert(composerBar.bounds, to: tableView)
        let overlap = tableView.bounds.maxY - barFrame.minY
        let inset = max(overlap + .adaptHeight(8), .adaptHeight(8))
        tableView.contentInset.bottom = inset
        tableView.verticalScrollIndicatorInsets.bottom = inset
    }

    private func refreshChips() {
        let selected = viewModel.selectedCategory.value
        zip(
            [nutritionChip, mealsChip, swapsChip],
            AIChatCategory.allCases
        ).forEach { button, category in
            guard let button else { return }
            OnboardingStyle.styleChatCategoryChip(
                button,
                emoji: category.emoji,
                title: L10n.tr(category.titleKey),
                selected: selected == category
            )
        }
        scrollChipIntoView(selected)
    }

    private func scrollChipIntoView(_ category: AIChatCategory?) {
        guard let category else { return }
        let chips = [nutritionChip, mealsChip, swapsChip]
        guard chips.indices.contains(category.rawValue), let button = chips[category.rawValue] else { return }
        chipsScrollView.layoutIfNeeded()
        let frame = button.convert(button.bounds, to: chipsScrollView).insetBy(dx: -.adaptWidth(16), dy: 0)
        chipsScrollView.scrollRectToVisible(frame, animated: true)
    }

    private func applyChipsFade() {
        OnboardingStyle.applyChatChipsEdgeFade(to: chipsScrollView)
    }

    private func applyMessages(_ newItems: [AIChatItem]) {
        let oldItems = items
        items = newItems
        guard tableView.window != nil, oldItems.isEmpty == false else {
            tableView.reloadData()
            scrollToBottom(animated: false)
            return
        }
        playChatArrivalHaptic(from: oldItems, to: newItems)

        let oldIDs = oldItems.map(\.id)
        let newIDs = newItems.map(\.id)
        let oldSet = Set(oldIDs)
        let newSet = Set(newIDs)

        if oldIDs == newIDs {
            let changed = zip(oldItems, newItems).enumerated().compactMap { index, pair -> IndexPath? in
                pair.0.kind == pair.1.kind ? nil : IndexPath(row: index, section: 0)
            }
            if changed.isEmpty == false {
                tableView.reloadRows(at: changed, with: .fade)
            }
            scrollToBottom(animated: true)
            return
        }

        if oldSet.isDisjoint(with: newSet) {
            tableView.reloadData()
            scrollToBottom(animated: false)
            return
        }

        let deletes = oldIDs.enumerated().compactMap { index, id in
            newSet.contains(id) ? nil : IndexPath(row: index, section: 0)
        }
        let inserts = newIDs.enumerated().compactMap { index, id in
            oldSet.contains(id) ? nil : IndexPath(row: index, section: 0)
        }
        let reloads = newItems.enumerated().compactMap { index, item -> IndexPath? in
            guard let old = oldItems.first(where: { $0.id == item.id }), old.kind != item.kind else { return nil }
            return IndexPath(row: index, section: 0)
        }

        appearingMessageIDs.formUnion(inserts.compactMap { path -> UUID? in
            let item = newItems[path.row]
            switch item.kind {
            case .typing, .user:
                return nil
            default:
                return item.id
            }
        })

        tableView.performBatchUpdates({
            if deletes.isEmpty == false {
                tableView.deleteRows(at: deletes, with: .fade)
            }
            if inserts.isEmpty == false {
                tableView.insertRows(at: inserts, with: .none)
            }
            if reloads.isEmpty == false {
                tableView.reloadRows(at: reloads, with: .fade)
            }
        }, completion: { [weak self] _ in
            self?.scrollToBottom(animated: true)
        })
    }

    private func playChatArrivalHaptic(from oldItems: [AIChatItem], to newItems: [AIChatItem]) {
        let oldIDs = Set(oldItems.map(\.id))
        let newIDs = Set(newItems.map(\.id))
        guard oldIDs.isEmpty == false, oldIDs.isDisjoint(with: newIDs) == false else { return }
        let previous = Dictionary(uniqueKeysWithValues: oldItems.map { ($0.id, $0.kind) })
        var arrived = false
        var loggedMeal = false
        for item in newItems {
            switch item.kind {
            case .typing, .user:
                continue
            case .assistant, .recipe, .swap, .system, .loggedMeal, .mealPlan:
                break
            }
            let prior = previous[item.id]
            let isNew = prior == nil
            let replacedTyping: Bool
            if case .typing? = prior {
                replacedTyping = true
            } else {
                replacedTyping = false
            }
            guard isNew || replacedTyping else { continue }
            arrived = true
            if case .loggedMeal = item.kind {
                loggedMeal = true
            }
        }
        guard arrived else { return }
        if loggedMeal {
            Haptics.success()
        } else {
            Haptics.light()
        }
    }

    private func makeContent(for item: AIChatItem) -> UIView {
        switch item.kind {
        case .user(let text):
            let view = AIChatUserBubbleView()
            view.configure(text: text)
            return view
        case .assistant(let text), .system(let text):
            let view = AIChatAssistantBubbleView()
            view.configure(text: text)
            return view
        case .typing:
            let view = AIChatAssistantBubbleView()
            view.configureTyping()
            return view
        case .recipe(let option, let mealType):
            let view = AIChatRecipeCardView()
            view.configure(option, mealType: mealType)
            view.onLog = { [weak self] in
                self?.viewModel.logRecipe(option, mealType: mealType)
            }
            view.onSelect = { [weak self] in
                self?.onOpenRecipeDetails?(option, mealType)
            }
            return wrapAssistant(view)
        case .swap(let proposal):
            let view = AIChatSwapCardView()
            view.configure(proposal)
            view.onApply = { [weak self] in
                self?.viewModel.applySwap(proposal)
            }
            view.onSeeMore = { [weak self] in
                self?.viewModel.seeMoreSwapOptions()
            }
            return wrapAssistant(view)
        case .mealPlan(let plan):
            let view = AIChatMealPlanCardView()
            view.configure(plan)
            return view
        case .loggedMeal(let entryID, let proposal):
            let view = AIChatLoggedMealCardView()
            view.configure(proposal: proposal, canUndo: entryID != nil)
            view.onUndo = { [weak self] in
                guard let entryID else { return }
                self?.viewModel.undoLoggedMeal(id: entryID)
            }
            return wrapAssistant(view)
        }
    }

    private func wrapAssistant(_ content: UIView) -> UIView {
        let row = AIChatAssistantRowView()
        row.embed(content)
        return row
    }

    private func scrollToBottom(animated: Bool = true) {
        guard items.isEmpty == false, tableView.numberOfRows(inSection: 0) == items.count else { return }
        let index = IndexPath(row: items.count - 1, section: 0)
        tableView.scrollToRow(at: index, at: .bottom, animated: animated)
    }

    private func presentWaterConfirmAlert(message: String) {
        let alert = UIAlertController(title: L10n.tr("ai.alert.waterTitle"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel) { [weak self] _ in
            self?.viewModel.rejectPendingWaterLog()
        })
        alert.addAction(UIAlertAction(title: L10n.tr("common.confirm"), style: .default) { [weak self] _ in
            self?.viewModel.confirmPendingWaterLog()
        })
        Haptics.warning()
        present(alert, animated: true)
    }
}

private final class AIChatRowCell: UITableViewCell {
    static let reuseIdentifier = "AIChatRowCell"

    private var hostedView: UIView?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        automaticallyUpdatesContentConfiguration = false
        contentConfiguration = nil
        backgroundConfiguration = .clear()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostedView?.removeFromSuperview()
        hostedView = nil
        contentView.alpha = 1
        contentConfiguration = nil
    }

    func display(_ view: UIView) {
        hostedView?.removeFromSuperview()
        hostedView = view
        contentView.alpha = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentView.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -.adaptHeight(12)),
            view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: .adaptWidth(16)),
            view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -.adaptWidth(16))
        ])
        contentView.layoutIfNeeded()
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let width = targetSize.width > 0 ? targetSize.width : UIScreen.main.bounds.width
        contentView.bounds.size.width = width
        contentView.layoutIfNeeded()
        let fitted = contentView.systemLayoutSizeFitting(
            CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: ceil(fitted.height))
    }
}
