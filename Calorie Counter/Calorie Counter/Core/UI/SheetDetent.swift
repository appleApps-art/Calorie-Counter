import UIKit

enum SheetDetent {
    static func inspector(
        _ figmaHeight: CGFloat,
        canvasSize: CGSize = DesignMetrics.canvasBounds.size,
        safeAreaBottom: CGFloat = DesignMetrics.windowSafeAreaBottom,
        maximumHeight: CGFloat = .greatestFiniteMagnitude,
        minimumContentHeight: CGFloat = 0
    ) -> CGFloat {
        let scale = DesignMetrics.heightScale(for: canvasSize)
        let scaled = (figmaHeight * scale).rounded(.toNearestOrAwayFromZero)
        let minimum = (minimumContentHeight * scale).rounded(.toNearestOrAwayFromZero)
        return min(max(0, maximumHeight), max(0, scaled - safeAreaBottom, minimum))
    }
}

extension UIViewController {
    /// Tints a bottom sheet. iOS 26 draws its glass under every sheet and the tint sits on that
    /// glass; earlier systems draw nothing there, so the screen underneath showed through the
    /// sheet. They get a frosted material of their own under the same tint.
    func applySheetBackground(_ tint: UIColor) {
        if #available(iOS 26.0, *) {
            view.backgroundColor = tint
            return
        }
        view.backgroundColor = .clear
        let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.isUserInteractionEnabled = false
        backdrop.contentView.backgroundColor = tint
        view.insertSubview(backdrop, at: 0)
    }
}

extension UISheetPresentationController {
    func applyFigmaInspectorDetent(_ figmaHeight: CGFloat) {
        detents = [.custom { [weak self] context in
            guard let self else { return min(figmaHeight, context.maximumDetentValue) }
            return inspectorDetentHeight(
                figmaHeight,
                maximumHeight: context.maximumDetentValue
            )
        }]
        prefersGrabberVisible = true
        prefersScrollingExpandsWhenScrolledToEdge = false
    }

    func inspectorDetentHeight(
        _ designHeight: CGFloat,
        minimumContentHeight: CGFloat = 0,
        maximumHeight: CGFloat
    ) -> CGFloat {
        let presented = presentedViewController.viewIfLoaded
        var canvas = containerView?.bounds.size ?? DesignMetrics.canvasBounds.size
        if let presented, presented.window != nil, presented.bounds.width > 0 {
            canvas.width = presented.bounds.width
        }
        let bottom = presented?.safeAreaInsets.bottom ?? containerView?.safeAreaInsets.bottom ?? 0
        return SheetDetent.inspector(
            designHeight,
            canvasSize: canvas,
            safeAreaBottom: bottom,
            maximumHeight: maximumHeight,
            minimumContentHeight: minimumContentHeight
        )
    }
}
