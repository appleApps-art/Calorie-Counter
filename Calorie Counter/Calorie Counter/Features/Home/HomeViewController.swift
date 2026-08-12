import UIKit

final class HomeViewController: BaseViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var summaryLabel: UILabel!
    @IBOutlet private weak var caloriesLabel: UILabel!
    @IBOutlet private weak var entriesLabel: UILabel!
    @IBOutlet private weak var scanBarcodeButton: UIButton!
    @IBOutlet private weak var logByTextButton: UIButton!

    private let viewModel: HomeViewModel
    private let onScanBarcode: () -> Void
    private let onLogByText: () -> Void

    init(
        viewModel: HomeViewModel,
        onScanBarcode: @escaping () -> Void,
        onLogByText: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onScanBarcode = onScanBarcode
        self.onLogByText = onLogByText
        super.init(nibName: "HomeViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scanBarcodeButton.setTitle(L10n.tr("home.scanBarcode"), for: .normal)
        logByTextButton.setTitle(L10n.tr("home.logByText"), for: .normal)
        scanBarcodeButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        logByTextButton.addTarget(self, action: #selector(logByTextTapped), for: .touchUpInside)
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.reload()
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
        }
        viewModel.summaryText.bind { [weak self] value in
            self?.summaryLabel.text = value
        }
        viewModel.caloriesText.bind { [weak self] value in
            self?.caloriesLabel.text = value
        }
        viewModel.entriesCountText.bind { [weak self] value in
            self?.entriesLabel.text = value
        }
    }

    @objc
    private func scanTapped() {
        onScanBarcode()
    }

    @objc
    private func logByTextTapped() {
        onLogByText()
    }
}
