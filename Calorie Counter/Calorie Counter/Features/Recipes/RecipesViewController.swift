import UIKit

final class RecipesViewController: BaseViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var modeSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var searchButton: UIButton!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var resultsLabel: UILabel!
    @IBOutlet private weak var tableView: UITableView!

    private let viewModel: RecipesViewModel

    init(viewModel: RecipesViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "RecipesViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        modeSegmentedControl.setTitle(L10n.tr("recipes.title"), forSegmentAt: 0)
        modeSegmentedControl.setTitle(L10n.tr("recipes.foods"), forSegmentAt: 1)
        searchTextField.placeholder = L10n.tr("common.search")
        searchButton.setTitle(L10n.tr("common.search"), for: .normal)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        searchTextField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        modeSegmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        viewModel.viewDidLoad()
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
        }
        viewModel.statusText.bind { [weak self] value in
            self?.statusLabel.text = value
        }
        viewModel.resultsText.bind { [weak self] value in
            self?.resultsLabel.text = value
        }
        viewModel.items.bind { [weak self] _ in
            self?.tableView.reloadData()
        }
        viewModel.isLoading.bind { [weak self] isLoading in
            self?.searchButton.isEnabled = !isLoading
            self?.searchTextField.isEnabled = !isLoading
        }
        viewModel.searchMode.bind { [weak self] mode in
            self?.modeSegmentedControl.selectedSegmentIndex = mode.rawValue
        }
    }

    @objc
    private func searchChanged() {
        viewModel.updateSearchQuery(searchTextField.text ?? "")
    }

    @objc
    private func searchTapped() {
        view.endEditing(true)
        viewModel.updateSearchQuery(searchTextField.text ?? "")
        viewModel.searchTapped()
    }

    @objc
    private func modeChanged() {
        viewModel.searchModeChanged(modeSegmentedControl.selectedSegmentIndex)
    }
}

extension RecipesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = viewModel.items.value[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.secondaryText = item.subtitle
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.selectItem(at: indexPath.row)
    }
}
