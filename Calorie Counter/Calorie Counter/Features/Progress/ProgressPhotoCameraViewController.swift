import PhotosUI
import UIKit

final class ProgressPhotoCameraViewController: BaseViewController, PHPickerViewControllerDelegate {
    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var flashButton: UIButton!
    @IBOutlet private weak var stepCard: AdaptiveView!
    @IBOutlet private weak var stepLabel: AdaptiveLabel!
    @IBOutlet private weak var galleryButton: UIButton!
    @IBOutlet private weak var shutterButton: UIButton!
    @IBOutlet private weak var shutterDiscView: UIView!

    private let viewModel: ProgressPhotoCameraViewModel
    private let capturer: FoodPhotoCapturing
    private var isTorchOn = false
    private var hasStarted = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    init(
        viewModel: ProgressPhotoCameraViewModel,
        capturer: FoodPhotoCapturing = CameraFoodPhotoCapturer()
    ) {
        self.viewModel = viewModel
        self.capturer = capturer
        super.init(nibName: "ProgressPhotoCameraViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .progressPhoto }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationItem.largeTitleDisplayMode = .never
        configureChrome()
        capturer.attachPreview(to: previewView)
        capturer.onPhotoCaptured = { [weak self] data in
            self?.viewModel.saveCapturedData(data)
        }
        capturer.onCaptureFailed = { [weak self] error in
            self?.viewModel.captureFailed(error)
        }
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
        shutterButton.layer.cornerRadius = shutterButton.bounds.height / 2
        shutterButton.layer.cornerCurve = .continuous
        shutterDiscView.layer.cornerRadius = shutterDiscView.bounds.height / 2
        shutterDiscView.layer.cornerCurve = .continuous
        if let wrap = shutterButton.superview {
            wrap.layer.cornerRadius = wrap.bounds.height / 2
            wrap.layer.cornerCurve = .continuous
            wrap.layer.borderColor = UIColor.white.cgColor
            view.bringSubviewToFront(wrap)
            view.bringSubviewToFront(galleryButton)
        }
    }

    override func bindViewModel() {
        viewModel.stepText.bind { [weak self] value in
            guard let self else { return }
            self.stepLabel.text = value
            OnboardingStyle.lockFigmaFont(self.stepLabel, size: 17, weight: .regular, color: .white, kern: -0.43)
        }
        viewModel.shutterHintText.bind { [weak self] value in
            self?.shutterButton.accessibilityHint = value
        }
        viewModel.isBusy.bind { [weak self] busy in
            self?.shutterButton.isEnabled = !busy
            self?.galleryButton.isEnabled = !busy
        }
        viewModel.errorText.bind { [weak self] message in
            guard let self, !message.isEmpty else { return }
            Haptics.error()
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
            self.present(alert, animated: true)
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.9) else { return }
            DispatchQueue.main.async {
                self?.viewModel.saveCapturedData(data)
            }
        }
    }

    private func configureChrome() {
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
        stepCard.useLiveGlass = false
        stepCard.applyCardShadow = false
        stepCard.applyButtonGlass = false
        stepCard.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        stepLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(stepLabel, size: 17, weight: .regular, color: .white, kern: -0.43)
        configureShutterButton()
        shutterButton.accessibilityLabel = L10n.tr("progressPhoto.shutter")
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        shutterButton.controlHaptic = .none
    }

    private func configureShutterButton() {
        shutterButton.configuration = nil
        shutterButton.setTitle(nil, for: .normal)
        shutterButton.setImage(nil, for: .normal)
        shutterButton.backgroundColor = .clear
        shutterButton.tintColor = .clear
        shutterButton.clipsToBounds = true
        shutterButton.layer.borderWidth = 0
        shutterDiscView.backgroundColor = .white
        shutterDiscView.isUserInteractionEnabled = false
        shutterDiscView.layer.masksToBounds = true
        guard let wrap = shutterButton.superview else { return }
        wrap.backgroundColor = .clear
        wrap.layer.borderWidth = 4
        wrap.layer.borderColor = UIColor.white.cgColor
        wrap.clipsToBounds = false
        wrap.bringSubviewToFront(shutterDiscView)
        view.bringSubviewToFront(wrap)
        view.bringSubviewToFront(galleryButton)
    }

    private func styleFlashButton() {
        OnboardingStyle.styleGlassSymbolButton(
            flashButton,
            systemName: "flashlight.on.fill",
            foregroundColor: isTorchOn ? AppColor.teal : .white
        )
    }

    @objc private func closeTapped() {
        viewModel.closeTapped()
    }

    @objc private func flashTapped() {
        isTorchOn.toggle()
        capturer.setTorchOn(isTorchOn)
        styleFlashButton()
    }

    @objc private func galleryTapped() {
        guard !viewModel.isBusy.value else { return }
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func shutterTapped() {
        guard !viewModel.isBusy.value else { return }
        Haptics.rigid()
        capturer.captureFullFramePhoto()
    }
}
