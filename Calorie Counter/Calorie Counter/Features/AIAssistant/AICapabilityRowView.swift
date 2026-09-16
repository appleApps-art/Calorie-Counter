import UIKit

final class AICapabilityRowView: UIView {
    @IBOutlet private weak var iconContainerView: AdaptiveView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var separatorView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(icon: String, title: String, subtitle: String, showsSeparator: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        OnboardingStyle.lockFigmaFont(
            subtitleLabel,
            size: 13,
            weight: .regular,
            color: AppColor.labelsSecondary,
            kern: -0.08
        )
        iconContainerView.backgroundColor = AppColor.teal
        iconImageView.image = OnboardingStyle.symbol(icon, pointSize: 16)?
            .withTintColor(AppColor.onAccent, renderingMode: .alwaysOriginal)
        iconImageView.tintColor = AppColor.onAccent
        separatorView.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        separatorView.isHidden = !showsSeparator
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
    }
}
