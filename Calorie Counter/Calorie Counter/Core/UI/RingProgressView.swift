import UIKit

final class RingProgressView: UIView {
    @IBInspectable var lineWidth: CGFloat = 13 {
        didSet { setNeedsLayout() }
    }

    @IBInspectable var progress: CGFloat = 0 {
        didSet { progressLayer.strokeEnd = min(max(progress, 0), 1) }
    }

    var trackColor: UIColor = AppColor.primarySoft {
        didSet { refreshStrokeColors() }
    }

    var progressColor: UIColor = AppColor.primary {
        didSet { refreshStrokeColors() }
    }

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true
        layer.masksToBounds = true
        trackLayer.frame = bounds
        progressLayer.frame = bounds
        let inset = lineWidth / 2
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: max(0, min(bounds.width, bounds.height) / 2 - inset),
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        let width = CGFloat.adaptWidth(lineWidth)
        trackLayer.lineWidth = width
        progressLayer.lineWidth = width
        refreshStrokeColors()
    }

    private func setup() {
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true
        layer.masksToBounds = true
        for layer in [trackLayer, progressLayer] {
            layer.fillColor = UIColor.clear.cgColor
            layer.lineCap = .round
            layer.contentsScale = UIScreen.main.scale
            self.layer.addSublayer(layer)
        }
        refreshStrokeColors()
        progressLayer.strokeEnd = min(max(progress, 0), 1)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: RingProgressView, _) in
            view.refreshStrokeColors()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        isOpaque = false
    }

    private func refreshStrokeColors() {
        let traits = traitCollection
        trackLayer.strokeColor = trackColor.resolvedColor(with: traits).cgColor
        progressLayer.strokeColor = progressColor.resolvedColor(with: traits).cgColor
    }
}