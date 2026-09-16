import UIKit

final class LogWorkoutViewController: BaseViewController, UITextFieldDelegate {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var typeHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var typeCard: AdaptiveView!
    @IBOutlet private var typeButtons: [UIButton]?
    @IBOutlet private weak var nameHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var nameCard: AdaptiveView!
    @IBOutlet private weak var nameField: UITextField!
    @IBOutlet private weak var dateHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var dateBadgeLabel: AdaptiveLabel!
    @IBOutlet private weak var changeDateButton: UIButton!
    @IBOutlet private weak var durationHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var durationCard: AdaptiveView!
    @IBOutlet private weak var durationPicker: UIDatePicker!
    @IBOutlet private weak var caloriesHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesCard: AdaptiveView!
    @IBOutlet private weak var caloriesField: UITextField!
    @IBOutlet private weak var caloriesUnitLabel: AdaptiveLabel!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!

    private var dateBadgeWidth: NSLayoutConstraint?

    private let viewModel: LogWorkoutViewModel
    private var didApplyDuration = false

    init(viewModel: LogWorkoutViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "LogWorkoutViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .logWorkout }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureChrome()
        saveButton.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -8).isActive = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let field = [nameField, caloriesField].compactMap({ $0 }).first(where: { $0.isFirstResponder }) {
            let rect = field.convert(field.bounds, to: scrollView).insetBy(dx: 0, dy: -24)
            scrollView.scrollRectToVisible(rect, animated: false)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didApplyDuration {
            didApplyDuration = true
            durationPicker.countDownDuration = viewModel.durationSeconds.value
        }
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
        }
        viewModel.selectedTypeIndex.bind { [weak self] index in
            self?.renderTypeChips(selected: index)
        }
        viewModel.nameText.bind { [weak self] value in
            guard let self, !self.nameField.isFirstResponder else { return }
            self.styleField(self.nameField, text: value)
        }
        viewModel.dateText.bind { [weak self] value in
            self?.updateDateBadge(value)
        }
        viewModel.isCaloriesEstimated.bind { [weak self] estimated in
            self?.caloriesUnitLabel.text = estimated
                ? L10n.tr("logWorkout.estimatedUnit") : L10n.tr("logWorkout.kcalUnit")
        }
        viewModel.caloriesText.bind { [weak self] value in
            guard let self, !self.caloriesField.isFirstResponder else { return }
            self.styleField(self.caloriesField, text: value)
        }
        viewModel.errorText.bind { [weak self] message in
            guard let self, !message.isEmpty else { return }
            Haptics.error()
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
            self.present(alert, animated: true)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === nameField {
            viewModel.updateName(textField.text ?? "")
        } else if textField === caloriesField {
            viewModel.finishEditingCalories()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func configureChrome() {
        view.backgroundColor = AppColor.backgroundsPrimary
        scrollView.keyboardDismissMode = .interactive
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.styleBackButton(backButton)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        [typeCard, nameCard, durationCard, caloriesCard].forEach { card in
            card?.layer.cornerRadius = (card === nameCard || card === caloriesCard) ? 16 : 24
            card?.useLiveGlass = false
            card?.cardFillColor = AppColor.backgroundsPrimaryElevated
            card?.applyCardShadow = true
        }
        applySectionHeader(typeHeaderLabel, symbol: "figure.run.treadmill", title: L10n.tr("logWorkout.typeSection"))
        let chips = (typeButtons ?? []).sorted { $0.tag < $1.tag }
        chips.enumerated().forEach { index, button in
            button.tag = index
            button.addTarget(self, action: #selector(typeTapped(_:)), for: .touchUpInside)
        }
        renderTypeChips(selected: viewModel.selectedTypeIndex.value)
        OnboardingStyle.lockFigmaFont(nameHeaderLabel, size: 17, weight: .regular, color: AppColor.labelsSecondary, kern: -0.43)
        nameHeaderLabel.text = L10n.tr("logWorkout.typeField")
        configureField(nameField)
        nameField.keyboardType = .default
        nameField.returnKeyType = .done
        applySectionHeader(dateHeaderLabel, symbol: "calendar", title: L10n.tr("product.entry.logDate"))
        dateBadgeLabel.backgroundColor = AppColor.fillQuaternary
        dateBadgeLabel.layer.cornerRadius = 17
        dateBadgeLabel.layer.masksToBounds = true
        dateBadgeLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(dateBadgeLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        dateBadgeWidth = dateBadgeLabel.widthAnchor.constraint(equalToConstant: 0)
        dateBadgeWidth?.isActive = true
        updateDateBadge(viewModel.dateText.value)
        changeDateButton.setContentHuggingPriority(.required, for: .horizontal)
        OnboardingStyle.styleBorderlessButton(changeDateButton, title: L10n.tr("product.entry.changeDate"))
        changeDateButton.addTarget(self, action: #selector(changeDateTapped), for: .touchUpInside)
        applySectionHeader(durationHeaderLabel, symbol: "clock.arrow.circlepath", title: L10n.tr("logWorkout.duration"))
        durationPicker.datePickerMode = .countDownTimer
        durationPicker.preferredDatePickerStyle = .wheels
        durationPicker.minuteInterval = 1
        durationPicker.tintColor = AppColor.teal
        durationPicker.addTarget(self, action: #selector(durationChanged), for: .valueChanged)
        OnboardingStyle.lockFigmaFont(caloriesHeaderLabel, size: 17, weight: .regular, color: AppColor.labelsSecondary, kern: -0.43)
        caloriesHeaderLabel.text = L10n.tr("logWorkout.calories")
        configureField(caloriesField)
        caloriesField.keyboardType = .decimalPad
        caloriesField.placeholder = "0"
        caloriesField.addTarget(self, action: #selector(caloriesEdited), for: .editingChanged)
        OnboardingStyle.lockFigmaFont(caloriesUnitLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        caloriesUnitLabel.text = viewModel.isCaloriesEstimated.value ? L10n.tr("logWorkout.estimatedUnit") : L10n.tr("logWorkout.kcalUnit")
        OnboardingStyle.stylePrimaryButton(saveButton, title: L10n.tr("common.save"), systemImage: "checkmark")
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

    }

    @objc private func caloriesEdited() {
        viewModel.updateCalories(caloriesField.text ?? "")
    }

    private func configureField(_ field: UITextField) {
        field.delegate = self
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.tintColor = AppColor.teal
        field.font = .systemFont(ofSize: 17, weight: .regular)
        field.textColor = AppColor.labelsPrimary
    }

    private func styleField(_ field: UITextField, text: String) {
        field.defaultTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .regular),
            .foregroundColor: AppColor.labelsPrimary,
            .kern: -0.43
        ]
        field.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: AppColor.labelsPrimary,
                .kern: -0.43
            ]
        )
    }

    private func renderTypeChips(selected: Int) {
        (typeButtons ?? []).sorted { $0.tag < $1.tag }.enumerated().forEach { index, button in
            let type = ExerciseType(rawValue: index) ?? .running
            button.setTitle(nil, for: .normal)
            OnboardingStyle.styleSelectionChip(button, title: type.localizedTitle, selected: index == selected)
            button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.8
        }
    }

    private func updateDateBadge(_ text: String) {
        dateBadgeLabel.text = text
        dateBadgeWidth?.constant = ceil(dateBadgeLabel.intrinsicContentSize.width) + 22
    }

    private func applySectionHeader(_ label: AdaptiveLabel?, symbol: String, title: String) {
        guard let label else { return }
        let image = OnboardingStyle.symbol(symbol, pointSize: 15, weight: .semibold)
        let text = NSMutableAttributedString()
        if let image {
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(AppColor.labelVibrantPrimary, renderingMode: .alwaysOriginal)
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: " "))
        }
        text.append(NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: AppColor.labelVibrantPrimary,
                .kern: -0.23
            ]
        ))
        label.attributedText = text
        label.adaptFontSize = false
    }

    @objc private func backTapped() {
        viewModel.backTapped()
    }

    @objc private func changeDateTapped() {
        viewModel.changeDateTapped()
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        viewModel.updateName(nameField.text ?? "")
        viewModel.updateCalories(caloriesField.text ?? "")
        viewModel.updateDuration(durationPicker.countDownDuration)
        viewModel.saveTapped()
    }

    @objc private func typeTapped(_ sender: UIButton) {
        view.endEditing(true)
        viewModel.selectType(sender.tag)
    }

    @objc private func durationChanged() {
        viewModel.updateDuration(durationPicker.countDownDuration)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}
