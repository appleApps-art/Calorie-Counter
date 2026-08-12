import UIKit

final class FoodProductDetailViewController: BaseViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var detailsLabel: UILabel!
    @IBOutlet private weak var statusLabel: UILabel!

    private let viewModel: FoodProductDetailViewModel

    init(viewModel: FoodProductDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "FoodProductDetailViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.viewDidLoad()
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
            self?.title = value
        }
        viewModel.detailsText.bind { [weak self] value in
            self?.detailsLabel.text = value
        }
        viewModel.statusText.bind { [weak self] value in
            self?.statusLabel.text = value
        }
    }
}
