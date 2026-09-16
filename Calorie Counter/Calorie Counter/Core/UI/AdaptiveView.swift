import UIKit

final class AdaptiveView: UIView {
    private var storedCornerRadius: CGFloat = 0
    private var glassContainerView: UIVisualEffectView?
    private var glassEffectView: UIVisualEffectView?
    private var glassButton: UIButton?
    private var backdropBlurView: UIVisualEffectView?
    private var didApplyGlassEffect = false
    private var lastGlassBounds: CGRect = .zero

    @IBInspectable var adaptCornerRadius: Bool = false
    @IBInspectable var matchScreenCorners: Bool = false {
        didSet { refreshChrome() }
    }
    @IBInspectable var applyCardShadow: Bool = false {
        didSet { invalidateGlass() }
    }
    @IBInspectable var applyButtonGlass: Bool = false {
        didSet { invalidateGlass() }
    }
    @IBInspectable var showsDropShadow: Bool = true {
        didSet { invalidateGlass() }
    }
    var cardShadowOpacity: Float? {
        didSet { invalidateGlass() }
    }
    @IBInspectable var designShadowRadius: CGFloat = 16 {
        didSet { invalidateGlass() }
    }
    @IBInspectable var showsHairlineBorder: Bool = false {
        didSet { invalidateGlass() }
    }
    @IBInspectable var useLiveGlass: Bool = true {
        didSet { invalidateGlass() }
    }
    var cardFillColor: UIColor = AppColor.card {
        didSet { invalidateGlass() }
    }
    @IBInspectable var designCornerRadius: CGFloat = 0 {
        didSet {
            storedCornerRadius = designCornerRadius
            refreshChrome()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if designCornerRadius == 0, layer.cornerRadius > 0 {
            storedCornerRadius = layer.cornerRadius
        } else {
            storedCornerRadius = designCornerRadius
        }
        layer.cornerCurve = .continuous
        clipsToBounds = false
        refreshChrome()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: AdaptiveView, _) in
            view.invalidateGlass()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerCurve = .continuous
        clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            didApplyGlassEffect = false
            glassEffectView?.effect = nil
            glassContainerView?.effect = nil
            glassButton?.configuration = nil
        }
        refreshChrome()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshCornerRadius()
        layoutBackdropBlur()
        guard bounds != lastGlassBounds else { return }
        lastGlassBounds = bounds
        refreshGlassAndShadow()
    }

    private func invalidateGlass() {
        lastGlassBounds = .zero
        didApplyGlassEffect = false
        refreshChrome()
    }

    private func refreshChrome() {
        refreshCornerRadius()
        refreshGlassAndShadow()
    }

    private var usesCardGlass: Bool { applyCardShadow }
    private var usesButtonGlass: Bool { applyButtonGlass }
    private var usesGlass: Bool { usesCardGlass || usesButtonGlass }

    private func refreshCornerRadius() {
        guard adaptCornerRadius else { return }
        let adapted = clampedCornerRadius(CGFloat.adaptWidth(storedCornerRadius, in: self))
        layer.cornerCurve = .continuous
        if matchScreenCorners {
            applyScreenMatchedCorners(minimum: adapted)
        } else {
            layer.cornerRadius = adapted
        }
    }

    private func clampedCornerRadius(_ radius: CGFloat) -> CGFloat {
        guard bounds.width > 0, bounds.height > 0 else { return radius }
        return min(radius, min(bounds.width, bounds.height) / 2)
    }

    private func applyScreenMatchedCorners(minimum: CGFloat) {
        if #available(iOS 26.0, *) {
            let configuration = Self.screenMatchedCornerConfiguration(minimum: minimum)
            cornerConfiguration = configuration
            let bottom = effectiveRadius(corner: .bottomLeft)
            layer.cornerRadius = max(minimum, bottom)
        } else {
            layer.cornerRadius = concentricScreenCornerRadius(minimum: minimum)
        }
    }

    @available(iOS 26.0, *)
    private static func screenMatchedCornerConfiguration(minimum: CGFloat) -> UICornerConfiguration {
        .uniformEdges(
            topRadius: .fixed(Double(minimum)),
            bottomRadius: .containerConcentric(minimum: minimum)
        )
    }

    private func concentricScreenCornerRadius(minimum: CGFloat) -> CGFloat {
        guard let window else { return minimum }
        let screenRadius = window.windowScene?.screen.displayCornerRadius ?? 0
        guard screenRadius > 0 else { return minimum }
        let frameInWindow = convert(bounds, to: window)
        let leading = max(0, frameInWindow.minX - window.bounds.minX)
        let trailing = max(0, window.bounds.maxX - frameInWindow.maxX)
        let bottom = max(0, window.bounds.maxY - frameInWindow.maxY)
        let inset = min(leading, trailing, bottom)
        return max(minimum, screenRadius - inset)
    }

    private func refreshGlassAndShadow() {
        refreshBorder()
        guard usesGlass else {
            removeGlassEffect()
            removeBackdropBlur()
            clearShadow()
            return
        }
        if DesignMetrics.isInterfaceBuilder {
            removeGlassEffect()
            removeBackdropBlur()
            backgroundColor = usesButtonGlass ? OnboardingStyle.buttonGlassFill : cardFillColor
            return
        }
        if #available(iOS 26.0, *), useLiveGlass {
            removeBackdropBlur()
            installGlassEffect()
        } else {
            installCardFill()
        }
    }

    private func installCardFill() {
        removeGlassEffect()
        clipsToBounds = false
        layer.masksToBounds = false
        removeBackdropBlur()
        backgroundColor = usesButtonGlass ? OnboardingStyle.buttonGlassFill : cardFillColor
        if showsDropShadow {
            applyKitShadow()
        } else {
            clearShadow()
        }
    }

    private func installBackdropBlur() {
        if backdropBlurView == nil {
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            blur.isUserInteractionEnabled = false
            blur.clipsToBounds = true
            insertSubview(blur, at: 0)
            backdropBlurView = blur
        }
        backdropBlurView?.contentView.backgroundColor = OnboardingStyle.glassFill
        layoutBackdropBlur()
    }

    private func layoutBackdropBlur() {
        guard let backdropBlurView else { return }
        if backdropBlurView.superview !== self {
            insertSubview(backdropBlurView, at: 0)
        }
        backdropBlurView.frame = bounds
        backdropBlurView.layer.cornerRadius = layer.cornerRadius
        backdropBlurView.layer.cornerCurve = .continuous
        applyScreenMatchedCornersIfNeeded(to: backdropBlurView, radius: layer.cornerRadius)
    }

    private func removeBackdropBlur() {
        backdropBlurView?.removeFromSuperview()
        backdropBlurView = nil
    }

    private func refreshBorder() {
        guard showsHairlineBorder else {
            layer.borderWidth = 0
            layer.borderColor = nil
            return
        }
        layer.borderWidth = 1
        layer.borderColor = OnboardingStyle.fillQuaternary.resolvedColor(with: traitCollection).cgColor
    }

    private func clearShadow() {
        layer.shadowOpacity = 0
        layer.shadowPath = nil
    }

    @available(iOS 26.0, *)
    private func installGlassEffect() {
        backgroundColor = .clear
        clipsToBounds = false
        layer.masksToBounds = false
        installCardGlass()
    }

    @available(iOS 26.0, *)
    private func installCardGlass() {
        glassButton?.removeFromSuperview()
        glassButton = nil
        if showsDropShadow {
            applyKitShadow()
        } else {
            clearShadow()
        }
        let container = resolvedGlassContainer()
        let glass = resolvedGlassEffectView(in: container)
        sendSubviewToBack(container)
        layoutGlass(container: container, glass: glass)
        guard window != nil, bounds.width > 0, bounds.height > 0 else { return }
        guard !didApplyGlassEffect else { return }
        guard UIView.inheritedAnimationDuration == 0 else { return }
        didApplyGlassEffect = true
        let containerEffect = UIGlassContainerEffect()
        containerEffect.spacing = 0
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = usesButtonGlass
        container.effect = containerEffect
        glass.effect = effect
    }

    @available(iOS 26.0, *)
    private func resolvedGlassContainer() -> UIVisualEffectView {
        if let glassContainerView {
            return glassContainerView
        }
        let container = UIVisualEffectView()
        container.isUserInteractionEnabled = false
        container.clipsToBounds = true
        insertSubview(container, at: 0)
        glassContainerView = container
        return container
    }

    @available(iOS 26.0, *)
    private func resolvedGlassEffectView(in container: UIVisualEffectView) -> UIVisualEffectView {
        if let glassEffectView {
            return glassEffectView
        }
        let view = UIVisualEffectView()
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        container.contentView.addSubview(view)
        glassEffectView = view
        return view
    }

    @available(iOS 26.0, *)
    private func layoutGlass(container: UIVisualEffectView, glass: UIVisualEffectView) {
        container.frame = bounds
        if container.contentView.bounds.isEmpty {
            container.contentView.frame = container.bounds
        }
        glass.frame = container.contentView.bounds.isEmpty ? container.bounds : container.contentView.bounds
        let radius = layer.cornerRadius
        container.layer.cornerRadius = radius
        container.layer.cornerCurve = .continuous
        glass.layer.cornerRadius = radius
        glass.layer.cornerCurve = .continuous
        applyScreenMatchedCornersIfNeeded(to: container, radius: radius)
        applyScreenMatchedCornersIfNeeded(to: glass, radius: radius)
    }

    private func applyScreenMatchedCornersIfNeeded(to view: UIView, radius: CGFloat) {
        guard #available(iOS 26.0, *) else { return }
        if matchScreenCorners {
            view.cornerConfiguration = Self.screenMatchedCornerConfiguration(minimum: CGFloat.adaptWidth(storedCornerRadius, in: self))
        } else {
            view.cornerConfiguration = .corners(radius: .fixed(Double(radius)))
        }
    }

    private func applyKitShadow() {
        if usesButtonGlass {
            OnboardingStyle.applyButtonFallbackShadow(layer)
        } else {
            OnboardingStyle.applyCardFallbackShadow(
                layer,
                traits: traitCollection,
                radius: designShadowRadius
            )
            if let cardShadowOpacity { layer.shadowOpacity = cardShadowOpacity }
        }
        if bounds.width > 0, bounds.height > 0 {
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: layer.cornerRadius
            ).cgPath
        }
    }

    private func removeGlassEffect() {
        glassContainerView?.removeFromSuperview()
        glassContainerView = nil
        glassEffectView?.removeFromSuperview()
        glassEffectView = nil
        glassButton?.removeFromSuperview()
        glassButton = nil
        didApplyGlassEffect = false
    }
}
