import UIKit

final class SettingsWeightGoalViewController: BaseViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var pickerView: UIPickerView!
    @IBOutlet private weak var selectionBandView: AdaptiveView!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var decorationsView: SettingsSheetDecorationsView!

    private let isMetric: Bool
    private let initialKilograms: Double?
    private let onSave: (Double) -> Void
    private let weightsMetric = Array(30...200)
    private let weightsImperial = Array(66...440)

    private var weights: [Int] { isMetric ? weightsMetric : weightsImperial }
    private var unit: String {
        isMetric ? L10n.tr("onboarding.body.kg") : L10n.tr("onboarding.body.lb")
    }

    init(isMetric: Bool, kilograms: Double?, onSave: @escaping (Double) -> Void) {
        self.isMetric = isMetric
        self.initialKilograms = kilograms
        self.onSave = onSave
        super.init(nibName: "SettingsWeightGoalViewController")
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 38
        }
    }

    override var analyticsScreen: AnalyticsScreen? { .settingsWeightGoal }

    override func viewDidLoad() {
        super.viewDidLoad()
        SettingsSheetChrome.apply(to: view)
        titleLabel.text = L10n.tr("settings.weightGoal")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(
            closeButton,
            systemName: "xmark",
            foregroundColor: AppColor.iconSecondary
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        OnboardingStyle.stylePrimaryButton(saveButton, title: L10n.tr("common.save"))
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        selectionBandView.backgroundColor = AppColor.backgroundsPrimary
        view.sendSubviewToBack(decorationsView)
        selectionBandView.adaptCornerRadius = true
        selectionBandView.designCornerRadius = 8
        selectionBandView.useLiveGlass = false
        pickerView.dataSource = self
        pickerView.delegate = self
        OnboardingStyle.styleWheelPicker(pickerView)
        selectInitial()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        OnboardingStyle.styleWheelPicker(pickerView)
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        weights.count
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        .adaptHeight(36)
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        OnboardingStyle.pickerRowLabel(reusing: view, text: "\(weights[row]) \(unit)")
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        Haptics.selection()
    }

    private func selectInitial() {
        guard let initialKilograms else { return }
        let value = isMetric
            ? Int(initialKilograms.rounded())
            : Int((initialKilograms * 2.2046226218).rounded())
        if let index = weights.firstIndex(of: value) {
            pickerView.selectRow(index, inComponent: 0, animated: false)
        }
    }

    private var selectedKilograms: Double {
        let row = pickerView.selectedRow(inComponent: 0)
        let value = weights.indices.contains(row) ? weights[row] : weights[0]
        return isMetric ? Double(value) : Double(value) / 2.2046226218
    }

    @objc
    private func saveTapped() {
        let kilograms = selectedKilograms
        dismiss(animated: true) { [onSave] in
            onSave(kilograms)
        }
    }

    @objc
    private func closeTapped() {
        dismiss(animated: true)
    }
}
