import UIKit

final class IngredientLineView: UIView, UITextFieldDelegate {
    @IBOutlet private weak var textField: UITextField!
    @IBOutlet private weak var separatorView: UIView!

    private(set) var ingredientID: UUID?
    var onCommit: ((UUID, String) -> Void)?
    var isEditable: Bool = false {
        didSet { textField.isEnabled = isEditable }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ ingredient: FoodIngredient, showsSeparator: Bool, editable: Bool) {
        ingredientID = ingredient.id
        isEditable = editable
        textField.text = ProductDetailsMath.formatIngredient(ingredient)
        textField.isEnabled = editable
        separatorView.isHidden = !showsSeparator
        textField.defaultTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .medium),
            .foregroundColor: AppColor.labelsPrimary,
            .kern: -0.43
        ]
        textField.attributedText = NSAttributedString(
            string: ProductDetailsMath.formatIngredient(ingredient),
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: AppColor.labelsPrimary,
                .kern: -0.43
            ]
        )
        textField.clearButtonMode = editable ? .whileEditing : .never
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let ingredientID else { return }
        onCommit?(ingredientID, textField.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        separatorView.backgroundColor = AppColor.hairline
        textField.delegate = self
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.tintColor = AppColor.teal
        textField.returnKeyType = .done
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }
}
