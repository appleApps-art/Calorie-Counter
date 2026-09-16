import UIKit

final class VoiceLogDecorationsView: UIView {
    private struct Placement {
        let name: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private let placements: [Placement] = [
        Placement(name: "VoiceLogObject08", x: 338, y: 18, width: 73, height: 83),
        Placement(name: "VoiceLogObject07", x: 311, y: 112, width: 127, height: 125),
        Placement(name: "VoiceLogObject06", x: 278, y: 198, width: 159, height: 162),
        Placement(name: "VoiceLogObject01", x: 304, y: 268, width: 119, height: 116),
        Placement(name: "VoiceLogObject02", x: 316, y: 352, width: 108, height: 107),
        Placement(name: "VoiceLogObject03", x: 292, y: 438, width: 121, height: 118),
        Placement(name: "VoiceLogObject04", x: 314, y: 534, width: 108, height: 114),
        Placement(name: "VoiceLogObject05", x: 336, y: 628, width: 79, height: 84)
    ]

    private let imageViews: [UIImageView]
    private var didPlayIntro = false

    override init(frame: CGRect) {
        imageViews = placements.map { placement in
            let view = UIImageView(image: UIImage(named: placement.name))
            view.contentMode = .scaleAspectFit
            view.clipsToBounds = true
            view.alpha = 0.15
            return view
        }
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        imageViews = placements.map { placement in
            let view = UIImageView(image: UIImage(named: placement.name))
            view.contentMode = .scaleAspectFit
            view.clipsToBounds = true
            view.alpha = 0.15
            return view
        }
        super.init(coder: coder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scaleX = bounds.width / DesignMetrics.baseWidth
        let scaleY = bounds.height / DesignMetrics.baseHeight
        for (index, placement) in placements.enumerated() {
            imageViews[index].frame = CGRect(
                x: placement.x * scaleX,
                y: placement.y * scaleY,
                width: placement.width * scaleX,
                height: placement.height * scaleY
            )
        }
    }

    func playIntroIfNeeded() {
        guard !didPlayIntro else { return }
        didPlayIntro = true
        if UIAccessibility.isReduceMotionEnabled {
            imageViews.forEach { $0.alpha = 0.15 }
            return
        }
        for (index, view) in imageViews.enumerated() {
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            UIView.animate(
                withDuration: 2,
                delay: Double(index) * 0.04,
                options: [.curveEaseOut]
            ) {
                view.alpha = 0.15
                view.transform = .identity
            }
        }
    }

    private func configure() {
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        clipsToBounds = true
        backgroundColor = .clear
        imageViews.forEach { addSubview($0) }
    }
}
