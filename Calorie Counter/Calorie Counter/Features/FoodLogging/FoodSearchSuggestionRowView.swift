import UIKit

final class FoodSearchSuggestionRowView: UIView {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var separatorView: UIView!

    private var title = ""
    var onSelect: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(title: String, showsSeparator: Bool) {
        self.title = title
        titleLabel.text = title
        separatorView.isHidden = !showsSeparator
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
    }

    @objc
    private func tapped() {
        Haptics.light()
        onSelect?(title)
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        separatorView.backgroundColor = AppColor.hairline
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }
}
