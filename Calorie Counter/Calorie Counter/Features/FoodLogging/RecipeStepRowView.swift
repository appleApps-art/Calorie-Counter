import UIKit

final class RecipeStepRowView: UIView {
    @IBOutlet private weak var numberCircleView: AdaptiveView!
    @IBOutlet private weak var numberLabel: AdaptiveLabel!
    @IBOutlet private weak var stepLabel: AdaptiveLabel!
    @IBOutlet private weak var separatorView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(index: Int, text: String, showsSeparator: Bool, mutedIndex: Bool = false) {
        separatorView.isHidden = !showsSeparator
        numberLabel.text = "\(index)"
        stepLabel.text = text
        OnboardingStyle.lockFigmaFont(numberLabel, size: 13, weight: .semibold, color: AppColor.onAccent)
        OnboardingStyle.lockFigmaFont(stepLabel, size: 15, weight: .regular, color: AppColor.labelsPrimary, kern: -0.23)
        numberLabel.textAlignment = .center
        stepLabel.numberOfLines = 0
        stepLabel.adaptFontSize = false
        numberLabel.adaptFontSize = false
        numberCircleView.backgroundColor = mutedIndex ? AppColor.iconSecondary : AppColor.teal
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        separatorView.backgroundColor = AppColor.hairline
        numberCircleView.useLiveGlass = false
        numberCircleView.applyCardShadow = false
        numberCircleView.backgroundColor = AppColor.teal
        numberCircleView.clipsToBounds = true
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }
}
