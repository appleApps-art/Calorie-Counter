import UIKit

final class ProgressStatPillView: UIView {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var valueLabel: AdaptiveLabel!
    @IBOutlet private weak var symbolView: UIImageView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
    }

    func configure(title: String, value: String, valueColor: UIColor = AppColor.labelsPrimary, symbolName: String? = nil) {
        titleLabel.text = title
        valueLabel.text = value
        OnboardingStyle.lockFigmaFont(titleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary)
        OnboardingStyle.lockFigmaFont(valueLabel, size: 17, weight: .semibold, color: valueColor, kern: -0.43)
        if let symbolName {
            symbolView.isHidden = false
            symbolView.image = UIImage(systemName: symbolName)
            symbolView.tintColor = valueColor
        } else {
            symbolView.isHidden = true
        }
    }
}
