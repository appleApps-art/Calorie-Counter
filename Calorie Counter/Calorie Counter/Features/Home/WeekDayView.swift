import UIKit

final class WeekDayView: UIControl {
    @IBOutlet private weak var weekdayLabel: AdaptiveLabel!
    @IBOutlet private weak var dateLabel: AdaptiveLabel!
    @IBOutlet private weak var dateCircleView: AdaptiveView!

    private let dashedLayer = CAShapeLayer()
    private var item: HomeWeekDay?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshCircle()
        refreshSelectionChrome()
    }

    func configure(_ item: HomeWeekDay) {
        self.item = item
        weekdayLabel.text = item.weekday
        dateLabel.text = item.dayNumber
        weekdayLabel.textColor = item.isSelected || item.isToday ? AppColor.primary : AppColor.textSecondary
        dateLabel.textColor = AppColor.textPrimary
        refreshCircle()
        refreshSelectionChrome()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        subviews.first?.isUserInteractionEnabled = false
        dashedLayer.fillColor = UIColor.clear.cgColor
        dashedLayer.lineWidth = 1
        dateCircleView?.layer.addSublayer(dashedLayer)
        dateCircleView?.clipsToBounds = false
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: WeekDayView, _) in
            guard let item = view.item else { return }
            view.configure(item)
        }
    }

    private func refreshCircle() {
        guard let dateCircleView, dateCircleView.bounds.width > 0 else { return }
        dashedLayer.path = UIBezierPath(ovalIn: dateCircleView.bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
        let selected = item?.isSelected == true
        let today = item?.isToday == true
        dashedLayer.strokeColor = (selected || today ? AppColor.primary : AppColor.textSecondary)
            .resolvedColor(with: traitCollection).cgColor
        dashedLayer.lineDashPattern = selected ? nil : [3, 2]
    }

    private func refreshSelectionChrome() {
        let selected = item?.isSelected == true
        backgroundColor = selected ? AppColor.card : .clear
        layer.cornerRadius = .adaptWidth(13)
        if selected {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.1
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowRadius = .adaptWidth(20)
        } else {
            layer.shadowOpacity = 0
        }
        layer.masksToBounds = false
    }
}
