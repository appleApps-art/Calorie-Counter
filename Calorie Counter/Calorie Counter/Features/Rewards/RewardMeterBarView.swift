import UIKit

final class RewardMeterBarView: UIView {
    var progress: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    private let fillView = UIView()

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
        let radius = bounds.height / 2
        layer.cornerRadius = radius
        fillView.layer.cornerRadius = radius
        let width = max(0, bounds.width * min(1, max(0, progress)))
        fillView.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
    }

    private func commonInit() {
        backgroundColor = AppColor.fillPrimary
        clipsToBounds = true
        fillView.backgroundColor = AppColor.teal
        addSubview(fillView)
    }
}
