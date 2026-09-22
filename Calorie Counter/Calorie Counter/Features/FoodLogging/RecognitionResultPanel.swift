import UIKit

/// The panel that slides up with a recognized meal, on the photo scanner and in the voice log.
/// Both screens build it from the same pieces, so it is styled in one place.
enum RecognitionResultPanel {
    /// The panel is system glass with a light tint of the sheet colour; the cards on it are solid,
    /// as in the design, so they keep their edges against whatever shows through the glass.
    static func style(sheet: AdaptiveView, tint: UIView, cards: [AdaptiveView]) {
        sheet.useLiveGlass = true
        sheet.applyCardShadow = true
        sheet.showsDropShadow = true
        sheet.matchScreenCorners = true
        tint.backgroundColor = AppColor.resultPanelTint
        tint.isUserInteractionEnabled = false
        tint.frame = sheet.bounds
        tint.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tint.layer.cornerCurve = .continuous
        if tint.superview !== sheet {
            sheet.insertSubview(tint, at: 0)
        }
        cards.forEach { card in
            card.useLiveGlass = false
            card.applyCardShadow = true
            card.showsDropShadow = true
            card.cardFillColor = AppColor.backgroundsPrimary
            card.layer.borderWidth = 0
        }
    }

    /// The tint follows the panel's screen-matched corners, which are only known after layout.
    static func layout(tint: UIView, in sheet: AdaptiveView) {
        tint.frame = sheet.bounds
        if #available(iOS 26.0, *) {
            tint.cornerConfiguration = sheet.cornerConfiguration
        } else {
            tint.layer.cornerRadius = sheet.layer.cornerRadius
        }
    }

    /// A spinner in the middle of the meal photo slot, shown while its picture is still on the way.
    static func setImageLoading(_ loading: Bool, spinner: UIActivityIndicatorView, in imageView: UIImageView) {
        if spinner.superview !== imageView {
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.hidesWhenStopped = true
            spinner.color = AppColor.labelsSecondary
            imageView.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
            ])
        }
        if loading && imageView.image == nil {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }
}

/// Lets the result panel be pulled down to close, like a system sheet: it follows the finger,
/// closes past a quarter of its height or on a flick, and otherwise springs back.
final class ResultPanelSwipeDismissal: NSObject, UIGestureRecognizerDelegate {
    private weak var panel: UIView?
    private weak var scrollView: UIScrollView?
    private let onDismiss: () -> Void
    private let pan = UIPanGestureRecognizer()

    init(panel: UIView, scrollView: UIScrollView?, onDismiss: @escaping () -> Void) {
        self.panel = panel
        self.scrollView = scrollView
        self.onDismiss = onDismiss
        super.init()
        pan.addTarget(self, action: #selector(handlePan(_:)))
        pan.delegate = self
        panel.addGestureRecognizer(pan)
        // The content scrolls only once the pull is not a close.
        scrollView?.panGestureRecognizer.require(toFail: pan)
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let panel else { return }
        let distance = pan.translation(in: panel.superview).y
        switch pan.state {
        case .changed:
            // Down follows the finger; up gives only a little, as a system sheet does.
            let offset = distance >= 0 ? distance : -sqrt(-distance) * 2
            panel.transform = CGAffineTransform(translationX: 0, y: offset)
        case .ended, .cancelled, .failed:
            let velocity = pan.velocity(in: panel.superview).y
            let closes = pan.state == .ended && distance > 0
                && (distance > panel.bounds.height * 0.25 || velocity > 900)
            if closes {
                UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
                    panel.transform = CGAffineTransform(translationX: 0, y: panel.bounds.height)
                } completion: { [onDismiss] _ in
                    // Already off screen; the screen's own close must not slide it back up.
                    panel.alpha = 0
                    onDismiss()
                }
            } else {
                UIView.animate(
                    withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                    options: [.beginFromCurrentState]
                ) {
                    panel.transform = .identity
                }
            }
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan, let panel else { return true }
        let velocity = pan.velocity(in: panel)
        guard abs(velocity.y) > abs(velocity.x) else { return false }
        // Over the scrolling content only a pull down from its very top closes the panel.
        if let scrollView, scrollView.bounds.contains(pan.location(in: scrollView)) {
            let atTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 0.5
            return velocity.y > 0 && atTop
        }
        return true
    }
}
