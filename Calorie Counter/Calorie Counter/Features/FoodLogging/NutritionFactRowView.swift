import UIKit

final class NutritionFactRowView: UIControl {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var valueLabel: AdaptiveLabel!
    @IBOutlet private weak var dailyValueLabel: AdaptiveLabel!
    @IBOutlet private weak var checkImageView: UIImageView!
    @IBOutlet private weak var separatorView: UIView!
    @IBOutlet private weak var dailyValueWidthConstraint: AdaptiveConstraint!
    @IBOutlet private weak var dailyValueLeadingConstraint: AdaptiveConstraint!
    @IBOutlet private weak var valueWidthConstraint: AdaptiveConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(title: String, value: String, dailyValue: String? = nil, showsSeparator: Bool = true, separatorColor: UIColor = AppColor.hairline) {
        titleLabel.text = title
        valueLabel.text = value
        dailyValueLabel.text = dailyValue
        let hasValue = !value.isEmpty
        setDailyValueVisible(dailyValue != nil)
        valueLabel.isHidden = !hasValue
        valueWidthConstraint?.designConstant = dailyValue == nil ? (hasValue ? 140 : 0) : 90
        separatorView.isHidden = !showsSeparator
        separatorView.backgroundColor = separatorColor
        checkImageView.isHidden = true
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(valueLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(dailyValueLabel, size: 13, weight: .regular, color: AppColor.labelsSecondary, kern: -0.08)
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        dailyValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        titleLabel.applyLineTruncation(lines: 2)
        valueLabel.applyLineTruncation(lines: 1)
        titleLabel.textAlignment = .left
        valueLabel.textAlignment = .right
    }

    func configureMeal(title: String, selected: Bool, showsSeparator: Bool) {
        configure(title: title, value: "", dailyValue: nil, showsSeparator: showsSeparator)
        valueLabel.isHidden = true
        valueWidthConstraint?.designConstant = 0
        checkImageView.isHidden = !selected
        checkImageView.image = OnboardingStyle.symbol("checkmark", pointSize: 17)
        checkImageView.tintColor = AppColor.teal
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        subviews.forEach { $0.isUserInteractionEnabled = false }
        separatorView.backgroundColor = AppColor.hairline
        checkImageView.isHidden = true
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func setDailyValueVisible(_ visible: Bool) {
        dailyValueLabel.isHidden = !visible
        dailyValueWidthConstraint?.designConstant = visible ? 60 : 0
        dailyValueLeadingConstraint?.designConstant = visible ? 8 : 0
    }
}
