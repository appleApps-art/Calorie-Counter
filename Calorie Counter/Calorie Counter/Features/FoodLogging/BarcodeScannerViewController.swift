import PhotosUI
import UIKit
import Vision

final class BarcodeScannerViewController: BaseViewController, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    @IBOutlet private weak var previewView: UIView!
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
    @IBOutlet private weak var enterManuallyButton: UIButton!
    @IBOutlet private weak var galleryButton: UIButton!
    @IBOutlet private weak var shutterButton: UIButton!
    @IBOutlet private weak var shutterDiscView: UIView!
    @IBOutlet private weak var modeControl: UISegmentedControl!

    private let viewModel: BarcodeFoodLoggingViewModel
    private let scanner: CameraBarcodeScanner
    private let showsFreeScanQuota: Bool
    private var isTorchOn = false
    private let frameCornerRadius: CGFloat = 26
    private var lastLayoutSize: CGSize = .zero

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init(
        viewModel: BarcodeFoodLoggingViewModel,
        scanner: CameraBarcodeScanner = CameraBarcodeScanner(),
        showsFreeScanQuota: Bool = true
    ) {
        self.viewModel = viewModel
        self.scanner = scanner
        self.showsFreeScanQuota = showsFreeScanQuota
        super.init(nibName: "BarcodeScannerViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .barcodeScanner }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationItem.largeTitleDisplayMode = .never
        configureCameraChrome()
        scanner.attachPreview(to: previewView)
        previewView.bringSubviewToFront(overlayView)
        scanner.onBarcodeScanned = { [weak self] code in
            self?.handleScannedCode(code)
        }
        scanner.onScanFailed = { [weak self] error in
            self?.viewModel.captureFailed(error)
        }
        scanner.onStillPhotoCaptured = { [weak self] data in
            self?.handleCapturedPhoto(data)
        }
        overlayView.isUserInteractionEnabled = false
        hintBar.isUserInteractionEnabled = false
        applyPhase(viewModel.phase.value)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.resumeIdleIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scanner.layoutPreview(in: previewView)
        scanner.startScanning()
        updateInterestRect()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            scanner.stopScanning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scanner.layoutPreview(in: previewView)
        let radius = CGFloat.adaptWidth(frameCornerRadius)
        if abs(frameView.frameCornerRadius - radius) > 0.5 {
            frameView.frameCornerRadius = radius
            overlayView.holeCornerRadius = radius
        }
        let hole = overlayView.convert(frameView.bounds, from: frameView)
        if overlayView.holeRect != hole {
            overlayView.holeRect = hole
            updateInterestRect()
        }
        layoutShutterButton()
        if view.bounds.size != lastLayoutSize {
            lastLayoutSize = view.bounds.size
            modeControl.shrinkCameraModeTitlesToFit()
        }
    }

    override func bindViewModel() {
        viewModel.phase.bind { [weak self] phase in
            self?.applyPhase(phase)
        }
        viewModel.statusText.bind { [weak self] value in
            guard let self else { return }
            if self.viewModel.phase.value == .idle {
                if value == L10n.tr("barcode.camera.hint")
                    || value == L10n.tr("barcode.camera.identifying")
                    || value == L10n.tr("barcode.camera.recognized") {
                    self.hintLabel.text = L10n.tr("barcode.camera.hint")
                } else {
                    self.hintLabel.text = value
                }
                OnboardingStyle.lockFigmaFont(self.hintLabel, size: 17, weight: .regular, color: .white, kern: -0.43)
                self.updateShutterAndHint(phase: .idle)
            }
        }
    }

    @objc
    private func closeTapped() {
        viewModel.closeTapped()
    }

    @objc
    private func shutterTapped() {
        guard viewModel.phase.value == .idle else { return }
        let frame = previewView.convert(frameView.bounds, from: frameView)
        viewModel.beginCapture()
        scanner.captureStillPhoto(scanFrameInPreview: frame)
    }

    @objc
    private func shutterPressed() {
        UIView.animate(withDuration: 0.12) {
            self.shutterDiscView.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        }
    }

    @objc
    private func shutterReleased() {
        UIView.animate(withDuration: 0.18) {
            self.shutterDiscView.transform = .identity
        }
    }

    @objc
    private func flashTapped() {
        isTorchOn.toggle()
        scanner.setTorchOn(isTorchOn)
        styleFlashButton()
    }

    @objc
    private func galleryTapped() {
        guard viewModel.phase.value == .idle else { return }
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc
    private func enterManuallyTapped() {
        guard viewModel.phase.value == .idle else { return }
        scanner.setAcceptsScans(false)
        let sheet = BarcodeManualEntryViewController()
        sheet.modalPresentationStyle = .pageSheet
        if let presentation = sheet.sheetPresentationController {
            let compact = UISheetPresentationController.Detent.Identifier("barcodeManual")
            let keyboard = UISheetPresentationController.Detent.Identifier("barcodeManualKeyboard")
            presentation.detents = [
                .custom(identifier: compact) { [weak presentation] context in
                    presentation?.inspectorDetentHeight(305, maximumHeight: context.maximumDetentValue)
                        ?? min(305, context.maximumDetentValue)
                },
                .custom(identifier: keyboard) { [weak presentation] context in
                    presentation?.inspectorDetentHeight(592, maximumHeight: context.maximumDetentValue)
                        ?? min(592, context.maximumDetentValue)
                }
            ]
            presentation.selectedDetentIdentifier = keyboard
            presentation.prefersGrabberVisible = true
            presentation.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        sheet.onClose = { [weak self, weak sheet] in
            sheet?.dismiss(animated: true) {
                self?.scanner.setAcceptsScans(self?.viewModel.phase.value == .idle)
            }
        }
        sheet.onLookup = { [weak self, weak sheet] code in
            self?.viewModel.lookup(barcode: code)
            sheet?.dismiss(animated: true)
        }
        sheet.onKeyboardFocusChanged = { [weak sheet] focused in
            guard let presentation = sheet?.sheetPresentationController else { return }
            let identifier = UISheetPresentationController.Detent.Identifier(
                focused ? "barcodeManualKeyboard" : "barcodeManual"
            )
            presentation.animateChanges {
                presentation.selectedDetentIdentifier = identifier
            }
        }
        sheet.presentationController?.delegate = self
        present(sheet, animated: true)
    }

    @objc
    private func modeChanged() {
        switch modeControl.selectedSegmentIndex {
        case 0:
            viewModel.switchMode(.scanFood)
        case 2:
            viewModel.switchMode(.search)
        case 3:
            viewModel.switchMode(.voiceLog)
        default:
            break
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.handlePickedImage(image)
            }
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        scanner.setAcceptsScans(viewModel.phase.value == .idle)
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
        OnboardingStyle.styleGlassButton(
            enterManuallyButton,
            title: L10n.tr("barcode.camera.enterManually"),
            foregroundColor: .white
        )
        enterManuallyButton.addTarget(self, action: #selector(enterManuallyTapped), for: .touchUpInside)
        enterManuallyButton.setContentHuggingPriority(.required, for: .horizontal)
        enterManuallyButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        if var config = enterManuallyButton.configuration {
            config.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 72, bottom: 13, trailing: 72)
            enterManuallyButton.configuration = config
        }

        tooltipView.useLiveGlass = false
        tooltipView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        tooltipView.isHidden = !showsFreeScanQuota
        tooltipLabel.text = L10n.tr("photo.camera.freeScans")
        tooltipLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(tooltipLabel, size: 15, weight: .regular, color: .white, kern: -0.23)

        hintBar.useLiveGlass = false
        hintBar.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        hintLabel.textColor = .white
        hintSpinner.color = .white
        hintSpinner.hidesWhenStopped = true
        hintIconView.tintColor = .white
        hintIconView.contentMode = .scaleAspectFit

        modeControl.configureCameraModes(titles: CameraModeChrome.titles, selectedIndex: 1)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
    }

    private func styleFlashButton() {
        OnboardingStyle.styleGlassSymbolButton(
            flashButton,
            systemName: "flashlight.on.fill",
            foregroundColor: isTorchOn ? AppColor.teal : .white
        )
    }

    private func applyPhase(_ phase: BarcodeCameraPhase) {
        let isTeal = phase != .idle
        frameView.strokeColor = isTeal ? AppColor.teal : .white
        let idle = phase == .idle
        modeControl.isEnabled = idle
        galleryButton.isEnabled = idle
        enterManuallyButton.isEnabled = idle
        shutterButton.isEnabled = idle
        scanner.setAcceptsScans(idle)
        updateShutterAndHint(phase: phase)

        switch phase {
        case .idle:
            scanLineView.stopAnimating()
            hintSpinner.stopAnimating()
            hintIconView.isHidden = false
            hintIconView.image = OnboardingStyle.symbol("viewfinder", pointSize: 17)
            if viewModel.statusText.value == L10n.tr("barcode.camera.hint")
                || viewModel.statusText.value == L10n.tr("barcode.camera.identifying")
                || viewModel.statusText.value == L10n.tr("barcode.camera.recognized") {
                hintLabel.text = L10n.tr("barcode.camera.hint")
            } else {
                hintLabel.text = viewModel.statusText.value
            }
        case .identifying:
            hintIconView.isHidden = true
            hintSpinner.startAnimating()
            hintLabel.text = L10n.tr("barcode.camera.identifying")
            scanLineView.startAnimating()
        case .recognized:
            scanLineView.stopAnimating()
            hintSpinner.stopAnimating()
            hintIconView.isHidden = false
            hintIconView.image = OnboardingStyle.symbol("checkmark", pointSize: 17)
            hintLabel.text = L10n.tr("barcode.camera.recognized")
        }

        OnboardingStyle.lockFigmaFont(hintLabel, size: 17, weight: .regular, color: .white, kern: -0.43)
    }

    private func handleScannedCode(_ code: String) {
        Haptics.success()
        viewModel.lookup(barcode: code)
    }

    private func handlePickedImage(_ image: UIImage) {
        guard let code = firstBarcode(in: image) else {
            Haptics.error()
            viewModel.showIdleMessage(L10n.tr("barcode.error.invalid"))
            return
        }
        handleScannedCode(code)
    }

    private func handleCapturedPhoto(_ data: Data) {
        guard let image = UIImage(data: data) else {
            viewModel.showIdleMessage(L10n.tr("barcode.error.invalid"))
            return
        }
        handlePickedImage(image)
    }

    private func configureShutterButton() {
        shutterButton.configuration = nil
        shutterButton.setTitle(nil, for: .normal)
        shutterButton.setImage(nil, for: .normal)
        shutterButton.setBackgroundImage(nil, for: .normal)
        shutterButton.backgroundColor = .clear
        shutterButton.tintColor = .clear
        shutterButton.clipsToBounds = false
        shutterButton.layer.borderWidth = 0
        shutterButton.adjustsImageWhenHighlighted = false
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
        wrap.layer.masksToBounds = false
        wrap.setContentCompressionResistancePriority(.required, for: .vertical)
        wrap.setContentHuggingPriority(.required, for: .vertical)
        wrap.bringSubviewToFront(shutterDiscView)
    }

    private func layoutShutterButton() {
        let wrapSide = shutterButton.superview?.bounds.width ?? shutterButton.bounds.width
        let discSide = shutterDiscView.bounds.width
        shutterButton.layer.cornerRadius = wrapSide / 2
        shutterButton.layer.cornerCurve = .continuous
        shutterDiscView.layer.cornerRadius = discSide / 2
        shutterDiscView.layer.cornerCurve = .continuous
        guard let wrap = shutterButton.superview else { return }
        wrap.layer.cornerRadius = wrap.bounds.width / 2
        wrap.layer.cornerCurve = .continuous
        wrap.layer.borderWidth = 4
        wrap.layer.borderColor = UIColor.white.cgColor
        wrap.bringSubviewToFront(shutterDiscView)
    }

    private func updateShutterAndHint(phase: BarcodeCameraPhase) {
        let showShutter = phase == .idle
        let wrap = shutterButton.superview
        wrap?.isHidden = !showShutter
        wrap?.isUserInteractionEnabled = showShutter
        shutterButton.isUserInteractionEnabled = showShutter
        wrap?.alpha = showShutter ? 1 : 0
        let hintKey = L10n.tr("barcode.camera.hint")
        let hasError = phase == .idle
            && viewModel.statusText.value != hintKey
            && viewModel.statusText.value != L10n.tr("barcode.camera.identifying")
            && viewModel.statusText.value != L10n.tr("barcode.camera.recognized")
        let showHint = phase != .idle || hasError
        hintBar.isHidden = !showHint
        hintBar.alpha = showHint ? 1 : 0
    }

    private func firstBarcode(in image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let orientations: [CGImagePropertyOrientation] = [
            cgImageOrientation(from: image.imageOrientation),
            .up,
            .right,
            .down,
            .left
        ]
        for orientation in orientations {
            let request = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            guard (try? handler.perform([request])) != nil else { continue }
            if let code = request.results?
                .compactMap(\.payloadStringValue)
                .first(where: { !$0.isEmpty }) {
                return code
            }
        }
        return nil
    }

    private func cgImageOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private func updateInterestRect() {
        let rect = previewView.convert(frameView.bounds, from: frameView)
        scanner.updateInterestRect(rect)
    }
}
