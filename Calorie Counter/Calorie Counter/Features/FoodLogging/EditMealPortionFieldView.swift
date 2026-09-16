import UIKit

final class EditMealPortionFieldView: UIView, UITextFieldDelegate {
    @IBOutlet private weak var portionField: UITextField!

    private var displayedPortion = ""
    private var portionSuffix = ""
    private var initialNumber = ""
    private(set) var itemID: UUID?
    var onCommitPortion: ((UUID, String) -> Void)?
    var onEditingChanged: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ item: EditMealItem) {
        itemID = item.id
        displayedPortion = item.portionText
        portionField.placeholder = L10n.tr("editMeal.weightPlaceholder")
        styleField(text: item.portionText)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let content = subviews.first, content.bounds.height > 0 else { return }
        content.layer.cornerRadius = content.bounds.height / 2
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let text = displayedPortion
        let number = String(text.prefix { $0.isNumber || $0 == "." || $0 == "," })
        portionSuffix = text.isEmpty
            ? " " + AppUnits.current.portionSymbol
            : String(text.dropFirst(number.count))
        textField.text = number
        initialNumber = number
        onEditingChanged?(true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        onEditingChanged?(false)
        commitPortion()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text, let swiftRange = Range(range, in: text) else { return false }
        let next = text.replacingCharacters(in: swiftRange, with: string)
        return next.range(of: #"^[0-9]*([.,][0-9]*)?$"#, options: .regularExpression) != nil
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        if let content = subviews.first {
            content.backgroundColor = UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? AppColor.card.resolvedColor(with: trait)
                    : AppColor.gray6.resolvedColor(with: trait)
            }
            content.clipsToBounds = true
            content.layer.masksToBounds = true
            content.layer.cornerCurve = .continuous
            content.layer.borderWidth = 0
        }
        portionField?.delegate = self
        portionField?.borderStyle = .none
        portionField?.backgroundColor = .clear
        portionField?.tintColor = AppColor.teal
        portionField?.returnKeyType = .done
        portionField?.keyboardType = .decimalPad
        portionField?.autocorrectionType = .no
        portionField?.spellCheckingType = .no
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func styleField(text: String) {
        guard let portionField else { return }
        portionField.borderStyle = .none
        portionField.backgroundColor = .clear
        portionField.defaultTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .medium),
            .foregroundColor: AppColor.labelsPrimary,
            .kern: -0.43
        ]
        portionField.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: AppColor.labelsPrimary,
                .kern: -0.43
            ]
        )
    }

    private func commitPortion() {
        guard let itemID else { return }
        let number = portionField.text ?? ""
        guard number != initialNumber else { styleField(text: displayedPortion); return }
        let normalized = number.replacingOccurrences(of: ",", with: ".")
        guard number.range(of: #"^[0-9]+([.,][0-9]*)?$"#, options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite, value > 0 else {
            styleField(text: displayedPortion)
            return
        }
        let cleanNumber = number.last == "." || number.last == "," ? String(number.dropLast()) : number
        let formatted = cleanNumber + portionSuffix
        displayedPortion = formatted
        styleField(text: formatted)
        onCommitPortion?(itemID, formatted)
    }
}
