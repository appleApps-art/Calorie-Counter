import UIKit

final class RewardBadgeView: UIControl {
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!

    private(set) var progress: BadgeProgress?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ progress: BadgeProgress) {
        self.progress = progress
        iconImageView.image = UIImage(named: progress.badge.imageName)
        iconImageView.alpha = progress.showsLockedArt ? 0.15 : 1
        titleLabel.text = progress.badge.title
        subtitleLabel.text = progress.listSubtitle
        OnboardingStyle.lockFigmaFont(titleLabel, size: 15, weight: .regular, color: AppColor.labelsPrimary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(subtitleLabel, size: 12, weight: .regular, color: AppColor.iconSecondary)
        titleLabel.textAlignment = .center
        subtitleLabel.textAlignment = .center
        titleLabel.applyWrapping()
        subtitleLabel.applyWrapping()
        titleLabel.enableDynamicType(baseFont: .systemFont(ofSize: 15))
        subtitleLabel.enableDynamicType(baseFont: .systemFont(ofSize: 12), textStyle: .caption1)
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        subviews.first?.isUserInteractionEnabled = false
        guard let content = subviews.first else { return }
        NSLayoutConstraint.deactivate(content.constraints.filter {
            $0.firstItem === content && $0.firstAttribute == .height && $0.secondItem == nil
        })
        NSLayoutConstraint.deactivate(iconImageView.constraints.filter {
            $0.secondItem == nil && ($0.firstAttribute == .width || $0.firstAttribute == .height)
        })
        let preferredIconWidth = iconImageView.widthAnchor.constraint(equalToConstant: 118)
        preferredIconWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredIconWidth,
            iconImageView.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor),
            iconImageView.heightAnchor.constraint(equalTo: iconImageView.widthAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualToConstant: 182),
            content.bottomAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8)
        ])
    }
}
