import UIKit

final class TextFoodLoggingViewController: BaseViewController {
    @IBOutlet private weak var inputTextView: UITextView!
    @IBOutlet private weak var mealSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var analyzeButton: UIButton!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var resultCardView: UIView!
    @IBOutlet private weak var resultTitleLabel: UILabel!
    @IBOutlet private weak var resultDetailsLabel: UILabel!
    @IBOutlet private weak var confidenceLabel: UILabel!
    @IBOutlet private weak var editStackView: UIStackView!
    @IBOutlet private weak var nameTextField: UITextField!
    @IBOutlet private weak var caloriesTextField: UITextField!
    @IBOutlet private weak var proteinTextField: UITextField!
    @IBOutlet private weak var carbsTextField: UITextField!
    @IBOutlet private weak var fatsTextField: UITextField!
    @IBOutlet private weak var editDetailsButton: UIButton!
    @IBOutlet private weak var confirmButton: UIButton!

    private let viewModel: TextFoodLoggingViewModel

    init(viewModel: TextFoodLoggingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "TextFoodLoggingViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("textLog.title")
        inputTextView.delegate = self
        inputTextView.layer.cornerRadius = .adaptWidth(12)
        mealSegmentedControl.removeAllSegments()
        MealType.allCases.enumerated().forEach { index, meal in
            mealSegmentedControl.insertSegment(withTitle: meal.localizedTitle, at: index, animated: false)
        }
        mealSegmentedControl.selectedSegmentIndex = viewModel.mealTypeIndex.value
        mealSegmentedControl.addTarget(self, action: #selector(mealChanged), for: .valueChanged)
        analyzeButton.setTitle(L10n.tr("textLog.analyze"), for: .normal)
        confirmButton.setTitle(L10n.tr("textLog.confirmLog"), for: .normal)
        nameTextField.placeholder = L10n.tr("textLog.placeholderName")
        caloriesTextField.placeholder = L10n.tr("textLog.placeholderCalories")
        proteinTextField.placeholder = L10n.tr("textLog.placeholderProtein")
        carbsTextField.placeholder = L10n.tr("textLog.placeholderCarbs")
        fatsTextField.placeholder = L10n.tr("textLog.placeholderFats")
        analyzeButton.addTarget(self, action: #selector(analyzeTapped), for: .touchUpInside)
        editDetailsButton.addTarget(self, action: #selector(editDetailsTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        caloriesTextField.addTarget(self, action: #selector(caloriesChanged), for: .editingChanged)
        proteinTextField.addTarget(self, action: #selector(proteinChanged), for: .editingChanged)
        carbsTextField.addTarget(self, action: #selector(carbsChanged), for: .editingChanged)
        fatsTextField.addTarget(self, action: #selector(fatsChanged), for: .editingChanged)
        [caloriesTextField, proteinTextField, carbsTextField, fatsTextField].forEach {
            $0?.keyboardType = .decimalPad
        }
        resultCardView.isHidden = true
        editStackView.isHidden = true
        confirmButton.isEnabled = false
        analyzeButton.isEnabled = false
    }

    override func bindViewModel() {
        viewModel.statusText.bind { [weak self] value in
            self?.statusLabel.text = value
        }
        viewModel.resultTitleText.bind { [weak self] value in
            self?.resultTitleLabel.text = value
        }
        viewModel.resultDetailsText.bind { [weak self] value in
            self?.resultDetailsLabel.text = value
        }
        viewModel.confidenceText.bind { [weak self] value in
            self?.confidenceLabel.text = value
        }
        viewModel.isAnalyzing.bind { [weak self] isAnalyzing in
            self?.analyzeButton.isEnabled = !isAnalyzing && (self?.viewModel.canAnalyze.value ?? false)
            self?.inputTextView.isEditable = !isAnalyzing
            self?.mealSegmentedControl.isEnabled = !isAnalyzing
        }
        viewModel.canAnalyze.bind { [weak self] canAnalyze in
            let analyzing = self?.viewModel.isAnalyzing.value ?? false
            self?.analyzeButton.isEnabled = canAnalyze && !analyzing
        }
        viewModel.canConfirmLog.bind { [weak self] canConfirm in
            self?.confirmButton.isEnabled = canConfirm
        }
        viewModel.showsResultCard.bind { [weak self] shows in
            self?.resultCardView.isHidden = !shows
        }
        viewModel.isEditingDetails.bind { [weak self] isEditing in
            self?.editStackView.isHidden = !isEditing
            self?.resultDetailsLabel.isHidden = isEditing
            self?.editDetailsButton.setTitle(isEditing ? L10n.tr("textLog.editing") : L10n.tr("textLog.editDetails"), for: .normal)
            self?.editDetailsButton.isEnabled = !isEditing
        }
        viewModel.draftName.bind { [weak self] value in
            if self?.nameTextField.text != value {
                self?.nameTextField.text = value
            }
        }
        viewModel.draftCalories.bind { [weak self] value in
            if self?.caloriesTextField.text != value {
                self?.caloriesTextField.text = value
            }
        }
        viewModel.draftProtein.bind { [weak self] value in
            if self?.proteinTextField.text != value {
                self?.proteinTextField.text = value
            }
        }
        viewModel.draftCarbs.bind { [weak self] value in
            if self?.carbsTextField.text != value {
                self?.carbsTextField.text = value
            }
        }
        viewModel.draftFats.bind { [weak self] value in
            if self?.fatsTextField.text != value {
                self?.fatsTextField.text = value
            }
        }
        viewModel.mealTypeIndex.bind { [weak self] index in
            if self?.mealSegmentedControl.selectedSegmentIndex != index {
                self?.mealSegmentedControl.selectedSegmentIndex = index
            }
        }
    }

    @objc
    private func mealChanged() {
        viewModel.updateMealTypeIndex(mealSegmentedControl.selectedSegmentIndex)
    }

    @objc
    private func analyzeTapped() {
        view.endEditing(true)
        viewModel.analyzeTapped()
    }

    @objc
    private func editDetailsTapped() {
        viewModel.editDetailsTapped()
    }

    @objc
    private func confirmTapped() {
        view.endEditing(true)
        viewModel.confirmLogTapped()
    }

    @objc
    private func nameChanged() {
        viewModel.updateDraftName(nameTextField.text ?? "")
    }

    @objc
    private func caloriesChanged() {
        viewModel.updateDraftCalories(caloriesTextField.text ?? "")
    }

    @objc
    private func proteinChanged() {
        viewModel.updateDraftProtein(proteinTextField.text ?? "")
    }

    @objc
    private func carbsChanged() {
        viewModel.updateDraftCarbs(carbsTextField.text ?? "")
    }

    @objc
    private func fatsChanged() {
        viewModel.updateDraftFats(fatsTextField.text ?? "")
    }
}

extension TextFoodLoggingViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.updateInputText(textView.text ?? "")
    }
}
