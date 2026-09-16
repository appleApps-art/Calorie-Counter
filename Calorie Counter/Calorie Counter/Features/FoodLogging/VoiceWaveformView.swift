import UIKit

final class VoiceWaveformView: UIView {
    private let barCount = 45
    private let designBarWidth: CGFloat = 4
    private let designBarSpacing: CGFloat = 4
    private let designCanvasHeight: CGFloat = 140

    private let barLayers: [CALayer]
    private var heights: [CGFloat]
    private var targetLevel: CGFloat = 0.18
    private var smoothedLevel: CGFloat = 0.18
    private var isIdle = true
    private var isListening = false
    private var reduceMotion = false
    private var displayLink: CADisplayLink?
    private var lastTick: CFTimeInterval = 0

    override init(frame: CGRect) {
        (barLayers, heights) = Self.makeBars(count: 45)
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        (barLayers, heights) = Self.makeBars(count: 45)
        super.init(coder: coder)
        configure()
    }

    func showIdle() {
        stopAnimating()
        isIdle = true
        isListening = false
        heights = Self.idleHeights(count: barCount, maxHeight: bounds.height)
        applyHeights()
    }

    func showListening(level: CGFloat, reduceMotion: Bool) {
        isIdle = false
        self.reduceMotion = reduceMotion
        isListening = true
        let clamped = max(0, min(1, level))
        targetLevel = reduceMotion ? 0.72 : max(0.14, min(1, pow(clamped, 0.58)))
        if reduceMotion {
            stopAnimating()
            renderStaticListening()
            return
        }
        startAnimating()
    }

    func showRecorded() {
        stopAnimating()
        isIdle = false
        isListening = false
        applyHeights()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if isIdle {
            heights = Self.idleHeights(count: barCount, maxHeight: bounds.height)
        }
        applyHeights()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopAnimating()
        } else if isListening, !reduceMotion {
            startAnimating()
        }
    }

    deinit {
        displayLink?.invalidate()
    }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        barLayers.forEach { layer.addSublayer($0) }
    }

    private func startAnimating() {
        guard displayLink == nil else { return }
        lastTick = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 45, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc
    private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(0.033, max(1.0 / 120.0, now - lastTick))
        lastTick = now

        let follow: CGFloat = targetLevel > smoothedLevel ? 14 : 5.5
        smoothedLevel += (targetLevel - smoothedLevel) * min(1, follow * CGFloat(dt))

        let scale = barScale
        let minHeight = max(3, 6 * scale)
        let energy = 0.16 + 0.84 * smoothedLevel
        let lerp = CGFloat(1 - exp(-16 * dt))

        for index in 0..<barCount {
            let envelope = max(minHeight, Self.listeningEnvelope[index] * scale)
            let t = now * 2.15 + Double(index) * 0.41
            let waveA = 0.5 + 0.5 * sin(t)
            let waveB = 0.5 + 0.5 * sin(t * 1.63 + Double(index) * 0.19)
            let wobble = 0.38 + 0.62 * (0.45 + 0.55 * waveA) * (0.55 + 0.45 * waveB)
            let target = minHeight + (envelope - minHeight) * energy * CGFloat(wobble)
            heights[index] += (target - heights[index]) * lerp
        }
        applyHeights()
    }

    private func renderStaticListening() {
        let scale = barScale
        let energy: CGFloat = 0.72
        heights = Self.listeningEnvelope.map { design in
            max(4, design * scale * energy)
        }
        applyHeights()
    }

    private func applyHeights() {
        let barWidth = CGFloat.adaptWidth(designBarWidth)
        let spacing = CGFloat.adaptWidth(designBarSpacing)
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        var x = (bounds.width - totalWidth) / 2
        let midY = bounds.midY
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for index in 0..<barCount {
            let height = max(2, min(bounds.height, heights[index]))
            let layer = barLayers[index]
            layer.backgroundColor = UIColor.white.cgColor
            layer.cornerRadius = barWidth / 2
            layer.frame = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
            x += barWidth + spacing
        }
        CATransaction.commit()
    }

    private var barScale: CGFloat {
        let height = bounds.height
        guard height > 0 else { return 1 }
        return height / designCanvasHeight
    }

    private static func makeBars(count: Int) -> ([CALayer], [CGFloat]) {
        let layers = (0..<count).map { _ -> CALayer in
            let layer = CALayer()
            layer.backgroundColor = UIColor.white.cgColor
            layer.masksToBounds = true
            return layer
        }
        return (layers, Array(repeating: 8, count: count))
    }

    private static func idleHeights(count: Int, maxHeight: CGFloat) -> [CGFloat] {
        let cap = max(8, maxHeight * 0.16)
        return (0..<count).map { index in
            let wave = sin(CGFloat(index) * 0.37) * 0.35 + 0.65
            return max(4, cap * wave)
        }
    }

    private static let listeningEnvelope: [CGFloat] = [
        8, 14, 10, 22, 36, 24, 52, 88, 118, 112,
        70, 48, 82, 104, 60, 34, 68, 92, 54, 28,
        16, 24, 32, 12, 26, 40, 20, 60, 92, 114,
        78, 52, 86, 110, 96, 64, 40, 80, 104, 68,
        36, 22, 14, 10, 8
    ]
}
