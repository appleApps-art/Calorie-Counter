import UIKit

final class RecipeDetailViewController: BaseViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var summaryLabel: UILabel!
    @IBOutlet private weak var nutritionLabel: UILabel!
    @IBOutlet private weak var ingredientsLabel: UILabel!
    @IBOutlet private weak var stepsLabel: UILabel!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var replaceButton: UIButton!

    let viewModel: RecipeDetailViewModel

    init(viewModel: RecipeDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "RecipeDetailViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        saveButton.setTitle(L10n.tr("common.save"), for: .normal)
        replaceButton.setTitle(L10n.tr("recipes.replaceButton"), for: .normal)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        replaceButton.addTarget(self, action: #selector(replaceTapped), for: .touchUpInside)
        viewModel.viewDidLoad()
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
            self?.title = value
        }
        viewModel.summaryText.bind { [weak self] value in
            self?.summaryLabel.text = value
        }
        viewModel.nutritionText.bind { [weak self] value in
            self?.nutritionLabel.text = value
        }
        viewModel.ingredientsText.bind { [weak self] value in
            self?.ingredientsLabel.text = value
        }
        viewModel.stepsText.bind { [weak self] value in
            self?.stepsLabel.text = value
        }
        viewModel.statusText.bind { [weak self] value in
            self?.statusLabel.text = value
        }
        viewModel.saveButtonTitle.bind { [weak self] value in
            self?.saveButton.setTitle(value, for: .normal)
        }
        viewModel.isLoading.bind { [weak self] isLoading in
            self?.saveButton.isEnabled = !isLoading
            self?.replaceButton.isEnabled = !isLoading
        }
        viewModel.pendingConfirmText.bind { [weak self] message in
            guard let self, let message else { return }
            self.presentConfirmAlert(message: message)
        }
    }

    @objc
    private func saveTapped() {
        viewModel.saveTapped()
    }

    @objc
    private func replaceTapped() {
        viewModel.replaceIngredientTapped()
    }

    private func presentConfirmAlert(message: String) {
        let alert = UIAlertController(title: L10n.tr("recipes.applySwapTitle"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("common.cancel"), style: .cancel) { [weak self] _ in
            self?.viewModel.rejectPendingSwap()
        })
        alert.addAction(UIAlertAction(title: L10n.tr("common.confirm"), style: .default) { [weak self] _ in
            self?.viewModel.confirmPendingSwap()
        })
        present(alert, animated: true)
    }
}
