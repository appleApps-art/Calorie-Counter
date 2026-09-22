import PhotosUI
import UIKit

final class AIPhotoCameraViewController: BaseViewController, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var freezeFrameView: UIImageView!
    @IBOutlet private weak var overlayView: CameraScanOverlayView!
    @IBOutlet private weak var frameView: CameraScanFrameView!
    @IBOutlet private weak var scanLineView: CameraScanLineView!
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var flashButton: UIButton!
    @IBOutlet private weak var tooltipView: AdaptiveView!
    @IBOutlet private weak var tooltipLabel: AdaptiveLabel!
    @IBOutlet private weak var hintBar: AdaptiveView!
    @IBOutlet private weak var hintIconView: UIImageView!
    @IBOutlet private weak var hintSpinner: UIActivityIndicatorView!
    @IBOutlet private weak var hintLabel: AdaptiveLabel!
    @IBOutlet private weak var galleryButton: UIButton!
    @IBOutlet private weak var shutterButton: UIButton!
    @IBOutlet private weak var shutterDiscView: UIView!
    @IBOutlet private weak var modeControl: UISegmentedControl!
    @IBOutlet private weak var dimView: UIView!
    @IBOutlet private weak var resultSheet: AdaptiveView!
    @IBOutlet private weak var resultCloseButton: UIButton!
    @IBOutlet private weak var resultTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var productCard: AdaptiveView!
    @IBOutlet private weak var productImageView: UIImageView!
    @IBOutlet private weak var productNameLabel: AdaptiveLabel!
    @IBOutlet private weak var productSubtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreCard: AdaptiveView!
    @IBOutlet private weak var scoreCircleView: AdaptiveView!
    @IBOutlet private weak var scoreGradeLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreSummaryLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesValueLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinValueLabel: AdaptiveLabel!
    @IBOutlet private weak var carbsTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var carbsValueLabel: AdaptiveLabel!
    @IBOutlet private weak var fatTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var fatValueLabel: AdaptiveLabel!
    @IBOutlet private var microCards: [AdaptiveView]!
    @IBOutlet private weak var detailsLabel: AdaptiveLabel!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var detailsButton: UIButton!

    private let viewModel: FoodPhotoAnalysisViewModel
    private let capturer: FoodPhotoCapturing
    /// Free tries left on a free account; nil for Premium, which has no counter.
    private let freeScansLeft: Int?
    private var isTorchOn = false
    private var hasStarted = false
    private var isCameraReady = false
    private var isPickerVisible = false
    private let resultSheetTint = UIView()
    private var resultSwipeDismissal: ResultPanelSwipeDismissal?
    private var lastPhotoPhase: AIPhotoPhase?
    private let frameCornerRadius: CGFloat = 26

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init(
        viewModel: FoodPhotoAnalysisViewModel,
        capturer: FoodPhotoCapturing = CameraFoodPhotoCapturer(),
        freeScansLeft: Int? = nil
    ) {
        self.viewModel = viewModel
        self.capturer = capturer
        self.freeScansLeft = freeScansLeft
        super.init(nibName: "AIPhotoCameraViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .aiPhoto }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationItem.largeTitleDisplayMode = .never
        configureCameraChrome()
        configureResultSheet()
        if viewModel.inventoryMode {
            applyFridgeScanFrame()
        }
        tooltipView.isHidden = freeScansLeft == nil
        capturer.attachPreview(to: previewView)
        previewView.bringSubviewToFront(overlayView)
        capturer.onPhotoCaptured = { [weak self] data in
            self?.viewModel.analyze(imageData: data)
        }
        capturer.onCaptureFailed = { [weak self] error in
            self?.viewModel.captureFailed(error)
        }
        capturer.onSessionRunning = { [weak self] in
            self?.isCameraReady = true
        }
        freezeFrameView.contentMode = .scaleAspectFill
        freezeFrameView.clipsToBounds = true
        freezeFrameView.isHidden = true
        frameView.isUserInteractionEnabled = false
        overlayView.isUserInteractionEnabled = false
        applyPhase(viewModel.phase.value, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        capturer.layoutPreview(in: previewView)
        if !hasStarted {
            hasStarted = true
            capturer.startCapture()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            capturer.stopCapture()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        capturer.layoutPreview(in: previewView)
        let radius = CGFloat.adaptWidth(frameCornerRadius)
        frameView.frameCornerRadius = radius
        overlayView.holeCornerRadius = radius
        overlayView.holeRect = overlayView.convert(frameView.bounds, from: frameView)
        modeControl.shrinkCameraModeTitlesToFit()
        layoutShutterButton()
        layoutResultSheetTint()
    }

    /// The tint has to take the panel's shape: square corners would poke out of the glass.
    private func layoutResultSheetTint() {
        RecognitionResultPanel.layout(tint: resultSheetTint, in: resultSheet)
    }

    override func bindViewModel() {
        viewModel.phase.bind { [weak self] phase in
            self?.applyPhase(phase, animated: true)
        }
        viewModel.statusText.bind { [weak self] value in
            guard let self, self.viewModel.phase.value == .idle else { return }
            if value != L10n.tr("photo.status"), value != L10n.tr("photo.analyzing") {
                self.hintLabel.text = value
            }
        }
        viewModel.analysis.bind { [weak self] _ in
            self?.renderResult()
        }
        viewModel.errorText.bind { [weak self] message in
            guard !message.isEmpty else { return }
            self?.presentError(message)
        }
        viewModel.capturedImage.bind { [weak self] image in
            self?.productImageView.image = image
            self?.updateFreezeFrame()
        }
        viewModel.showsFullDetails.bind { [weak self] visible in
            self?.detailsLabel.isHidden = !visible
        }
        viewModel.canConfirmLog.bind { [weak self] canLog in
            self?.addButton.isEnabled = canLog
        }
    }

    @objc
    private func closeTapped() {
        viewModel.closeTapped()
    }

    @objc
    private func flashTapped() {
        isTorchOn.toggle()
        capturer.setTorchOn(isTorchOn)
        styleFlashButton()
    }

    @objc
    private func galleryTapped() {
        guard viewModel.phase.value == .idle else { return }
        isPickerVisible = true
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        // A swipe-down closes the picker without calling didFinishPicking; the shutter must not
        // stay locked behind a picker that is already gone.
        picker.presentationController?.delegate = self
        present(picker, animated: true)
    }

    @objc
    private func shutterTapped() {
        captureFoodPhoto()
    }

    @objc
    private func shutterPressed() {
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.shutterDiscView.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        }
    }

    @objc
    private func shutterReleased() {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.shutterDiscView.transform = .identity
        }
    }

    @objc
    private func modeChanged() {
        switch modeControl.selectedSegmentIndex {
        case 1:
            viewModel.switchMode(.scanBarcode)
        case 2:
            viewModel.switchMode(.search)
        case 3:
            viewModel.switchMode(.voiceLog)
        default:
            break
        }
    }

    @objc
    private func resultCloseTapped() {
        viewModel.dismissResultTapped()
    }

    @objc
    private func addTapped() {
        viewModel.confirmLogTapped()
    }

    @objc
    private func detailsTapped() {
        viewModel.viewDetailsTapped()
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        isPickerVisible = false
    }

    /// Offline a picked photo fails at once, while the gallery is still closing; the alert waits
    /// for it instead of being dropped.
    private func presentError(_ message: String, attempt: Int = 0) {
        guard viewIfLoaded?.window != nil else { return }
        if let presented = presentedViewController {
            guard presented.isBeingDismissed, attempt < 10 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.presentError(message, attempt: attempt + 1)
            }
            return
        }
        Haptics.error()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
        present(alert, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        isPickerVisible = false
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.viewModel.analyze(image: image)
            }
        }
    }

    private func configureCameraChrome() {
        OnboardingStyle.styleGlassSymbolButton(
            closeButton,
            systemName: "xmark",
            foregroundColor: .white
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        styleFlashButton()
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)
        OnboardingStyle.styleGlassSymbolButton(
            galleryButton,
            systemName: "photo.on.rectangle.angled",
            foregroundColor: .white
        )
        galleryButton.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
        configureShutterButton()

        tooltipView.useLiveGlass = false
        tooltipView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        tooltipView.isHidden = freeScansLeft == nil
        tooltipLabel.text = L10n.format("photo.camera.freeScansLeft", freeScansLeft ?? 0)
        tooltipLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(tooltipLabel, size: 15, weight: .regular, color: .white, kern: -0.23)

        hintBar.useLiveGlass = false
        hintBar.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        hintLabel.textColor = .white
        hintSpinner.color = .white
        hintSpinner.hidesWhenStopped = true
        hintIconView.tintColor = .white
        hintIconView.contentMode = .scaleAspectFit

        modeControl.configureCameraModes(titles: CameraModeChrome.titles, selectedIndex: 0)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
    }

    private func configureResultSheet() {
        RecognitionResultPanel.style(sheet: resultSheet, tint: resultSheetTint, cards: [productCard, scoreCard] + microCards)
        scoreCircleView.useLiveGlass = false
        scoreCircleView.backgroundColor = AppColor.accentMint
        productImageView.contentMode = .scaleAspectFill
        productImageView.clipsToBounds = true
        productImageView.layer.cornerRadius = .adaptWidth(12)
        productImageView.layer.cornerCurve = .continuous
        productImageView.backgroundColor = AppColor.fillSecondary

        resultTitleLabel.text = L10n.tr("photo.result.title")
        resultTitleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            resultTitleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(
            resultCloseButton,
            systemName: "xmark",
            foregroundColor: AppColor.iconSecondary
        )
        resultCloseButton.addTarget(self, action: #selector(resultCloseTapped), for: .touchUpInside)

        caloriesTitleLabel.text = L10n.tr("photo.result.calories")
        proteinTitleLabel.text = L10n.tr("home.protein")
        carbsTitleLabel.text = L10n.tr("home.carbs")
        fatTitleLabel.text = L10n.tr("photo.result.fat")
        [
            caloriesTitleLabel,
            proteinTitleLabel,
            carbsTitleLabel,
            fatTitleLabel
        ].forEach { label in
            OnboardingStyle.lockFigmaFont(
                label,
                size: 13,
                weight: .regular,
                color: AppColor.iconSecondary,
                kern: -0.08
            )
        }

        OnboardingStyle.stylePrimaryButton(
            addButton,
            title: L10n.tr("photo.result.addToDiary"),
            systemImage: "square.and.arrow.up"
        )
        // The scan result uses the deeper accent from the design, dark teal in light mode.
        if var configuration = addButton.configuration {
            configuration.baseBackgroundColor = AppColor.tabSelected
            configuration.background.backgroundColor = AppColor.tabSelected
            configuration.baseForegroundColor = AppColor.onAccent
            addButton.configuration = configuration
            addButton.tintColor = AppColor.tabSelected
        }
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        OnboardingStyle.styleGlassButton(
            detailsButton,
            title: L10n.tr("photo.result.viewDetails"),
            foregroundColor: AppColor.labelVibrantPrimary,
            weight: .medium
        )
        detailsButton.addTarget(self, action: #selector(detailsTapped), for: .touchUpInside)

        detailsLabel.numberOfLines = 0
        detailsLabel.isHidden = true
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        dimView.alpha = 0
        dimView.isHidden = true
        resultSheet.alpha = 0
        resultSheet.isHidden = true
        resultSheet.transform = CGAffineTransform(translationX: 0, y: 48)
        pinResultScrollContent()
        installResultSwipeDismissal()
    }

    private func pinResultScrollContent() {
        guard let stack = productCard.superview, let scroll = stack.superview as? UIScrollView else { return }
        scroll.pinFilledContent(stack, hugHeight: true)
    }

    private func installResultSwipeDismissal() {
        let scroll = productCard.superview?.superview as? UIScrollView
        resultSwipeDismissal = ResultPanelSwipeDismissal(panel: resultSheet, scrollView: scroll) { [weak self] in
            self?.viewModel.dismissResultTapped()
        }
    }

    private func applyFridgeScanFrame() {
        for constraint in frameView.constraints {
            guard constraint.firstAttribute == .height, let adaptive = constraint as? AdaptiveConstraint else {
                continue
            }
            adaptive.designConstant = 560
            adaptive.priority = UILayoutPriority(750)
        }
        for constraint in view.constraints {
            guard constraint.firstItem === frameView,
                  constraint.firstAttribute == .centerY,
                  constraint.secondItem === view
            else {
                continue
            }
            constraint.priority = UILayoutPriority(750)
            if let adaptive = constraint as? AdaptiveConstraint {
                adaptive.designConstant = -22
            } else {
                constraint.constant = .adaptHeight(-22)
            }
        }
    }

    private func styleFlashButton() {
        OnboardingStyle.styleGlassSymbolButton(
            flashButton,
            systemName: "flashlight.on.fill",
            foregroundColor: isTorchOn ? AppColor.teal : .white
        )
    }

    private func configureShutterButton() {
        shutterButton.configuration = nil
        shutterButton.setTitle(nil, for: .normal)
        shutterButton.setImage(nil, for: .normal)
        shutterButton.backgroundColor = .clear
        shutterButton.tintColor = .clear
        shutterButton.clipsToBounds = true
        shutterButton.layer.borderWidth = 0
        shutterButton.accessibilityLabel = L10n.tr("progressPhoto.shutter")
        shutterButton.controlHaptic = .none
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        shutterButton.addTarget(self, action: #selector(shutterPressed), for: .touchDown)
        shutterButton.addTarget(self, action: #selector(shutterReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        shutterDiscView.backgroundColor = .white
        shutterDiscView.isUserInteractionEnabled = false
        shutterDiscView.layer.masksToBounds = true
        guard let wrap = shutterButton.superview else { return }
        wrap.backgroundColor = .clear
        wrap.layer.borderWidth = 4
        wrap.layer.borderColor = UIColor.white.cgColor
        wrap.clipsToBounds = false
        wrap.bringSubviewToFront(shutterDiscView)
    }

    private func layoutShutterButton() {
        shutterButton.layer.cornerRadius = shutterButton.bounds.height / 2
        shutterButton.layer.cornerCurve = .continuous
        shutterDiscView.layer.cornerRadius = shutterDiscView.bounds.height / 2
        shutterDiscView.layer.cornerCurve = .continuous
        guard let wrap = shutterButton.superview else { return }
        wrap.layer.cornerRadius = wrap.bounds.height / 2
        wrap.layer.cornerCurve = .continuous
        wrap.layer.borderColor = UIColor.white.cgColor
    }

    private func updateShutterAndHint(showsShutter: Bool, animated: Bool) {
        let wrap = shutterButton.superview
        if showsShutter {
            wrap?.isHidden = false
        } else {
            hintBar.isHidden = false
        }
        wrap?.isUserInteractionEnabled = showsShutter
        shutterButton.isUserInteractionEnabled = showsShutter
        let updates = {
            wrap?.alpha = showsShutter ? 1 : 0
            self.hintBar.alpha = showsShutter ? 0 : 1
        }
        let finish = {
            wrap?.isHidden = !showsShutter
            self.hintBar.isHidden = showsShutter
        }
        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: updates) { _ in
                finish()
            }
        } else {
            updates()
            finish()
        }
    }

    private func applyPhase(_ phase: AIPhotoPhase, animated: Bool) {
        let becameResult = phase == .result && lastPhotoPhase != nil && lastPhotoPhase != .result
        lastPhotoPhase = phase
        modeControl.isEnabled = phase == .idle
        galleryButton.isEnabled = phase == .idle
        shutterButton.isEnabled = phase == .idle
        updateShutterAndHint(showsShutter: phase == .idle, animated: animated)

        switch phase {
        case .idle:
            frameView.strokeColor = .white
            scanLineView.stopAnimating()
            hintSpinner.stopAnimating()
            hintIconView.isHidden = false
            hintIconView.image = OnboardingStyle.symbol("viewfinder", pointSize: 17)
            if viewModel.statusText.value == L10n.tr("photo.status")
                || viewModel.statusText.value == L10n.tr("photo.analyzing")
                || viewModel.statusText.value == L10n.tr("textLog.readyToConfirm")
                || viewModel.statusText.value == L10n.tr("textLog.foodLogged") {
                hintLabel.text = L10n.tr("photo.camera.hint")
            } else {
                hintLabel.text = viewModel.statusText.value
            }
        case .identifying:
            frameView.strokeColor = .white
            hintIconView.isHidden = true
            hintSpinner.startAnimating()
            hintLabel.text = L10n.tr("photo.camera.identifying")
            scanLineView.startAnimating()
        case .recognized, .result:
            frameView.strokeColor = AppColor.teal
            scanLineView.stopAnimating()
            hintSpinner.stopAnimating()
            hintIconView.isHidden = false
            hintIconView.image = OnboardingStyle.symbol("checkmark", pointSize: 17)
            hintLabel.text = L10n.tr("photo.camera.recognized")
        }

        OnboardingStyle.lockFigmaFont(hintLabel, size: 17, weight: .regular, color: .white, kern: -0.43)
        updateFreezeFrame()
        let showsResult = phase == .result && !viewModel.inventoryMode
        setResultVisible(showsResult, animated: animated)
        if showsResult {
            renderResult()
            resultSheet.layoutIfNeeded()
            if becameResult {
                Haptics.success()
            }
        }
    }

    private func captureFoodPhoto() {
        guard isCameraReady, !isPickerVisible, view.window != nil else { return }
        guard viewModel.phase.value == .idle else { return }
        viewModel.beginCapture()
        Haptics.rigid()
        capturer.captureStillPhoto(scanFrameInPreview: previewView.convert(frameView.bounds, from: frameView))
    }

    private func updateFreezeFrame() {
        let image = viewModel.capturedImage.value
        let freeze = image != nil && viewModel.phase.value != .idle
        freezeFrameView.image = freeze ? image : nil
        freezeFrameView.isHidden = !freeze
        capturer.setLivePreviewHidden(freeze)
    }

    private func setResultVisible(_ visible: Bool, animated: Bool) {
        dimView.isHidden = false
        resultSheet.isHidden = false
        let updates = {
            self.dimView.alpha = visible ? 1 : 0
            self.resultSheet.alpha = visible ? 1 : 0
            self.resultSheet.transform = visible ? .identity : CGAffineTransform(translationX: 0, y: 48)
        }
        let finish = {
            if !visible {
                self.dimView.isHidden = true
                self.resultSheet.isHidden = true
            }
        }
        if animated {
            UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: updates) { _ in
                finish()
            }
        } else {
            updates()
            finish()
        }
    }

    private func renderResult() {
        guard let result = viewModel.analysis.value else { return }
        productNameLabel.text = result.name
        OnboardingStyle.lockFigmaFont(
            productNameLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        productSubtitleLabel.text = viewModel.productSubtitleText
        OnboardingStyle.lockFigmaFont(
            productSubtitleLabel,
            size: 15,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: -0.23
        )
        let facts = result.nutritionFacts
        scoreGradeLabel.text = facts.grade.rawValue
        OnboardingStyle.lockFigmaFont(scoreGradeLabel, size: 17, weight: .semibold, color: .white)
        scoreTitleLabel.text = viewModel.healthScoreTitleText
        OnboardingStyle.lockFigmaFont(
            scoreTitleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        scoreSummaryLabel.text = facts.summary
        OnboardingStyle.lockFigmaFont(
            scoreSummaryLabel,
            size: 13,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: -0.08
        )
        caloriesValueLabel.text = viewModel.caloriesValueText
        proteinValueLabel.text = viewModel.proteinValueText
        carbsValueLabel.text = viewModel.carbsValueText
        fatValueLabel.text = viewModel.fatValueText
        [
            caloriesValueLabel,
            proteinValueLabel,
            carbsValueLabel,
            fatValueLabel
        ].forEach { label in
            OnboardingStyle.lockFigmaFont(
                label,
                size: 17,
                weight: .regular,
                color: AppColor.labelsPrimary,
                kern: -0.43
            )
        }
        detailsLabel.text = viewModel.fullDetailsText
        OnboardingStyle.lockFigmaFont(
            detailsLabel,
            size: 15,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.23
        )
        productNameLabel.applyWrapping()
        productSubtitleLabel.applyWrapping()
        scoreTitleLabel.applyWrapping()
        scoreSummaryLabel.applyWrapping()
        [
            caloriesValueLabel,
            proteinValueLabel,
            carbsValueLabel,
            fatValueLabel
        ].forEach { $0.applyLineTruncation(lines: 1) }
    }
}
