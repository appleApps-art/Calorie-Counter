import UIKit

final class OnboardingBodyViewController: BaseViewController {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var unitSegmentedControl: UISegmentedControl!
    @IBOutlet private weak var selectionBandView: AdaptiveView!
    @IBOutlet private weak var pickerView: UIPickerView!
    @IBOutlet private weak var pageControl: UIPageControl!
    @IBOutlet private weak var continueButton: UIButton!

    var onContinue: ((Double, Double) -> Void)?
    var onBack: (() -> Void)?

    var selectedHeightCm: Double {
        let row = pickerView.selectedRow(inComponent: heightComponent)
        let value = heights.indices.contains(row) ? heights[row] : (isMetric ? 175 : 69)
        return isMetric ? Double(value) : Double(value) * 2.54
    }

    var selectedWeightKg: Double {
        let row = pickerView.selectedRow(inComponent: weightComponent)
        let value = weights.indices.contains(row) ? weights[row] : (isMetric ? 60 : 132)
        return isMetric ? Double(value) : Double(value) / 2.2046226218
    }

    private let heightComponent = 0
    private let weightComponent = 1

    private var isMetric = true

    private let heightsMetric = Array(120...220)
    private let weightsMetric = Array(30...200)
    private let heightsImperial = Array(48...84)
    private let weightsImperial = Array(66...440)

    private var heights: [Int] { isMetric ? heightsMetric : heightsImperial }
    private var weights: [Int] { isMetric ? weightsMetric : weightsImperial }
    private var heightUnit: String { isMetric ? L10n.tr("onboarding.body.cm") : L10n.tr("onboarding.body.in") }
    private var weightUnit: String { isMetric ? L10n.tr("onboarding.body.kg") : L10n.tr("onboarding.body.lb") }

    init() {
        super.init(nibName: "OnboardingBodyViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .onboardingBody }

    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundImageView.image = UIImage(named: "OnboardingBg1")
        view.clipsToBounds = false
        titleLabel.text = L10n.tr("onboarding.body.q.title")
        OnboardingStyle.styleHeading(titleLabel, nil)
        selectionBandView.backgroundColor = .tertiarySystemFill
        unitSegmentedControl.isHidden = false
        configureSegmentedControl()
        OnboardingStyle.styleBackButton(backButton)
        OnboardingStyle.stylePrimaryButton(continueButton, title: L10n.tr("common.continue"))
        OnboardingStyle.stylePageControl(pageControl, pages: 6, current: 3)
        OnboardingStyle.styleWheelPicker(pickerView)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        pickerView.dataSource = self
        pickerView.delegate = self
        selectDefaults()
        pageControl.topAnchor.constraint(greaterThanOrEqualTo: pickerView.superview!.bottomAnchor, constant: 16).isActive = true
        FlowScrollLayout.install(in: view, keepingBackgrounds: [backgroundImageView])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        OnboardingStyle.styleWheelPicker(pickerView)
    }

    private func configureSegmentedControl() {
        unitSegmentedControl.removeAllSegments()
        unitSegmentedControl.insertSegment(withTitle: L10n.tr("onboarding.body.metric"), at: 0, animated: false)
        unitSegmentedControl.insertSegment(withTitle: L10n.tr("onboarding.body.imperial"), at: 1, animated: false)
        unitSegmentedControl.selectedSegmentIndex = 0
        unitSegmentedControl.backgroundColor = AppColor.gray6
        unitSegmentedControl.selectedSegmentTintColor = AppColor.card
        unitSegmentedControl.addTarget(self, action: #selector(unitChanged), for: .valueChanged)
    }

    private func selectDefaults() {
        let defaultHeight = isMetric ? 175 : 69
        let defaultWeight = isMetric ? 60 : 132
        if let index = heights.firstIndex(of: defaultHeight) {
            pickerView.selectRow(index, inComponent: heightComponent, animated: false)
        }
        if let index = weights.firstIndex(of: defaultWeight) {
            pickerView.selectRow(index, inComponent: weightComponent, animated: false)
        }
    }

    @objc
    private func unitChanged() {
        Haptics.selection()
        isMetric = unitSegmentedControl.selectedSegmentIndex == 0
        pickerView.reloadAllComponents()
        selectDefaults()
    }

    @objc
    private func backTapped() {
        Haptics.light()
        onBack?()
    }

    @objc
    private func continueTapped() {
        Haptics.light()
        onContinue?(selectedHeightCm, selectedWeightKg)
    }
}

extension OnboardingBodyViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        component == heightComponent ? heights.count : weights.count
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        36
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        pickerView.bounds.width / 2
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let text: String
        if component == heightComponent {
            text = "\(heights[row]) \(heightUnit)"
        } else {
            text = "\(weights[row]) \(weightUnit)"
        }
        return OnboardingStyle.pickerRowLabel(reusing: view, text: text)
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        Haptics.selection()
    }
}
