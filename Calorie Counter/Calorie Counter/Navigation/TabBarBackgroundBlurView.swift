import UIKit

final class TabBarBackgroundBlurView: UIView {
    private let blurContainerView = UIView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let blurMask = CAGradientLayer()
    private let blurMaskView = UIView()

    private let tintGradient = CAGradientLayer()
    var neutralBackground = false { didSet { if oldValue != neutralBackground { updateTint() } } }

    var flipsVertically = false {
        didSet { applyFlip() }
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
        blurContainerView.frame = bounds
        blurView.frame = blurContainerView.bounds
        updateBlurMask()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tintGradient.frame = bounds
        CATransaction.commit()
        updateTint()
    }

    private func setup() {
        isUserInteractionEnabled = false
        isOpaque = false
        clipsToBounds = false
        backgroundColor = .clear
        blurContainerView.isUserInteractionEnabled = false
        blurContainerView.backgroundColor = .clear
        blurView.isUserInteractionEnabled = false
        blurContainerView.addSubview(blurView)
        addSubview(blurContainerView)
        blurMaskView.layer.addSublayer(blurMask)
        layer.addSublayer(tintGradient)
        applyFlip()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        blurView.effect = UIBlurEffect(style: traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        updateTint()
    }

    private func updateTint() {
        let color: UIColor = traitCollection.userInterfaceStyle == .dark ? .black
            : (neutralBackground ? .white : UIColor(red: 231/255, green: 1, blue: 252/255, alpha: 1))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tintGradient.colors = [color.withAlphaComponent(0).cgColor, color.cgColor]
        tintGradient.locations = [0, 0.86364]
        tintGradient.startPoint = CGPoint(x: 0.5, y: flipsVertically ? 1 : 0)
        tintGradient.endPoint = CGPoint(x: 0.5, y: flipsVertically ? 0 : 1)
        CATransaction.commit()
    }

    private func applyFlip() {
        updateTint()
        updateBlurMask()
    }

    private func updateBlurMask() {
        // UIKit copies an effect view's mask; resize and reassign it after layout.
        // Masking an ancestor instead prevents the live backdrop from rendering.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blurView.mask = nil
        blurMaskView.frame = blurView.bounds
        blurMask.frame = blurMaskView.bounds
        blurMask.startPoint = CGPoint(x: 0.5, y: 0)
        blurMask.endPoint = CGPoint(x: 0.5, y: 1)
        if flipsVertically {
            blurMask.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
            blurMask.locations = [0, 0.13636, 1]
        } else {
            // Fade the blur with the design's tint instead of introducing a solid material strip.
            blurMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
            blurMask.locations = [0, 0.86364, 1]
        }
        blurView.mask = blurMaskView
        CATransaction.commit()
    }
}
