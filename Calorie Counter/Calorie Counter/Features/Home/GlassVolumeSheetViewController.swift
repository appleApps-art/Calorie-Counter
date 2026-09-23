import UIKit

final class GlassVolumeSheetViewController: BaseViewController, UITextFieldDelegate {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var navTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var inputCard: AdaptiveView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var valueField: UITextField!
    @IBOutlet private weak var clearButton: UIButton!
    @IBOutlet private weak var chipsCard: AdaptiveView!
    @IBOutlet private weak var chipsLabel: AdaptiveLabel!
    @IBOutlet private weak var chip150: UIButton!
    @IBOutlet private weak var chip200: UIButton!
    @IBOutlet private weak var chip250: UIButton!
    @IBOutlet private weak var chip330: UIButton!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private var restingBottomConstraint: NSLayoutConstraint!

    private let initialValue: Int
    private let onSave: (Int) -> Void
    private let presets = [150, 200, 250, 330]
    private let units = AppUnits.current
    private var editingTopConstraint: NSLayoutConstraint?

    init(milliliters: Int, onSave: @escaping (Int) -> Void) {
        self.initialValue = milliliters
        self.onSave = onSave
        super.init(nibName: "GlassVolumeSheetViewController")
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.applyFigmaInspectorDetent(386)
    }

    override var analyticsScreen: AnalyticsScreen? { .glassVolume }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Tint the native sheet material without replacing its live glass backdrop.
        applySheetBackground(AppColor.dynamic(light: .clear, dark: UIColor.black.withAlphaComponent(0.6)))
        disableCardLiveGlass()
        inputCard.cardFillColor = AppColor.backgroundsPrimaryElevated
        chipsCard.cardFillColor = AppColor.gray6
        // UIKit expands this inspector for the keyboard. Keep the form under its
        // header while editing instead of following the newly expanded bottom edge.
        if let form = saveButton.superview, let header = closeButton.superview {
            editingTopConstraint = form.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24)
        }
        navTitleLabel.text = L10n.tr("home.glassVolume.navTitle")
        titleLabel.text = L10n.tr("home.glassVolume.title")
        chipsLabel.text = L10n.tr("home.glassVolume.standard")
        OnboardingStyle.lockFigmaFont(
            navTitleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: -0.43
        )
        OnboardingStyle.lockFigmaFont(
            chipsLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        valueField.delegate = self
        valueField.keyboardType = .decimalPad
        valueField.tintColor = AppColor.teal
        valueField.defaultTextAttributes = fieldAttributes
        applyFieldText(units.number(units.volume(Double(initialValue))))
        OnboardingStyle.styleGlassSymbolButton(
            closeButton,
            systemName: "xmark",
            foregroundColor: AppColor.iconSecondary
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = AppColor.labelsSecondary.withAlphaComponent(0.3)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        OnboardingStyle.stylePrimaryButton(saveButton, title: L10n.tr("common.save"), systemImage: "checkmark")
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        zip([chip150, chip200, chip250, chip330], presets).forEach { button, value in
            button?.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            button?.tag = value
        }
        refreshChips()
        valueField.addTarget(self, action: #selector(valueChanged), for: .editingChanged)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        restingBottomConstraint.isActive = false
        editingTopConstraint?.isActive = true
        let digits = currentDigits
        if textField.text != digits {
            textField.text = digits
        }
        DispatchQueue.main.async {
            textField.selectAll(nil)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        editingTopConstraint?.isActive = false
        restingBottomConstraint.isActive = true
        applyFieldText(currentDigits)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty { return true }
        let current = textField.text ?? ""
        guard let range = Range(range, in: current) else { return false }
        return current.replacingCharacters(in: range, with: string).range(of: #"^[0-9]*([.,][0-9]*)?$"#, options: .regularExpression) != nil
    }

    @objc
    private func valueChanged() {
        let digits = currentDigits
        if valueField.isFirstResponder, valueField.text != digits {
            valueField.text = digits
        }
        refreshChips()
    }

    @objc
    private func clearTapped() {
        applyFieldText("")
        refreshChips()
        valueField.becomeFirstResponder()
    }

    @objc
    private func chipTapped(_ sender: UIButton) {
        applyFieldText(units.number(units.volume(Double(sender.tag))))
        refreshChips()
    }

    @objc
    private func saveTapped() {
        guard let displayed = Double(currentDigits.replacingOccurrences(of: ",", with: ".")), displayed.isFinite, displayed > 0 else { return }
        let value = max(1, Int(units.milliliters(displayed).rounded()))
        dismiss(animated: true) { [onSave] in
            onSave(value)
        }
    }

    @objc
    private func closeTapped() {
        dismiss(animated: true)
    }

    private func refreshChips() {
        let current = currentDigits
        zip([chip150, chip200, chip250, chip330], presets).forEach { button, value in
            guard let button else { return }
            OnboardingStyle.styleSelectionChip(
                button,
                title: units.volumeText(Double(value)),
                selected: current == units.number(units.volume(Double(value)))
            )
            // Four presets share a compact row. Reapply these after configuration
            // changes so editing cannot restore the generic chip's wrapping/insets.
            button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)
            button.configuration?.titleLineBreakMode = .byClipping
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.8
        }
    }

    private var currentDigits: String {
        String((valueField.text ?? "").prefix { $0.isNumber || $0 == "." || $0 == "," })
    }

    private var fieldAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 17, weight: .medium),
            .foregroundColor: AppColor.labelsPrimary,
            .kern: -0.43
        ]
    }

    private func formattedValue(_ value: Double) -> String {
        "\(units.number(value)) \(units.volumeSymbol)"
    }

    private func applyFieldText(_ digits: String) {
        let formatted: String
        if digits.isEmpty {
            formatted = ""
        } else if valueField.isFirstResponder {
            formatted = digits
        } else if let value = Double(digits.replacingOccurrences(of: ",", with: ".")) {
            formatted = formattedValue(value)
        } else {
            formatted = digits
        }
        if valueField.text != formatted {
            valueField.text = formatted
        }
    }

    private func disableCardLiveGlass() {
        [inputCard, chipsCard].forEach { card in
            card.useLiveGlass = false
        }
    }
}
