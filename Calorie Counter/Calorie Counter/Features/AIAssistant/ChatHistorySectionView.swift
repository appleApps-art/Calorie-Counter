import UIKit

final class ChatHistorySectionView: UIView {
    @IBOutlet private weak var dateLabel: AdaptiveLabel!
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var rowsStackView: UIStackView!

    var onSelect: ((ChatHistoryRowItem) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ section: ChatHistorySection) {
        dateLabel.text = section.title
        OnboardingStyle.lockFigmaFont(
            dateLabel,
            size: 15,
            weight: .regular,
            color: AppColor.labelVibrantPrimary,
            kern: -0.23
        )
        cardView.applyCardShadow = true
        cardView.showsDropShadow = true
        cardView.showsHairlineBorder = false
        cardView.useLiveGlass = false
        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        section.rows.enumerated().forEach { index, item in
            let row = ChatHistoryRowView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.configure(item, showsSeparator: index < section.rows.count - 1)
            row.onTap = { [weak self] in
                self?.onSelect?(item)
            }
            rowsStackView.addArrangedSubview(row)
        }
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
    }
}
