import UIKit

final class ShimmerView: UIView {
    private let highlight = UIView()
    private let highlightGradient = CAGradientLayer()
    private var isActive = false
    private var displayLink: CADisplayLink?
    private var becomeActiveObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
        clipsToBounds = true
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        backgroundColor = AppColor.fillVibrantTertiary
        highlight.isUserInteractionEnabled = false
        highlight.backgroundColor = .clear
        highlightGradient.startPoint = CGPoint(x: 0, y: 0.5)
        highlightGradient.endPoint = CGPoint(x: 1, y: 0.5)
        highlightGradient.actions = [
            "colors": NSNull(),
            "locations": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull()
        ]
        highlight.layer.addSublayer(highlightGradient)
        addSubview(highlight)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ShimmerView, _) in
            view.refreshColors()
        }
        becomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartDisplayLink()
        }
        refreshColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopDisplayLink()
        if let becomeActiveObserver {
            NotificationCenter.default.removeObserver(becomeActiveObserver)
        }
    }

    func apply(cornerRadius: CGFloat) {
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
    }

    func start() {
        isHidden = false
        isActive = true
        restartDisplayLink()
    }

    func stop() {
        isActive = false
        isHidden = true
        stopDisplayLink()
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            stopDisplayLink()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHighlightFrame(time: CACurrentMediaTime())
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopDisplayLink()
            return
        }
        if isActive {
            restartDisplayLink()
        }
    }

    private func refreshColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let base = AppColor.fillVibrantTertiary.resolvedColor(with: traitCollection)
        let sheen = isDark ? UIColor.white : AppColor.card.resolvedColor(with: traitCollection)
        let shoulder: CGFloat = isDark ? 0.05 : 0.18
        let peak: CGFloat = isDark ? 0.18 : 0.62
        backgroundColor = isDark ? UIColor.white.withAlphaComponent(0.10) : base
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightGradient.colors = [
            sheen.withAlphaComponent(0).cgColor,
            sheen.withAlphaComponent(shoulder).cgColor,
            sheen.withAlphaComponent(peak).cgColor,
            sheen.withAlphaComponent(shoulder).cgColor,
            sheen.withAlphaComponent(0).cgColor
        ]
        highlightGradient.locations = [0, 0.32, 0.5, 0.68, 1]
        CATransaction.commit()
    }

    private func restartDisplayLink() {
        stopDisplayLink()
        guard isActive, window != nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        updateHighlightFrame(time: CACurrentMediaTime())
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc
    private func tick(_ link: CADisplayLink) {
        updateHighlightFrame(time: link.timestamp)
    }

    private func updateHighlightFrame(time: CFTimeInterval) {
        let width = bounds.width
        let height = bounds.height
        guard width > 1, height > 1 else {
            highlight.frame = .zero
            return
        }
        let sweep = max(width * 0.72, 56)
        let cycle: CFTimeInterval = 1.35
        let linear = CGFloat(time.truncatingRemainder(dividingBy: cycle) / cycle)
        let progress = Self.easeInOut(linear)
        let x = -sweep + (width + sweep) * progress
        highlight.frame = CGRect(x: x, y: 0, width: sweep, height: height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightGradient.frame = highlight.bounds
        CATransaction.commit()
    }

    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
