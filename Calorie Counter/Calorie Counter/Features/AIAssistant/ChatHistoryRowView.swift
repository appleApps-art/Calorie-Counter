import UIKit

final class ChatHistoryRowView: UIView {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var timeLabel: AdaptiveLabel!
    @IBOutlet private weak var chevronView: UIImageView!
    @IBOutlet private weak var separatorView: UIView!

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ item: ChatHistoryRowItem, showsSeparator: Bool) {
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        timeLabel.text = item.timeText
        separatorView.isHidden = !showsSeparator
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .regular,
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
        OnboardingStyle.lockFigmaFont(
            timeLabel,
            size: 13,
            weight: .regular,
            color: AppColor.labelsSecondary,
            kern: -0.08
        )
        titleLabel.applyLineTruncation(lines: 1)
        subtitleLabel.applyLineTruncation(lines: 1)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        timeLabel.textAlignment = .right
        if let font = timeLabel.font {
            timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: font.pointSize, weight: .regular)
        }
        timeLabel.applyLineTruncation(lines: 1)
        timeLabel.textAlignment = .right
        chevronView.image = OnboardingStyle.symbol("chevron.right", pointSize: 13, weight: .medium)?.withTintColor(
            AppColor.labelsPrimary,
            renderingMode: .alwaysOriginal
        )
        chevronView.isAccessibilityElement = false
        separatorView.backgroundColor = AppColor.hairline
        accessibilityLabel = [item.title, item.subtitle, item.timeText]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    @objc
    private func handleTap() {
        Haptics.light()
        onTap?()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        isAccessibilityElement = true
        accessibilityTraits = .button
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
}
