import UIKit

final class OnboardingFeatureRowView: UIView {
    @IBOutlet private weak var iconContainerView: AdaptiveView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!

    private var iconName: String?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 38)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(icon: String, title: String) {
        iconName = icon
        titleLabel.text = title
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .regular, color: AppColor.textPrimary, kern: -0.43)
        titleLabel.applyWrapping()
        refreshIconChrome()
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
        let wellColor = AppColor.gray6
        let iconColor = AppColor.iconSecondary
        iconContainerView.backgroundColor = wellColor
        iconImageView.tintColor = iconColor
        guard let iconName else { return }
        iconImageView.image = OnboardingStyle.symbol(iconName, pointSize: 17)?
            .withTintColor(iconColor, renderingMode: .alwaysOriginal)
    }
}
