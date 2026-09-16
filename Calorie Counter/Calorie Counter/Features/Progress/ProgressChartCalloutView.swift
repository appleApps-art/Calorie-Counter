import UIKit

final class ProgressChartCalloutView: UIView {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var rowsStack: UIStackView!
    @IBOutlet private weak var fatsRow: UIStackView!
    @IBOutlet private weak var carbsRow: UIStackView!
    @IBOutlet private weak var proteinRow: UIStackView!
    @IBOutlet private weak var fatsDot: UIView!
    @IBOutlet private weak var carbsDot: UIView!
    @IBOutlet private weak var proteinDot: UIView!
    @IBOutlet private weak var fatsLabel: AdaptiveLabel!
    @IBOutlet private weak var carbsLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinLabel: AdaptiveLabel!

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
        isUserInteractionEnabled = false
        embedNibContent()
        [fatsDot, carbsDot, proteinDot].forEach { dot in
            dot?.layer.cornerRadius = .adaptWidth(4)
        }
        fatsDot.backgroundColor = AppColor.accentIndigo
        carbsDot.backgroundColor = AppColor.accentMint
        proteinDot.backgroundColor = AppColor.accentBlue
        refreshFill()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ProgressChartCalloutView, _) in
            view.refreshFill()
        }
    }

    private func refreshFill() {
        subviews.first?.backgroundColor = AppColor.labelsPrimary
    }

    func showStacked(title: String, fats: String, carbs: String, protein: String) {
        isHidden = false
        rowsStack.isHidden = false
        titleLabel.numberOfLines = 1
        applyTitle(title)
        applyRow(fatsLabel, text: fats)
        applyRow(carbsLabel, text: carbs)
        applyRow(proteinLabel, text: protein)
        invalidateIntrinsicContentSize()
    }

    func showCompact(title: String, lines: Int = 1) {
        isHidden = false
        rowsStack.isHidden = true
        titleLabel.numberOfLines = lines
        applyTitle(title)
        invalidateIntrinsicContentSize()
    }

    func hide() {
        isHidden = true
    }

    private func applyTitle(_ text: String) {
        titleLabel.text = text
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 13,
            weight: .semibold,
            color: AppColor.onAccent,
            kern: -0.08
        )
    }

    private func applyRow(_ label: AdaptiveLabel, text: String) {
        label.text = text
        OnboardingStyle.lockFigmaFont(
            label,
            size: 11,
            weight: .regular,
            color: AppColor.onAccent,
            kern: 0.06
        )
    }
}
