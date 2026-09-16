import PhotosUI
import UIKit

final class EditMealViewController: BaseViewController, UITextFieldDelegate, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var mealCard: AdaptiveView!
    @IBOutlet private weak var foodsStackView: UIStackView!
    @IBOutlet private weak var aiTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var composerFadeView: UIView!
    @IBOutlet private weak var composerField: AdaptiveView!
    @IBOutlet private weak var plusButton: UIButton!
    @IBOutlet private weak var inputField: UITextField!
    @IBOutlet private weak var micButton: UIButton!
    @IBOutlet private weak var sendButton: UIButton!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var footerView: UIView!
    @IBOutlet private weak var composerBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var foodsScrollView: UIScrollView!
    @IBOutlet private var foodsToFooterConstraint: NSLayoutConstraint!

    private let viewModel: EditMealViewModel
    private let micChrome = VoiceMicButtonChrome()
    private let composerFadeGradient = CAGradientLayer()
    private let loadingOverlay = CustomLoadingOverlayView()
    private var foodBlocks: [FoodBlock] = []
    private var renderedItems: [EditMealItem] = []
    private var scanOverlays: [CameraScanLineView] = []
    private var footerSafeAreaConstraint: NSLayoutConstraint?
    private var footerKeyboardConstraint: NSLayoutConstraint?
    private var scrollKeyboardConstraint: NSLayoutConstraint?
    private var footerOffscreenConstraint: NSLayoutConstraint?
    private var isAssistantChromeHidden = false
    private var portionEditingWork: DispatchWorkItem?
    private weak var activePortionField: EditMealPortionFieldView?
    private var keyboardScreenFrame: CGRect?

    private struct FoodBlock {
        let id: UUID
        let row: UIView
        let field: UIView
    }

    init(viewModel: EditMealViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "EditMealViewController")
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }

    override var analyticsScreen: AnalyticsScreen? { .editMeal }
    override var keyboardDismissExcludedViews: [UIView] { [sendButton].compactMap { $0 } }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.backgroundsPrimaryElevated
        navigationItem.largeTitleDisplayMode = .never
        configureHeader()
        configureMealCard()
        configureComposer()
        for name in [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardDidChangeFrameNotification, UIResponder.keyboardDidShowNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(portionKeyboardChanged(_:)), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(portionKeyboardHidden), name: UIResponder.keyboardDidHideNotification, object: nil)
        loadingOverlay.attach(to: view)
        viewModel.viewDidLoad()
#if DEBUG
        if QALaunchConfiguration.isActive, ProcessInfo.processInfo.arguments.contains("-qaLongMeal") {
            try? viewModel.stageAdditions((1...8).map { index in
                var entry = FoodLogProposal(name: "QA portion \(index)", mealType: viewModel.mealType,
                                           calories: 100, protein: 5, carbs: 10, fats: 4).toFoodEntry(date: Date())
                entry.portionGrams = 100
                return entry
            })
        }
#endif
        Analytics.tracker.track(.mealEditOpened(mealType: viewModel.mealType.rawValue, itemCount: viewModel.items.value.count))
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: EditMealViewController, _) in
            controller.refreshComposerFadeColors()
            controller.styleSendButton()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.reload()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            viewModel.discardChanges()
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        viewModel.discardChanges()
    }

    func stageAdditions(_ entries: [FoodEntry]) throws {
        try viewModel.stageAdditions(entries)
    }

    func askAssistant(_ query: String) {
        viewModel.updateInput(query)
        viewModel.sendTapped()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        composerFadeGradient.frame = composerFadeView.bounds
        refreshComposerFadeColors()
        updateFoodsScrollInsets()
        revealActivePortion()
        layoutScanOverlays()
        micChrome.layoutIfNeeded()
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
        viewModel.items.bind { [weak self] items in
            self?.renderFoods(items)
        }
        viewModel.inputText.bind { [weak self] value in
            guard self?.inputField.text != value else { return }
            self?.inputField.text = value
        }
        viewModel.isSending.bind { [weak self] isSending in
            self?.sendButton.isEnabled = !isSending
            self?.saveButton.isEnabled = !isSending
            self?.inputField.isEnabled = !isSending
            self?.layoutScanOverlays()
            self?.loadingOverlay.setVisible(isSending)
        }
        viewModel.scanningItemIDs.bind { [weak self] _ in
            self?.layoutScanOverlays()
        }
        viewModel.isRecording.bind { [weak self] _ in
            self?.applyMic()
        }
        viewModel.canConfirmVoice.bind { [weak self] _ in
            self?.applyMic()
        }
        viewModel.assistantMessage.bind { [weak self] message in
            guard let self, let message, !message.isEmpty else { return }
            let alert = UIAlertController(title: L10n.tr("editMeal.aiTitle"), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
            self.present(alert, animated: true)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.8) else { return }
            DispatchQueue.main.async {
                self?.sendPhoto(data)
            }
        }
    }

    @objc
    private func closeTapped() {
        view.endEditing(true)
        viewModel.closeTapped()
    }

    @objc
    private func addTapped() {
        view.endEditing(true)
        viewModel.addTapped()
    }

    @objc
    private func saveTapped() {
        view.endEditing(true)
        viewModel.saveTapped()
    }

    @objc
    private func sendTapped() {
        guard !viewModel.isSending.value else { return }
        viewModel.updateInput(inputField.text ?? "")
        viewModel.sendTapped()
        view.endEditing(true)
    }

    @objc
    private func plusTapped() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
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
        if !viewModel.canConfirmVoice.value {
            let color = viewModel.isRecording.value ? AppColor.teal : AppColor.iconSecondary
            micButton.tintColor = color
            micButton.imageView?.tintColor = color
            micButton.setImage(UIImage(systemName: "microphone", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))?.withTintColor(color, renderingMode: .alwaysOriginal), for: .normal)
        }
    }

    @objc
    private func inputChanged() {
        viewModel.updateInput(inputField.text ?? "")
    }

    private func sendPhoto(_ data: Data) {
        do {
            let prepared = try FoodPhotoImagePreprocessor.prepareJPEGBase64(from: data)
            viewModel.attachPreparedImage(base64: prepared.base64, mimeType: prepared.mimeType)
        } catch {
        }
    }

    private func configureHeader() {
        titleLabel.textAlignment = .center
        OnboardingStyle.styleGlassSymbolButton(
            closeButton,
            systemName: "xmark",
            foregroundColor: AppColor.labelsSecondary,
            liveGlass: false
        )
        OnboardingStyle.styleTealSymbolButton(addButton, systemName: "plus")
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        OnboardingStyle.stylePrimaryButton(saveButton, title: L10n.tr("editMeal.save"), systemImage: "checkmark")
    }

    private func configureMealCard() {
        mealCard.useLiveGlass = false
        mealCard.applyCardShadow = false
        mealCard.applyButtonGlass = false
        mealCard.showsDropShadow = false
        mealCard.showsHairlineBorder = false
        mealCard.clipsToBounds = false
        mealCard.layer.masksToBounds = false
        mealCard.backgroundColor = .clear
        foodsScrollView.backgroundColor = .clear
        foodsStackView.axis = .vertical
        foodsStackView.spacing = .adaptHeight(4)
        foodsStackView.alignment = .fill
        foodsStackView.distribution = .fill
        foodsStackView.clipsToBounds = false
    }

    private func updateFoodsScrollInsets() {
        let scrollFrame = foodsScrollView.convert(foodsScrollView.bounds, to: view)
        let fadeFrame = composerFadeView.convert(composerFadeView.bounds, to: view)
        let overlap = scrollFrame.intersection(fadeFrame)
        var bottomInset = isAssistantChromeHidden || overlap.isNull ? 0 : overlap.height
        if isAssistantChromeHidden, let frame = keyboardScreenFrame, let window = view.window {
            let keyboard = view.convert(window.convert(frame, from: window.screen.coordinateSpace), from: window)
            let covered = scrollFrame.intersection(keyboard)
            if !covered.isNull { bottomInset = covered.height }
        }
        if foodsScrollView.contentInset.bottom != bottomInset {
            foodsScrollView.contentInset.bottom = bottomInset
            foodsScrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    private func configureComposer() {
        aiTitleLabel.adaptFontSize = false
        aiTitleLabel.textAlignment = .left
        aiTitleLabel.attributedText = Self.sparklesTitle(L10n.tr("editMeal.aiTitle"))
        aiTitleLabel.lineBreakMode = .byTruncatingTail
        aiTitleLabel.setContentHuggingPriority(.required, for: .horizontal)
        aiTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        composerField.useLiveGlass = true
        composerField.applyCardShadow = true
        composerField.showsDropShadow = true
        composerField.applyButtonGlass = true
        inputField.delegate = self
        inputField.borderStyle = .none
        inputField.backgroundColor = .clear
        inputField.font = .systemFont(ofSize: 17, weight: .medium)
        inputField.textColor = AppColor.labelVibrantPrimary
        inputField.attributedPlaceholder = NSAttributedString(
            string: L10n.tr("editMeal.aiPlaceholder"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: AppColor.footerLabel
            ]
        )
        inputField.addTarget(self, action: #selector(inputChanged), for: .editingChanged)
        plusButton.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        micButton.controlHaptic = .medium
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        OnboardingStyle.stylePlainSymbolButton(plusButton, systemName: "plus", foregroundColor: AppColor.labelVibrantPrimary)
        micChrome.attach(micButton)
        applyMic()
        styleSendButton()
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: symbolConfiguration), for: .normal)
        addButton.configuration?.image = UIImage(systemName: "plus", withConfiguration: symbolConfiguration)
        saveButton.configuration?.image = UIImage(systemName: "checkmark", withConfiguration: symbolConfiguration)
        plusButton.setImage(UIImage(systemName: "plus", withConfiguration: symbolConfiguration), for: .normal)
        composerFadeView.isUserInteractionEnabled = false
        composerFadeView.backgroundColor = .clear
        composerFadeGradient.startPoint = CGPoint(x: 0.5, y: 1)
        composerFadeGradient.endPoint = CGPoint(x: 0.5, y: 0)
        refreshComposerFadeColors()
        composerFadeGradient.locations = [0, 0.5, 0.95238]
        if composerFadeGradient.superlayer !== composerFadeView.layer {
            composerFadeView.layer.addSublayer(composerFadeGradient)
        }
        foodsScrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        foodsScrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        footerView.setContentHuggingPriority(.required, for: .vertical)
        footerView.setContentCompressionResistancePriority(.required, for: .vertical)
        saveButton.setContentHuggingPriority(.required, for: .vertical)
        saveButton.setContentCompressionResistancePriority(.required, for: .vertical)
        composerBottomConstraint.isActive = false
        view.keyboardLayoutGuide.usesBottomSafeArea = true
        footerKeyboardConstraint = footerView.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor
        )
        footerSafeAreaConstraint = footerKeyboardConstraint
        scrollKeyboardConstraint = foodsScrollView.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor
        )
        footerOffscreenConstraint = footerView.topAnchor.constraint(equalTo: view.bottomAnchor)
        footerKeyboardConstraint?.isActive = true
        scrollKeyboardConstraint?.isActive = false
        footerOffscreenConstraint?.isActive = false
        view.clipsToBounds = true
    }

    private func styleSendButton() {
        if traitCollection.userInterfaceStyle == .dark {
            OnboardingStyle.styleGlassSymbolButton(sendButton, systemName: "arrow.up", foregroundColor: .white)
        } else {
            OnboardingStyle.styleTealSymbolButton(sendButton, systemName: "arrow.up")
        }
        let image = UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
        if sendButton.configuration != nil {
            sendButton.configuration?.image = image
        } else {
            sendButton.setImage(image, for: .normal)
        }
    }

    private func renderFoods(_ items: [EditMealItem]) {
        // Repository notifications can deliver the same state more than once.
        guard items != renderedItems else { return }
        let remainingIDs = Set(items.map(\.id))
        let isDeletion = items.count < renderedItems.count
            && items == renderedItems.filter { remainingIDs.contains($0.id) }
        renderedItems = items
        guard isDeletion else {
            rebuildFoods(items)
            return
        }
        removeFoodBlocks(except: remainingIDs)
    }

    private func removeFoodBlocks(except remainingIDs: Set<UUID>) {
        view.layoutIfNeeded()
        let shouldAnimate = view.window != nil && !UIAccessibility.isReduceMotionEnabled
        let removed = foodBlocks.filter { !remainingIDs.contains($0.id) }
        var snapshots: [UIView] = []
        for block in removed {
            for element in [block.row, block.field] {
                if shouldAnimate, let snapshot = element.snapshotView(afterScreenUpdates: false) {
                    snapshot.frame = element.convert(element.bounds, to: foodsScrollView)
                    snapshot.isUserInteractionEnabled = false
                    foodsScrollView.addSubview(snapshot)
                    snapshots.append(snapshot)
                }
                foodsStackView.removeArrangedSubview(element)
                element.removeFromSuperview()
            }
        }
        foodBlocks.removeAll { !remainingIDs.contains($0.id) }
        mealCard.isHidden = foodBlocks.isEmpty
        let updates = {
            // Existing rows and images retain their identity; only their positions move.
            self.view.layoutIfNeeded()
            let minimumY = -self.foodsScrollView.adjustedContentInset.top
            let maximumY = max(minimumY, self.foodsScrollView.contentSize.height
                - self.foodsScrollView.bounds.height + self.foodsScrollView.adjustedContentInset.bottom)
            let offset = self.foodsScrollView.contentOffset
            self.foodsScrollView.contentOffset = CGPoint(x: offset.x, y: min(max(offset.y, minimumY), maximumY))
            snapshots.forEach {
                $0.alpha = 0
                $0.transform = CGAffineTransform(translationX: 12, y: 0)
            }
        }
        if shouldAnimate {
            UIView.animate(withDuration: 0.26, delay: 0,
                           options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
                           animations: updates) { _ in
                snapshots.forEach { $0.removeFromSuperview() }
            }
        } else {
            updates()
        }
        layoutScanOverlays()
    }

    private func rebuildFoods(_ items: [EditMealItem]) {
        foodsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        foodBlocks = []
        mealCard.isHidden = items.isEmpty
        items.forEach { item in
            let row = EditMealFoodRowView()
            row.onDelete = { [weak self] id in
                self?.viewModel.deleteFood(id: id)
            }
            row.onSelect = { [weak self] id in
                self?.viewModel.openFood(id: id)
            }
            let field = EditMealPortionFieldView()
            field.onCommitPortion = { [weak self] id, text in
                self?.viewModel.commitPortion(id: id, text: text)
            }
            field.onEditingChanged = { [weak self, weak field] editing in
                if editing {
                    self?.activePortionField = field
                } else if self?.activePortionField === field {
                    self?.activePortionField = nil
                }
                self?.setPortionEditing(editing)
            }
            foodsStackView.addArrangedSubview(row)
            foodsStackView.addArrangedSubview(field)
            row.configure(item)
            field.configure(item)
            foodBlocks.append(FoodBlock(id: item.id, row: row, field: field))
        }
        layoutScanOverlays()
    }

    private func setPortionEditing(_ editing: Bool) {
        portionEditingWork?.cancel()
        if editing {
            setAssistantChromeHidden(true)
            view.setNeedsLayout()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.setAssistantChromeHidden(false)
        }
        portionEditingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func revealActivePortion() {

        guard let field = activePortionField, field.isDescendant(of: foodsScrollView),
              foodsScrollView.bounds.height > 0 else { return }
        // The keyboard layout guide changes the viewport after editing begins.
        // Use its final layout and scroll coordinates, including the current offset.
        foodsScrollView.layoutIfNeeded()
        let target = field.convert(field.bounds, to: foodsScrollView).insetBy(dx: 0, dy: -12)
        let inset = foodsScrollView.adjustedContentInset
        let visibleTop = foodsScrollView.contentOffset.y + inset.top
        let visibleBottom = foodsScrollView.contentOffset.y + foodsScrollView.bounds.height - inset.bottom
        var offset = foodsScrollView.contentOffset.y
        if target.maxY > visibleBottom {
            offset += target.maxY - visibleBottom
        } else if target.minY < visibleTop {
            offset -= visibleTop - target.minY
        }
        let minimum = -inset.top
        let maximum = max(minimum, foodsScrollView.contentSize.height - foodsScrollView.bounds.height + inset.bottom)
        let next = min(max(offset, minimum), maximum)
        if abs(next - foodsScrollView.contentOffset.y) > 0.5 {
            foodsScrollView.setContentOffset(CGPoint(x: foodsScrollView.contentOffset.x, y: next), animated: false)
        }
    }

    @objc private func portionKeyboardChanged(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        keyboardScreenFrame = frame
        guard activePortionField != nil else { return }
        view.layoutIfNeeded()
        updateFoodsScrollInsets()
        revealActivePortion()
    }

    @objc private func portionKeyboardHidden() {
        keyboardScreenFrame = nil
        updateFoodsScrollInsets()
    }

    private func setAssistantChromeHidden(_ hidden: Bool) {
        guard isAssistantChromeHidden != hidden else { return }
        isAssistantChromeHidden = hidden
        foodsToFooterConstraint.isActive = !hidden
        scrollKeyboardConstraint?.isActive = hidden
        footerSafeAreaConstraint?.isActive = !hidden
        footerKeyboardConstraint?.isActive = !hidden
        footerOffscreenConstraint?.isActive = hidden
        footerView.isUserInteractionEnabled = !hidden
        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            self.composerFadeView.alpha = hidden ? 0 : 1
            self.view.layoutIfNeeded()
        }
    }

    private func layoutScanOverlays() {
        let groups = scanGroups()
        guard viewModel.isSending.value, !groups.isEmpty, mealCard.window != nil, !mealCard.isHidden else {
            clearScanOverlays()
            return
        }
        while scanOverlays.count < groups.count {
            let overlay = CameraScanLineView()
            overlay.layer.cornerRadius = .adaptWidth(32)
            mealCard.addSubview(overlay)
            scanOverlays.append(overlay)
        }
        while scanOverlays.count > groups.count {
            let overlay = scanOverlays.removeLast()
            overlay.stopAnimating()
            overlay.removeFromSuperview()
        }
        zip(scanOverlays, groups).forEach { overlay, group in
            overlay.frame = group.frame
            overlay.bandHeight = group.bandHeight
            overlay.startAnimating()
        }
    }

    private func clearScanOverlays() {
        scanOverlays.forEach { overlay in
            overlay.stopAnimating()
            overlay.removeFromSuperview()
        }
        scanOverlays = []
    }

    private func scanGroups() -> [(frame: CGRect, bandHeight: CGFloat)] {
        let ids = viewModel.scanningItemIDs.value
        var groups: [[FoodBlock]] = []
        var current: [FoodBlock] = []
        foodBlocks.forEach { block in
            if ids.contains(block.id) {
                current.append(block)
            } else if !current.isEmpty {
                groups.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            groups.append(current)
        }
        return groups.compactMap { group in
            let frames = group.map { block in
                block.row.convert(block.row.bounds, to: mealCard)
                    .union(block.field.convert(block.field.bounds, to: mealCard))
            }
            guard let first = frames.first else { return nil }
            let frame = frames.dropFirst().reduce(first) { $0.union($1) }
            guard frame.width > 0, frame.height > 0 else { return nil }
            let bandHeight = group.reduce(0) { $0 + $1.field.bounds.height }
            return (frame, bandHeight)
        }
    }

    private func refreshComposerFadeColors() {
        composerFadeGradient.colors = AppColor.fadeColors(
            from: AppColor.backgroundsPrimaryElevated,
            traits: traitCollection
        )
    }

    private static func sparklesTitle(_ text: String) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: AppColor.labelVibrantPrimary,
            .kern: -0.23,
            .paragraphStyle: paragraph
        ]
        let result = NSMutableAttributedString()
        if let image = OnboardingStyle.symbol("sparkles", pointSize: 15) {
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(AppColor.labelVibrantPrimary, renderingMode: .alwaysOriginal)
            attachment.bounds = CGRect(x: 0, y: -2, width: 15, height: 15)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: " ", attributes: attributes))
        }
        result.append(NSAttributedString(string: text, attributes: attributes))
        return result
    }
}
