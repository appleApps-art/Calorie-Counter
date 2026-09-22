import UIKit

final class NotificationRowView: UIView {
    @IBOutlet private weak var iconWellView: AdaptiveView!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var bodyLabel: AdaptiveLabel!
    @IBOutlet private weak var timeLabel: AdaptiveLabel!
    @IBOutlet private weak var separatorView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    var onDismiss: (() -> Void)?

    func configure(_ item: NotificationInboxRow, showsSeparator: Bool, settingsStyle: Bool = false) {
        titleLabel.text = item.title
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        bodyLabel.text = item.body
        timeLabel.text = item.timeText
        separatorView.isHidden = !showsSeparator
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        OnboardingStyle.lockFigmaFont(
            bodyLabel,
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
        timeLabel.textAlignment = .trailing
        timeLabel.adjustsFontSizeToFitWidth = true
        timeLabel.minimumScaleFactor = 0.8
        if let font = timeLabel.font {
            timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: font.pointSize, weight: .regular)
        }
        applyLineHeight(22, to: titleLabel)
        applyLineHeight(18, to: bodyLabel)
        applyLineHeight(18, to: timeLabel)
        bodyLabel.numberOfLines = 0
        iconWellView.backgroundColor = settingsStyle ? .white : AppColor.fillTertiary
        iconWellView.useLiveGlass = false
        if let imageName = item.imageName, let image = UIImage(named: imageName) {
            iconView.image = image
            iconView.tintColor = nil
            iconView.contentMode = .scaleAspectFit
        } else {
            let name = item.symbolName ?? "bell.fill"
            iconView.image = OnboardingStyle.symbol(name, pointSize: 17, weight: .semibold)
            iconView.tintColor = AppColor.iconSecondary
            iconView.contentMode = .center
        }
        separatorView.backgroundColor = AppColor.hairline
        accessibilityLabel = [item.title, item.body, item.timeText]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        isAccessibilityElement = true
        accessibilityCustomActions = [UIAccessibilityCustomAction(
            name: L10n.tr("pantry.delete"), target: self, selector: #selector(accessibilityDismiss)
        )]
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleDismiss))
        swipe.direction = .left
        addGestureRecognizer(swipe)
    }

    private func applyLineHeight(_ height: CGFloat, to label: UILabel) {
        guard let text = label.attributedText, text.length > 0 else { return }
        let value = NSMutableAttributedString(attributedString: text)
        let paragraph = ((text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy()
            as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraph.minimumLineHeight = height
        paragraph.maximumLineHeight = height
        value.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: value.length))
        if label === timeLabel, let font = label.font {
            value.addAttribute(.font, value: font, range: NSRange(location: 0, length: value.length))
        }
        label.attributedText = value
    }

    @objc
    private func handleDismiss() {
        Haptics.selection()
        onDismiss?()
    }

    @objc private func accessibilityDismiss() -> Bool {
        handleDismiss()
        return true
    }
}
