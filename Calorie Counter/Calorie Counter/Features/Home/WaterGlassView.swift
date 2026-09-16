import UIKit

final class WaterGlassView: UIView {
    private(set) var fillProgress: CGFloat = 0

    private let clipView = UIView()
    private let emptyView = UIView()
    private let liquidLayer = CAShapeLayer()
    private let splashLayer = CAShapeLayer()
    private let maskLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()

    private var displayedProgress: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var pour: Pour?

    private struct Pour {
        let start: CFTimeInterval
        let from: CGFloat
        let to: CGFloat
        let delay: TimeInterval
        let duration: TimeInterval
        let isPour: Bool
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        displayLink?.invalidate()
    }

    func setFillProgress(_ progress: CGFloat, animated: Bool, delay: TimeInterval = 0) {
        let clamped = min(max(progress, 0), 1)
        let from = displayedProgress
        fillProgress = clamped
        guard bounds.height > 0, abs(clamped - from) > 0.001 else {
            displayedProgress = clamped
            renderIdle()
            return
        }
        guard animated, window != nil else {
            displayedProgress = clamped
            renderIdle()
            return
        }
        let isPour = clamped > from
        let duration = (isPour ? 0.78 : 0.42) + 0.22 * abs(clamped - from)
        pour = Pour(
            start: CACurrentMediaTime(),
            from: from,
            to: clamped,
            delay: delay,
            duration: duration,
            isPour: isPour
        )
        startDisplayLink()
        if clamped < 0.999 {
            strokeLayer.isHidden = false
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopDisplayLink()
            displayedProgress = fillProgress
            renderIdle()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        clipView.frame = bounds
        emptyView.frame = bounds
        liquidLayer.frame = bounds
        splashLayer.frame = bounds
        let path = glassPath()
        maskLayer.frame = bounds
        maskLayer.path = path.cgPath
        clipView.layer.mask = maskLayer
        strokeLayer.path = path.cgPath
        strokeLayer.fillColor = UIColor.clear.cgColor
        strokeLayer.strokeColor = UIColor.black.withAlphaComponent(0.12).cgColor
        strokeLayer.lineWidth = 1
        if pour == nil {
            renderIdle()
        }
    }

    @objc
    private func tick(_ link: CADisplayLink) {
        guard let pour else {
            stopDisplayLink()
            return
        }
        let elapsed = link.timestamp - pour.start - pour.delay
        if elapsed < 0 {
            return
        }
        let linear = min(max(elapsed / pour.duration, 0), 1)
        let fillT = easeInOut(linear)
        displayedProgress = pour.from + (pour.to - pour.from) * fillT
        let wave = pour.isPour
            ? (1 - linear) * .adaptHeight(2.4)
            : (1 - linear) * .adaptHeight(0.8)
        let phase = CGFloat(elapsed) * 14
        let splash = pour.isPour && linear < 0.78
            ? 0.35 + 0.65 * abs(sin(elapsed * 16))
            : 0
        render(
            progress: displayedProgress,
            amplitude: wave,
            phase: phase,
            splash: splash
        )
        if linear >= 1 {
            displayedProgress = pour.to
            self.pour = nil
            stopDisplayLink()
            renderIdle()
        }
    }

    private func renderIdle() {
        render(progress: displayedProgress, amplitude: 0, phase: 0, splash: 0)
        updateStroke()
    }

    private func render(
        progress: CGFloat,
        amplitude: CGFloat,
        phase: CGFloat,
        splash: CGFloat
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        liquidLayer.path = liquidPath(progress: progress, amplitude: amplitude, phase: phase).cgPath
        splashLayer.path = splashPath(progress: progress, strength: splash).cgPath
        splashLayer.opacity = Float(min(splash, 1) * 0.55)
        CATransaction.commit()
    }

    private func liquidPath(progress: CGFloat, amplitude: CGFloat, phase: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        guard progress > 0.001, bounds.height > 0 else { return path }
        let surface = bounds.height * (1 - min(progress, 1))
        let amp = progress >= 0.995 ? 0 : amplitude
        path.move(to: CGPoint(x: 0, y: bounds.height))
        path.addLine(to: CGPoint(x: 0, y: surface))
        let steps = 14
        for index in 0...steps {
            let x = bounds.width * CGFloat(index) / CGFloat(steps)
            let wave = amp * sin((x / max(bounds.width, 1)) * .pi * 2.1 + phase)
            path.addLine(to: CGPoint(x: x, y: surface + wave))
        }
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        path.close()
        return path
    }

    private func splashPath(progress: CGFloat, strength: CGFloat) -> UIBezierPath {
        guard strength > 0.05, progress < 0.98, bounds.height > 0 else { return UIBezierPath() }
        let surface = bounds.height * (1 - min(progress, 1))
        let width = .adaptWidth(10) * strength
        let height = .adaptHeight(3.2) * strength
        let rect = CGRect(
            x: bounds.midX - width / 2,
            y: surface - height / 2,
            width: width,
            height: height
        )
        return UIBezierPath(ovalIn: rect)
    }

    private func glassPath() -> UIBezierPath {
        let top = CGFloat.adaptWidth(6)
        let bottom = CGFloat.adaptWidth(18)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: top, y: 0))
        path.addLine(to: CGPoint(x: bounds.width - top, y: 0))
        path.addArc(
            withCenter: CGPoint(x: bounds.width - top, y: top),
            radius: top,
            startAngle: -.pi / 2,
            endAngle: 0,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - bottom))
        path.addArc(
            withCenter: CGPoint(x: bounds.width - bottom, y: bounds.height - bottom),
            radius: bottom,
            startAngle: 0,
            endAngle: .pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: bottom, y: bounds.height))
        path.addArc(
            withCenter: CGPoint(x: bottom, y: bounds.height - bottom),
            radius: bottom,
            startAngle: .pi / 2,
            endAngle: .pi,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: 0, y: top))
        path.addArc(
            withCenter: CGPoint(x: top, y: top),
            radius: top,
            startAngle: .pi,
            endAngle: -.pi / 2,
            clockwise: true
        )
        path.close()
        return path
    }

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func startDisplayLink() {
        if displayLink != nil { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateStroke() {
        strokeLayer.isHidden = fillProgress >= 0.999
    }

    private func refreshLiquidColor() {
        let water = AppColor.teal.resolvedColor(with: traitCollection).cgColor
        liquidLayer.fillColor = water
        splashLayer.fillColor = water
    }

    private func setup() {
        backgroundColor = .clear
        emptyView.backgroundColor = OnboardingStyle.fillQuaternary
        refreshLiquidColor()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: WaterGlassView, _) in
            view.refreshLiquidColor()
        }
        [liquidLayer, splashLayer].forEach { layer in
            layer.actions = [
                "path": NSNull(),
                "opacity": NSNull(),
                "bounds": NSNull(),
                "position": NSNull()
            ]
        }
        clipView.addSubview(emptyView)
        clipView.layer.addSublayer(liquidLayer)
        clipView.layer.addSublayer(splashLayer)
        addSubview(clipView)
        layer.addSublayer(strokeLayer)
        isUserInteractionEnabled = false
        clipsToBounds = false
    }
}
