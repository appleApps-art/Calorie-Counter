import UIKit

final class BarcodeManualEntryViewController: BaseViewController, UITextFieldDelegate {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var inputCard: AdaptiveView!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var barcodeTextField: UITextField!
    @IBOutlet private weak var lookupButton: UIButton!

    var onClose: (() -> Void)?
    var onLookup: ((String) -> Void)?

    private var autoLookupWork: DispatchWorkItem?
    private var didSubmit = false
    private let clearButton = UIButton(type: .system)

    init() {
        super.init(nibName: "BarcodeManualEntryViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .barcodeManual }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.sheetGlassTint
        titleLabel.text = L10n.tr("barcode.manual.title")
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark", foregroundColor: AppColor.iconSecondary)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        inputCard.useLiveGlass = false
        inputCard.showsHairlineBorder = true
        inputCard.backgroundColor = AppColor.backgroundsPrimary
        subtitleLabel.text = L10n.tr("barcode.manual.subtitle")
        OnboardingStyle.lockFigmaFont(
            subtitleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: -0.43
        )

        barcodeTextField.delegate = self
        barcodeTextField.borderStyle = .none
        barcodeTextField.backgroundColor = .clear
        barcodeTextField.keyboardType = .numberPad
        barcodeTextField.font = .systemFont(ofSize: 17, weight: .medium)
        barcodeTextField.textColor = AppColor.labelVibrantPrimary
        barcodeTextField.attributedPlaceholder = NSAttributedString(
            string: L10n.tr("barcode.manual.placeholder"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: AppColor.footerLabel
            ]
        )
        barcodeTextField.addTarget(self, action: #selector(barcodeChanged), for: .editingChanged)
        configureClearButton()
        barcodeChanged()
        // In the design the card and the button sit right above the keyboard, not under the title.
        NSLayoutConstraint.activate([
            lookupButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: .adaptHeight(-32))
        ])

        OnboardingStyle.stylePrimaryButton(
            lookupButton,
            title: L10n.tr("barcode.manual.lookup"),
            systemImage: "magnifyingglass"
        )
        lookupButton.addTarget(self, action: #selector(lookupTapped), for: .touchUpInside)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        barcodeTextField.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autoLookupWork?.cancel()
        if isBeingDismissed {
            view.endEditing(true)
        }
    }



    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty { return true }
        let current = (textField.text ?? "").filter(\.isNumber)
        let added = string.filter(\.isNumber)
        guard string.allSatisfy({ $0.isNumber || $0.isWhitespace }) else { return false }
        return current.count + added.count <= 14
    }

    @objc
    private func closeTapped() {
        view.endEditing(true)
        onClose?()
    }

    @objc
    private func lookupTapped() {
        submitLookup()
    }

    @objc
    private func barcodeChanged() {
        guard let field = barcodeTextField else { return }
        let current = field.text ?? ""
        let formatted = BarcodeNormalization.groupedDisplay(current)
        if current != formatted {
            let digitsBeforeCursor: Int = {
                guard
                    let selected = field.selectedTextRange,
                    let prefixRange = field.textRange(from: field.beginningOfDocument, to: selected.start)
                else {
                    return current.filter(\.isNumber).count
                }
                let prefix = field.text(in: prefixRange) ?? ""
                return prefix.filter(\.isNumber).count
            }()
            field.text = formatted
            if let position = positionAfterDigits(digitsBeforeCursor, in: formatted, field: field) {
                field.selectedTextRange = field.textRange(from: position, to: position)
            }
        }
        let text = field.text ?? ""
        clearButton.isHidden = text.isEmpty
        scheduleAutoLookup()
    }

    private func scheduleAutoLookup() {
        autoLookupWork?.cancel()
        guard let code = BarcodeNormalization.normalize(barcodeTextField.text ?? "") else { return }
        let delay: TimeInterval
        switch code.count {
        case 13, 14:
            delay = 0.2
        case 12:
            delay = 0.7
        case 8:
            delay = 1.0
        default:
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.submitLookup()
        }
        autoLookupWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func submitLookup() {
        autoLookupWork?.cancel()
        // The button keeps its filled look in both states of the design; until the digits make up
        // a barcode, tapping it simply does nothing.
        guard !didSubmit, let code = BarcodeNormalization.normalize(barcodeTextField.text ?? "") else { return }
        didSubmit = true
        lookupButton.isEnabled = false
        view.endEditing(true)
        onLookup?(code)
    }

    @objc
    private func clearTapped() {
        barcodeTextField.text = ""
        barcodeChanged()
    }

    private func positionAfterDigits(_ count: Int, in formatted: String, field: UITextField) -> UITextPosition? {
        var seen = 0
        var index = formatted.startIndex
        while index < formatted.endIndex, seen < count {
            if formatted[index].isNumber {
                seen += 1
            }
            index = formatted.index(after: index)
        }
        let offset = formatted.distance(from: formatted.startIndex, to: index)
        return field.position(from: field.beginningOfDocument, offset: offset)
    }

    private func configureClearButton() {
        let image = UIImage(
            systemName: "xmark.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        )
        clearButton.setImage(image, for: .normal)
        clearButton.tintColor = AppColor.labelsTertiary
        clearButton.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        barcodeTextField.rightView = clearButton
        barcodeTextField.rightViewMode = .always
        clearButton.isHidden = true
    }

}
