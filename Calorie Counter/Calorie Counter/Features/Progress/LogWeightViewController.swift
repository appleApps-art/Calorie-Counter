import UIKit

final class LogWeightViewController: BaseViewController, UITextFieldDelegate {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var sectionHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var unitSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var weightCard: AdaptiveView!
    @IBOutlet private weak var valueField: UITextField!
    @IBOutlet private weak var valueFieldWidth: NSLayoutConstraint!
    @IBOutlet private weak var unitLabel: AdaptiveLabel!
    @IBOutlet private weak var slider: UISlider!
    @IBOutlet private weak var ticksView: UIStackView!
    @IBOutlet private weak var dateHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var dateBadgeLabel: AdaptiveLabel!
    @IBOutlet private weak var changeDateButton: UIButton!
    @IBOutlet private weak var saveButton: UIButton!

    private var dateBadgeWidth: NSLayoutConstraint?

    private let viewModel: LogWeightViewModel
    private var lastHapticStep: Int?
    private var isApplyingSlider = false

    init(viewModel: LogWeightViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "LogWeightViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .logWeight }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureChrome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
        }
        viewModel.sectionTitleText.bind { [weak self] value in
            self?.applySectionHeader(self?.sectionHeaderLabel, symbol: "chart.xyaxis.line", title: value)
        }
        viewModel.unitIndex.bind { [weak self] index in
            self?.unitSegmentedControl.selectedSegmentIndex = index
        }
        viewModel.displayValueText.bind { [weak self] value in
            guard let self, !self.valueField.isFirstResponder else { return }
            self.valueField.text = value
            self.updateWeightFieldWidth()
        }
        viewModel.unitLabelText.bind { [weak self] value in
            self?.unitLabel.text = value
        }
        viewModel.sliderMinimum.bind { [weak self] value in
            self?.slider.minimumValue = value
        }
        viewModel.sliderMaximum.bind { [weak self] value in
            self?.slider.maximumValue = value
        }
        viewModel.sliderValue.bind { [weak self] value in
            guard let self else { return }
            self.isApplyingSlider = true
            self.slider.value = value
            self.isApplyingSlider = false
        }
        viewModel.dateText.bind { [weak self] value in
            self?.updateDateBadge(value)
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
        viewModel.commitTypedValue(textField.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func configureChrome() {
        view.backgroundColor = AppColor.backgroundsPrimary
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.styleBackButton(backButton)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        weightCard.useLiveGlass = false
        weightCard.layer.cornerRadius = 24
        weightCard.cardFillColor = AppColor.backgroundsPrimaryElevated
        weightCard.applyCardShadow = true
        configureSegment()
        configureValueField()
        OnboardingStyle.lockFigmaFont(unitLabel, size: 17, weight: .regular, color: AppColor.labelsSecondary, kern: -0.43)
        configureSlider()
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
        OnboardingStyle.stylePrimaryButton(saveButton, title: L10n.tr("common.save"), systemImage: "checkmark")
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissTap)
    }

    private func configureSegment() {
        unitSegmentedControl.removeAllSegments()
        unitSegmentedControl.insertSegment(withTitle: L10n.tr("onboarding.body.kg"), at: 0, animated: false)
        unitSegmentedControl.insertSegment(withTitle: L10n.tr("logWeight.unit.lbs"), at: 1, animated: false)
        unitSegmentedControl.selectedSegmentIndex = 0
        unitSegmentedControl.backgroundColor = .tertiarySystemFill
        unitSegmentedControl.selectedSegmentTintColor = AppColor.dynamic(light: .white, dark: UIColor.white.withAlphaComponent(0.27))
        let font = UIFont.systemFont(ofSize: 13, weight: .medium)
        unitSegmentedControl.setTitleTextAttributes([.font: font, .foregroundColor: AppColor.labelsPrimary], for: .normal)
        unitSegmentedControl.setTitleTextAttributes([.font: font, .foregroundColor: AppColor.labelsPrimary], for: .selected)
        unitSegmentedControl.addTarget(self, action: #selector(unitChanged), for: .valueChanged)
    }

    private func configureValueField() {
        valueField.delegate = self
        valueField.borderStyle = .none
        valueField.backgroundColor = .clear
        valueField.keyboardType = .decimalPad
        valueField.textAlignment = .trailing
        valueField.adjustsFontSizeToFitWidth = false
        valueField.tintColor = AppColor.labelsPrimary
        valueField.font = UIFont.systemFont(ofSize: 34, weight: .regular)
        valueField.textColor = AppColor.labelsPrimary
        valueField.addTarget(self, action: #selector(updateWeightFieldWidth), for: .editingChanged)
        updateWeightFieldWidth()
    }

    @objc private func updateWeightFieldWidth() {
        let width = ((valueField.text?.isEmpty == false ? valueField.text! : "0") as NSString)
            .size(withAttributes: [.font: valueField.font ?? UIFont.systemFont(ofSize: 34)]).width
        valueFieldWidth.constant = max(44, ceil(width) + 16)
        // UIKit also installs private text-field constraints. Update only our XIB
        // width, then resize the enclosing number/unit stack in the same frame.
        valueField.invalidateIntrinsicContentSize()
        weightCard.layoutIfNeeded()
    }

    private func configureSlider() {
        slider.minimumTrackTintColor = AppColor.teal
        slider.maximumTrackTintColor = .systemFill
        slider.setThumbImage(Self.thumbImage(), for: .normal)
        slider.setThumbImage(Self.thumbImage(), for: .highlighted)
        slider.setMinimumTrackImage(Self.trackImage(AppColor.teal), for: .normal)
        // iOS 26 may suppress the custom maximum track. Keep the unfilled
        // rail explicit, while UISlider retains its native gesture/accessibility.
        let rail = UIView()
        rail.backgroundColor = .systemFill
        rail.layer.cornerRadius = 3
        rail.isUserInteractionEnabled = false
        rail.translatesAutoresizingMaskIntoConstraints = false
        weightCard.insertSubview(rail, belowSubview: slider)
        NSLayoutConstraint.activate([
            rail.leadingAnchor.constraint(equalTo: slider.leadingAnchor),
            rail.trailingAnchor.constraint(equalTo: slider.trailingAnchor),
            rail.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            rail.heightAnchor.constraint(equalToConstant: 6)
        ])
        slider.setMaximumTrackImage(Self.trackImage(.clear), for: .normal)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        ticksView.arrangedSubviews.forEach { tick in
            tick.backgroundColor = AppColor.fillSecondary
            tick.layer.cornerRadius = 2
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
        viewModel.saveTapped()
    }

    @objc private func unitChanged() {
        view.endEditing(true)
        viewModel.selectUnit(index: unitSegmentedControl.selectedSegmentIndex)
    }

    @objc private func sliderChanged() {
        guard !isApplyingSlider else { return }
        viewModel.sliderChanged(slider.value)
        valueField.text = viewModel.displayValueText.value
        updateWeightFieldWidth()
        let step = Int((Double(slider.value) * 10).rounded())
        if lastHapticStep != step {
            lastHapticStep = step
            Haptics.selection()
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private static func thumbImage() -> UIImage {
        let size = CGSize(width: 38, height: 24)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let rect = CGRect(x: 0, y: 0, width: 38, height: 24)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
            UIColor.white.setFill()
            path.fill()
            UIColor.black.withAlphaComponent(0.12).setStroke()
            path.lineWidth = 0.5
            path.stroke()
        }
    }

    private static func trackImage(_ color: UIColor) -> UIImage {
        let size = CGSize(width: 8, height: 6)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 8, height: 6), cornerRadius: 3)
            color.setFill()
            path.fill()
        }
        return image.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 3, bottom: 0, right: 3)).withRenderingMode(.alwaysOriginal)
    }
}
