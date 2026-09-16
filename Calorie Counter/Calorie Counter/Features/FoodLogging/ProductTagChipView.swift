import UIKit

final class ProductTagChipView: UIView {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ title: String) {
        titleLabel.text = title
        OnboardingStyle.lockFigmaFont(titleLabel, size: 13, weight: .regular, color: AppColor.labelsPrimary, kern: -0.08)
        applyFill()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        if let content = subviews.first as? AdaptiveView {
            content.useLiveGlass = false
            content.applyCardShadow = false
            content.showsHairlineBorder = true
            content.clipsToBounds = true
        }
        applyFill()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ProductTagChipView, _) in
            view.applyFill()
        }
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func applyFill() {
        guard let content = subviews.first else { return }
        content.backgroundColor = AppColor.fillVibrantTertiary
        content.clipsToBounds = true
    }
}
