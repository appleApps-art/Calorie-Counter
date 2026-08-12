import UIKit

final class OnboardingViewController: BaseViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var detailsLabel: UILabel!
    @IBOutlet private weak var goalSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var questionsStackView: UIStackView!
    @IBOutlet private weak var sexSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var activitySegmentedControl: UISegmentedControl!
    @IBOutlet private weak var ageTextField: UITextField!
    @IBOutlet private weak var heightTextField: UITextField!
    @IBOutlet private weak var weightTextField: UITextField!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var nextButton: UIButton!

    private let viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "OnboardingViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureControls()
        viewModel.viewDidLoad()
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
        }
        viewModel.subtitleText.bind { [weak self] value in
            self?.subtitleLabel.text = value
        }
        viewModel.detailsText.bind { [weak self] value in
            self?.detailsLabel.text = value
            self?.detailsLabel.isHidden = value.isEmpty
        }
        viewModel.statusText.bind { [weak self] value in
            self?.statusLabel.text = value
            self?.statusLabel.isHidden = value.isEmpty
        }
        viewModel.nextButtonTitle.bind { [weak self] value in
            self?.nextButton.setTitle(value, for: .normal)
        }
        viewModel.canAdvance.bind { [weak self] canAdvance in
            self?.nextButton.isEnabled = canAdvance
        }
        viewModel.showsBack.bind { [weak self] shows in
            self?.backButton.isHidden = !shows
        }
        viewModel.showsGoalPicker.bind { [weak self] shows in
            self?.goalSegmentedControl.isHidden = !shows
        }
        viewModel.showsQuestions.bind { [weak self] shows in
            self?.questionsStackView.isHidden = !shows
        }
        viewModel.profile.bind { [weak self] profile in
            self?.syncInputs(from: profile)
        }
    }

    private func configureControls() {
        backButton.setTitle(L10n.tr("common.back"), for: .normal)
        ageTextField.placeholder = L10n.tr("onboarding.placeholder.age")
        heightTextField.placeholder = L10n.tr("onboarding.placeholder.height")
        weightTextField.placeholder = L10n.tr("onboarding.placeholder.weight")
        ageTextField.keyboardType = .numberPad
        heightTextField.keyboardType = .decimalPad
        weightTextField.keyboardType = .decimalPad

        fill(goalSegmentedControl, titles: GoalType.allCases.map(\.localizedTitle))
        fill(sexSegmentedControl, titles: BiologicalSex.allCases.map(\.localizedTitle))
        fill(activitySegmentedControl, titles: ActivityLevel.allCases.map(\.localizedTitle))

        goalSegmentedControl.addTarget(self, action: #selector(goalChanged), for: .valueChanged)
        sexSegmentedControl.addTarget(self, action: #selector(sexChanged), for: .valueChanged)
        activitySegmentedControl.addTarget(self, action: #selector(activityChanged), for: .valueChanged)
        ageTextField.addTarget(self, action: #selector(ageChanged), for: .editingDidEnd)
        heightTextField.addTarget(self, action: #selector(heightChanged), for: .editingDidEnd)
        weightTextField.addTarget(self, action: #selector(weightChanged), for: .editingDidEnd)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
    }

    private func fill(_ control: UISegmentedControl, titles: [String]) {
        control.removeAllSegments()
        titles.enumerated().forEach { index, title in
            control.insertSegment(withTitle: title, at: index, animated: false)
        }
        control.selectedSegmentIndex = UISegmentedControl.noSegment
    }

    private func syncInputs(from profile: UserProfile) {
        if let goal = profile.goalType, let index = GoalType.allCases.firstIndex(of: goal) {
            goalSegmentedControl.selectedSegmentIndex = index
        } else {
            goalSegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        }
        if let sex = profile.sex, let index = BiologicalSex.allCases.firstIndex(of: sex) {
            sexSegmentedControl.selectedSegmentIndex = index
        } else {
            sexSegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        }
        if let activity = profile.activityLevel, let index = ActivityLevel.allCases.firstIndex(of: activity) {
            activitySegmentedControl.selectedSegmentIndex = index
        } else {
            activitySegmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
        }
        setText(ageTextField, profile.age.map(String.init) ?? "")
        setText(heightTextField, numberText(profile.heightCm))
        setText(weightTextField, numberText(profile.weightKg))
    }

    private func setText(_ field: UITextField, _ value: String) {
        if field.text != value {
            field.text = value
        }
    }

    private func numberText(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(Int(value.rounded()))
    }

    @objc
    private func goalChanged() {
        let index = goalSegmentedControl.selectedSegmentIndex
        guard GoalType.allCases.indices.contains(index) else { return }
        viewModel.setGoal(GoalType.allCases[index])
    }

    @objc
    private func sexChanged() {
        let index = sexSegmentedControl.selectedSegmentIndex
        guard BiologicalSex.allCases.indices.contains(index) else { return }
        viewModel.setSex(BiologicalSex.allCases[index])
    }

    @objc
    private func activityChanged() {
        let index = activitySegmentedControl.selectedSegmentIndex
        guard ActivityLevel.allCases.indices.contains(index) else { return }
        viewModel.setActivity(ActivityLevel.allCases[index])
    }

    @objc
    private func ageChanged() {
        guard let age = Int(ageTextField.text ?? "") else { return }
        viewModel.setAge(age)
    }

    @objc
    private func heightChanged() {
        guard let height = Double(heightTextField.text ?? "") else { return }
        viewModel.setHeight(height)
    }

    @objc
    private func weightChanged() {
        guard let weight = Double(weightTextField.text ?? "") else { return }
        viewModel.setWeight(weight)
    }

    @objc
    private func backTapped() {
        view.endEditing(true)
        viewModel.back()
    }

    @objc
    private func nextTapped() {
        view.endEditing(true)
        viewModel.advance()
    }
}
