import UIKit

final class HomeBackgroundView: UIView {
    private let canvasGradient = CAGradientLayer()
    private let washGradient = CAGradientLayer()

    @IBInspectable var usesHomeWash: Bool = true {
        didSet { refreshColors() }
    }
    @IBInspectable var usesSolidCanvas: Bool = false {
        didSet { refreshColors() }
    }
    @IBInspectable var usesPrimaryBackgroundInDark: Bool = false {
        didSet { refreshColors() }
    }

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
        canvasGradient.frame = bounds
        washGradient.frame = bounds
        refreshColors()
    }

    private func setup() {
        canvasGradient.startPoint = CGPoint(x: 0.22, y: 0)
        canvasGradient.endPoint = CGPoint(x: 0.78, y: 0.42)
        washGradient.startPoint = CGPoint(x: 0.18, y: 0)
        washGradient.endPoint = CGPoint(x: 0.9, y: 0.33)
        layer.addSublayer(canvasGradient)
        layer.addSublayer(washGradient)
        refreshColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: HomeBackgroundView, _) in
            view.refreshColors()
        }
    }

    private func refreshColors() {
        let traits = traitCollection
        if usesSolidCanvas {
            let color = usesPrimaryBackgroundInDark && traits.userInterfaceStyle == .dark
                ? AppColor.backgroundsPrimary : AppColor.canvas
            let fill = color.resolvedColor(with: traits)
            canvasGradient.colors = [fill.cgColor, fill.cgColor]
            washGradient.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            return
        }
        if !usesHomeWash {
            let fill = AppColor.backgroundsPrimary.resolvedColor(with: traits)
            canvasGradient.colors = [fill.cgColor, fill.cgColor]
            washGradient.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            return
        }
        let canvas = AppColor.canvas.resolvedColor(with: traits)
        let card = AppColor.card.resolvedColor(with: traits)
        let isDark = traits.userInterfaceStyle == .dark
        canvasGradient.colors = [
            canvas.cgColor,
            (isDark ? canvas : card).cgColor
        ]
        let washAlpha: CGFloat = isDark ? 0.18 : 0.35
        washGradient.colors = [
            AppColor.teal.withAlphaComponent(washAlpha).resolvedColor(with: traits).cgColor,
            UIColor.clear.cgColor
        ]
    }
}
