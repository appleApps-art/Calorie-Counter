import UIKit

final class OnboardingAgeViewController: BaseViewController {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var selectionBandView: AdaptiveView!
    @IBOutlet private weak var pickerView: UIPickerView!
    @IBOutlet private weak var pageControl: UIPageControl!
    @IBOutlet private weak var continueButton: UIButton!

    var onContinue: ((Int) -> Void)?
    var onBack: (() -> Void)?

    var selectedAge: Int {
        let row = pickerView.selectedRow(inComponent: 0)
        guard ages.indices.contains(row) else { return defaultAge }
        return ages[row]
    }

    private let ages = Array(13...100)
    private let defaultAge = 25

    init() {
        super.init(nibName: "OnboardingAgeViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .onboardingAge }

    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundImageView.image = UIImage(named: "OnboardingBg1")
        view.clipsToBounds = false
        titleLabel.text = L10n.tr("onboarding.age.q.title")
        subtitleLabel.text = L10n.tr("onboarding.age.q.subtitle")
        OnboardingStyle.styleHeading(titleLabel, subtitleLabel)
        selectionBandView.backgroundColor = .tertiarySystemFill
        OnboardingStyle.styleBackButton(backButton)
        OnboardingStyle.stylePrimaryButton(continueButton, title: L10n.tr("common.continue"))
        OnboardingStyle.stylePageControl(pageControl, pages: 6, current: 2)
        OnboardingStyle.styleWheelPicker(pickerView)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        pickerView.dataSource = self
        pickerView.delegate = self
        if let index = ages.firstIndex(of: defaultAge) {
            pickerView.selectRow(index, inComponent: 0, animated: false)
        }
        pageControl.topAnchor.constraint(greaterThanOrEqualTo: pickerView.superview!.bottomAnchor, constant: 16).isActive = true
        FlowScrollLayout.install(in: view, keepingBackgrounds: [backgroundImageView])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        OnboardingStyle.styleWheelPicker(pickerView)
    }

    @objc
    private func backTapped() {
        onBack?()
    }

    @objc
    private func continueTapped() {
        onContinue?(selectedAge)
    }
}

extension OnboardingAgeViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        ages.count
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        36
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        OnboardingStyle.pickerRowLabel(reusing: view, text: "\(ages[row])")
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        Haptics.selection()
    }
}
