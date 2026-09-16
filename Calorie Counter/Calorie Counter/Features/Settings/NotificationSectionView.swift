import UIKit

final class NotificationSectionView: UIView {
    @IBOutlet private weak var dateLabel: AdaptiveLabel!
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var rowsStackView: UIStackView!

    private var settingsStyle = false
    var onDismiss: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ section: NotificationInboxSection, settingsStyle: Bool = false) {
        self.settingsStyle = settingsStyle
        dateLabel.text = section.title
        OnboardingStyle.lockFigmaFont(
            dateLabel,
            size: 15,
            weight: .regular,
            color: AppColor.labelVibrantPrimary,
            kern: -0.23
        )
        SettingsSheetChrome.applyListCard(cardView, fillColor: settingsStyle ? AppColor.fillQuaternary : AppColor.dynamic(
            light: UIColor(red: 248 / 255, green: 248 / 255, blue: 251 / 255, alpha: 1),
            dark: UIColor(red: 20 / 255, green: 20 / 255, blue: 21 / 255, alpha: 1)
        ))
        cardView.clipsToBounds = false
        if let spacing = cardView.superview?.constraints.first(where: {
            $0.firstAttribute == .bottom && $0.secondItem as? UIView === cardView
        }) as? AdaptiveConstraint {
            spacing.designConstant = settingsStyle ? 12 : 16
        }
        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        section.rows.enumerated().forEach { index, item in
            let row = NotificationRowView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.configure(item, showsSeparator: index < section.rows.count - 1, settingsStyle: settingsStyle)
            row.onDismiss = { [weak self] in
                self?.onDismiss?(item.id)
            }
            rowsStackView.addArrangedSubview(row)
        }
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardView.superview?.layoutIfNeeded()
        guard !settingsStyle else {
            layer.shadowOpacity = 0
            layer.shadowPath = nil
            return
        }
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 3, height: 4)
        layer.shadowRadius = 8
        layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.45 : 0.1
        layer.shadowPath = UIBezierPath(roundedRect: cardView.convert(cardView.bounds, to: self), cornerRadius: cardView.layer.cornerRadius).cgPath
    }
}
