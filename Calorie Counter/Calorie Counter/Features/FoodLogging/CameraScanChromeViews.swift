import UIKit

final class CameraScanOverlayView: UIView {
    var holeRect: CGRect = .zero {
        didSet { updateMaskPath() }
    }
    var holeCornerRadius: CGFloat = 26 {
        didSet { updateMaskPath() }
    }
    var overlayColor: UIColor = UIColor.black.withAlphaComponent(0.25) {
        didSet { updateFillColors() }
    }

    private let dimLayer = CAShapeLayer()
    private let plusDarkerLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dimLayer.frame = bounds
        plusDarkerLayer.frame = bounds
        updateMaskPath()
    }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        dimLayer.fillRule = .evenOdd
        plusDarkerLayer.fillRule = .evenOdd
        plusDarkerLayer.compositingFilter = "plusDarker"
        layer.addSublayer(dimLayer)
        layer.addSublayer(plusDarkerLayer)
        updateFillColors()
    }

    private func updateFillColors() {
        dimLayer.fillColor = overlayColor.cgColor
        plusDarkerLayer.fillColor = UIColor.black.withAlphaComponent(0.05).cgColor
    }

    private func updateMaskPath() {
        let path = CGMutablePath()
        path.addRect(bounds)
        if holeRect.width > 0, holeRect.height > 0 {
            path.addRoundedRect(in: holeRect, cornerWidth: holeCornerRadius, cornerHeight: holeCornerRadius)
        }
        dimLayer.path = path
        plusDarkerLayer.path = path
    }
}

final class CameraScanFrameView: UIView {
    var strokeColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }
    var lineWidth: CGFloat = 2 {
        didSet { setNeedsDisplay() }
    }
    var frameCornerRadius: CGFloat = 26 {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frameCornerRadius
        layer.cornerCurve = .continuous
    }

    override func draw(_ rect: CGRect) {
        let inset = lineWidth / 2
        let path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset),
            cornerRadius: max(0, frameCornerRadius - inset)
        )
        path.lineWidth = lineWidth
        strokeColor.setStroke()
        path.stroke()
    }
}

final class CameraScanLineView: UIView {
    var bandHeight: CGFloat = 0 {
        didSet {
            guard oldValue != bandHeight else { return }
            setNeedsLayout()
        }
    }

    private let gradientLayer = CAGradientLayer()
    private let edgeMaskLayer = CAGradientLayer()
    private var isAnimatingScan = false
    private var lastAnimationSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = resolvedBandHeight
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: height)
        if gradientLayer.animation(forKey: "scan") == nil {
            gradientLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        } else {
            gradientLayer.position.x = bounds.midX
        }
        CATransaction.commit()
        layoutEdgeMask()
        if isAnimatingScan, bounds.size != lastAnimationSize, bounds.width > 0, bounds.height > 0 {
            addScanAnimation()
        }
    }

    func startAnimating() {
        isHidden = false
        isAnimatingScan = true
        setNeedsLayout()
        layoutIfNeeded()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if lastAnimationSize != bounds.size {
            addScanAnimation()
        }
    }

    func stopAnimating() {
        isAnimatingScan = false
        lastAnimationSize = .zero
        gradientLayer.removeAnimation(forKey: "scan")
        isHidden = true
    }

    private func configure() {
        isUserInteractionEnabled = false
        isHidden = true
        backgroundColor = .clear
        clipsToBounds = true
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradientLayer)
        edgeMaskLayer.startPoint = CGPoint(x: 0.5, y: 0)
        edgeMaskLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.mask = edgeMaskLayer
        refreshColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: CameraScanLineView, _) in
            view.refreshColors()
        }
    }

    private func refreshColors() {
        gradientLayer.colors = [
            AppColor.teal.withAlphaComponent(0).cgColor,
            AppColor.teal.withAlphaComponent(0.85).cgColor,
            AppColor.teal.withAlphaComponent(0).cgColor
        ]
        edgeMaskLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.clear.cgColor
        ]
    }

    private var resolvedBandHeight: CGFloat {
        let autoHeight = bounds.height * (81.0 / 268.0)
        let height = bandHeight > 0 ? bandHeight : autoHeight
        return min(max(height, 1), max(bounds.height, 1))
    }

    private func layoutEdgeMask() {
        edgeMaskLayer.frame = bounds
        let fade = min(max(bounds.height * 0.18, .adaptHeight(12)), .adaptHeight(28))
        let location = fade / max(bounds.height, 1)
        let clamped = min(max(location, 0.08), 0.4)
        edgeMaskLayer.locations = [0, NSNumber(value: clamped), NSNumber(value: 1 - clamped), 1]
    }

    private func addScanAnimation() {
        let height = resolvedBandHeight
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = -height / 2
        animation.toValue = bounds.height + height / 2
        animation.duration = 1.5
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = false
        gradientLayer.add(animation, forKey: "scan")
        lastAnimationSize = bounds.size
    }
}

enum CameraModeChrome {
    static var titles: [String] {
        [
            L10n.tr("photo.camera.mode.aiPhoto"),
            L10n.tr("photo.camera.mode.barcode"),
            L10n.tr("photo.camera.mode.search"),
            L10n.tr("photo.camera.mode.voice")
        ]
    }
}

extension UISegmentedControl {
    func configureCameraModes(titles: [String], selectedIndex: Int) {
        apportionsSegmentWidthsByContent = false
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        clipsToBounds = true
        selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.27)
        backgroundColor = UIColor.black.withAlphaComponent(0.48)
        if numberOfSegments != titles.count {
            removeAllSegments()
            titles.enumerated().forEach { index, title in
                insertSegment(withTitle: title, at: index, animated: false)
            }
        } else {
            titles.enumerated().forEach { index, title in
                if titleForSegment(at: index) != title {
                    setTitle(title, forSegmentAt: index)
                }
            }
        }
        if selectedSegmentIndex != selectedIndex, selectedIndex >= 0, selectedIndex < numberOfSegments {
            selectedSegmentIndex = selectedIndex
        }
        applyCameraModeTitleFonts(pointSize: 13)
        shrinkCameraModeTitlesToFit()
    }

    func shrinkCameraModeTitlesToFit() {
        applyCameraModeTitleFonts(pointSize: fittedCameraModeTitleSize())
        var stack = [self as UIView]
        while let view = stack.popLast() {
            if let label = view as? UILabel {
                configureCameraModeLabel(label)
            }
            if let button = view as? UIButton, let label = button.titleLabel {
                configureCameraModeLabel(label)
            }
            stack.append(contentsOf: view.subviews)
        }
    }

    private func fittedCameraModeTitleSize() -> CGFloat {
        let base: CGFloat = 13
        let minimum = base * 0.7
        let titles = (0..<numberOfSegments).compactMap { titleForSegment(at: $0) }
        guard !titles.isEmpty, bounds.width > 1, numberOfSegments > 0 else { return base }
        let available = max((bounds.width / CGFloat(numberOfSegments)) - 12, 1)
        var size = base
        while size > minimum {
            let font = UIFont.systemFont(ofSize: size, weight: .semibold)
            let widest = titles.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
            if widest <= available { return size }
            size -= 0.5
        }
        return minimum
    }

    private func applyCameraModeTitleFonts(pointSize: CGFloat) {
        setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: pointSize, weight: .medium)
        ], for: .normal)
        setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: pointSize, weight: .semibold)
        ], for: .selected)
    }

    private func configureCameraModeLabel(_ label: UILabel) {
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.lineBreakMode = .byTruncatingTail
        label.baselineAdjustment = .alignCenters
        label.allowsDefaultTighteningForTruncation = true
    }
}
