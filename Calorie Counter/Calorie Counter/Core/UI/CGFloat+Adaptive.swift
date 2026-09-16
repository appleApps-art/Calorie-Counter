import UIKit

extension CGFloat {
    static func adaptWidth(_ designPoint: CGFloat, in view: UIView? = nil) -> CGFloat {
        let scale = view.map { DesignMetrics.widthScale(for: DesignMetrics.canvasBounds(for: $0).size) }
            ?? DesignMetrics.widthScale
        return (designPoint * scale).rounded(.toNearestOrAwayFromZero)
    }

    static func adaptHeight(_ designPoint: CGFloat, in view: UIView? = nil) -> CGFloat {
        let scale = view.map { DesignMetrics.heightScale(for: DesignMetrics.canvasBounds(for: $0).size) }
            ?? DesignMetrics.heightScale
        return (designPoint * scale).rounded(.toNearestOrAwayFromZero)
    }

    static func adaptFont(_ designPoint: CGFloat) -> CGFloat {
        // Text remains readable on a short phone and in a compact presentation.
        // Dynamic Type is applied by the owning label, independently of screen geometry.
        designPoint
    }
}
