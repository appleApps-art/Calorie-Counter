import UIKit

final class BarcodeScannerViewController: BaseViewController {
    @IBOutlet private weak var previewContainerView: UIView!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var productTitleLabel: UILabel!
    @IBOutlet private weak var productDetailsLabel: UILabel!
    @IBOutlet private weak var barcodeTextField: UITextField!
    @IBOutlet private weak var lookupButton: UIButton!
    @IBOutlet private weak var logButton: UIButton!

    private let viewModel: BarcodeFoodLoggingViewModel
    private let scanner: CameraBarcodeScanner
    private var hasStarted = false

    init(viewModel: BarcodeFoodLoggingViewModel, scanner: CameraBarcodeScanner = CameraBarcodeScanner()) {
        self.viewModel = viewModel
        self.scanner = scanner
        super.init(nibName: "BarcodeScannerViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("barcode.title")
        lookupButton.setTitle(L10n.tr("barcode.lookup"), for: .normal)
        logButton.setTitle(L10n.tr("barcode.logSnack"), for: .normal)
        barcodeTextField.placeholder = L10n.tr("barcode.placeholder")
        lookupButton.addTarget(self, action: #selector(lookupTapped), for: .touchUpInside)
        logButton.addTarget(self, action: #selector(logTapped), for: .touchUpInside)
        barcodeTextField.addTarget(self, action: #selector(barcodeChanged), for: .editingChanged)
        barcodeTextField.keyboardType = .numberPad
        scanner.attachPreview(to: previewContainerView)
        scanner.onBarcodeScanned = { [weak self] code in
            self?.handleScannedCode(code)
        }
        scanner.onScanFailed = { [weak self] error in
            self?.viewModel.statusText.value = error.localizedDescription
        }
        logButton.isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scanner.layoutPreview(in: previewContainerView)
        if !hasStarted {
            hasStarted = true
            scanner.startScanning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner.stopScanning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scanner.layoutPreview(in: previewContainerView)
    }

    override func bindViewModel() {
        viewModel.statusText.bind { [weak self] value in
            self?.statusLabel.text = value
        }
        viewModel.productTitleText.bind { [weak self] value in
            self?.productTitleLabel.text = value
        }
        viewModel.productDetailsText.bind { [weak self] value in
            self?.productDetailsLabel.text = value
        }
        viewModel.isLoading.bind { [weak self] isLoading in
            self?.lookupButton.isEnabled = !isLoading
            self?.barcodeTextField.isEnabled = !isLoading
        }
        viewModel.canLogProduct.bind { [weak self] canLog in
            self?.logButton.isEnabled = canLog
        }
    }

    @objc
    private func barcodeChanged() {
        // Keep field in sync for manual entry.
    }

    @objc
    private func lookupTapped() {
        view.endEditing(true)
        viewModel.lookup(barcode: barcodeTextField.text ?? "")
    }

    @objc
    private func logTapped() {
        viewModel.logAsSnackTapped()
    }

    private func handleScannedCode(_ code: String) {
        barcodeTextField.text = code
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        viewModel.lookup(barcode: code)
    }
}
