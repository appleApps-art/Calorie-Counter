import UIKit

final class SettingsViewController: BaseViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!

    private let viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "SettingsViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
        viewModel.subtitleText.bind { [weak self] value in
            self?.subtitleLabel.text = value
        }
    }
}
