import UIKit

final class OnboardingFeatureRowView: UIView {
    @IBOutlet private weak var iconContainerView: AdaptiveView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!

    private var iconName: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(icon: String, title: String) {
        relaxFixedHeight()
        iconName = icon
        titleLabel.text = title
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .regular, color: AppColor.textPrimary, kern: -0.43)
        titleLabel.applyWrapping()
        refreshIconChrome()
    }

    /// The nib pins a row to 38pt; on a narrow screen the text needs a second line, so the pin
    /// becomes a minimum instead of cutting the label in half.
    private func relaxFixedHeight() {
        let fixed = constraints.filter {
            $0.firstItem === self && $0.secondItem == nil
                && $0.firstAttribute == .height && $0.relation == .equal
        }
        guard !fixed.isEmpty else { return }
        NSLayoutConstraint.deactivate(fixed)
        fixed.forEach { heightAnchor.constraint(greaterThanOrEqualToConstant: $0.constant).isActive = true }
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        embedNibContent()
        if let content = subviews.first {
            content.constraints.first {
                $0.firstAttribute == .bottom && $0.secondItem === iconContainerView
            }?.priority = .defaultHigh
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 4),
                titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -4)
            ])
        }
        titleLabel.textColor = AppColor.textPrimary
        refreshIconChrome()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: OnboardingFeatureRowView, _) in
            view.refreshIconChrome()
            view.titleLabel.textColor = AppColor.textPrimary
        }
    }

    private func refreshIconChrome() {
        // The design puts the glyph in a black well on white, and in a grey one on black.
        let isDark = traitCollection.userInterfaceStyle == .dark
        let wellColor = isDark ? AppColor.fillTertiary : UIColor.black
        let iconColor = isDark ? AppColor.iconSecondary : UIColor.white
        iconContainerView.backgroundColor = wellColor
        iconImageView.tintColor = iconColor
        guard let iconName else { return }
        iconImageView.image = OnboardingStyle.symbol(iconName, pointSize: 17)?
            .withTintColor(iconColor, renderingMode: .alwaysOriginal)
    }
}
