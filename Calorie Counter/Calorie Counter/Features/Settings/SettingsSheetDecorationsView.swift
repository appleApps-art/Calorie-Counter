import UIKit

final class SettingsSheetDecorationsView: UIView {
    private struct Placement {
        let name: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let rotationDegrees: CGFloat
        let flipX: Bool
    }

    private static let canvasWidth: CGFloat = 402
    private static let canvasHeight: CGFloat = 813

    private static let placements: [Placement] = [
        Placement(name: "VoiceLogObject08", x: -74, y: 535, width: 184, height: 172, rotationDegrees: -25.83, flipX: false),
        Placement(name: "VoiceLogObject07", x: 48, y: 546, width: 104, height: 96, rotationDegrees: 40.12, flipX: false),
        Placement(name: "VoiceLogObject06", x: 226, y: 548, width: 77, height: 73, rotationDegrees: 22.76, flipX: false),
        Placement(name: "VoiceLogObject05", x: 158, y: 500, width: 260, height: 235, rotationDegrees: 57.01, flipX: false),
        Placement(name: "VoiceLogObject04", x: 87, y: 519, width: 197, height: 183, rotationDegrees: -30.89, flipX: false),
        Placement(name: "VoiceLogObject03", x: 224, y: 611, width: 45, height: 44, rotationDegrees: -13.16, flipX: false),
        Placement(name: "VoiceLogObject02", x: 370, y: 564, width: 110, height: 100, rotationDegrees: -2.75, flipX: true),
        Placement(name: "VoiceLogObject01", x: 63, y: 607, width: 74, height: 65, rotationDegrees: 9.43, flipX: false)
    ]

    private let imageViews: [UIImageView]
    private let darkBackgroundView = UIImageView(image: UIImage(named: "SettingsSheetDarkBackground"))

    override init(frame: CGRect) {
        imageViews = Self.makeImageViews()
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        imageViews = Self.makeImageViews()
        super.init(coder: coder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        darkBackgroundView.frame = bounds
        let scaleX = bounds.width / Self.canvasWidth
        let scaleY = bounds.height / Self.canvasHeight
        for (index, placement) in Self.placements.enumerated() {
            let view = imageViews[index]
            view.bounds = CGRect(
                x: 0,
                y: 0,
                width: placement.width * scaleX,
                height: placement.height * scaleY
            )
            view.center = CGPoint(
                x: (placement.x + placement.width / 2) * scaleX,
                y: (placement.y + placement.height / 2) * scaleY
            )
            var transform = CGAffineTransform(rotationAngle: placement.rotationDegrees * .pi / 180)
            if placement.flipX {
                transform = transform.scaledBy(x: -1, y: 1)
            }
            view.transform = transform
        }
    }

    private static func makeImageViews() -> [UIImageView] {
        placements.map { placement in
            let view = UIImageView(image: UIImage(named: placement.name))
            view.contentMode = .scaleAspectFit
            view.clipsToBounds = true
            return view
        }
    }

    private func configure() {
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        clipsToBounds = true
        backgroundColor = .clear
        imageViews.forEach { addSubview($0) }
        darkBackgroundView.contentMode = .scaleToFill
        addSubview(darkBackgroundView)
        refreshAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: SettingsSheetDecorationsView, _) in
            view.refreshAppearance()
        }
    }
    private func refreshAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        darkBackgroundView.isHidden = !isDark
        imageViews.forEach { $0.isHidden = isDark }
    }
}

enum SettingsSheetChrome {
    static func apply(to view: UIView) {
        view.backgroundColor = AppColor.gray6
    }

    static func applyListCard(_ card: AdaptiveView, fillColor: UIColor = AppColor.dynamic(light: AppColor.fillQuaternary, dark: AppColor.backgroundsPrimary)) {
        card.adaptCornerRadius = true
        card.designCornerRadius = 24
        card.showsDropShadow = false
        card.showsHairlineBorder = false
        card.useLiveGlass = false
        card.applyCardShadow = false
        card.clipsToBounds = true
        card.backgroundColor = fillColor
    }
}
