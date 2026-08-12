import UIKit

extension CGFloat {
    static func adaptWidth(_ designPoint: CGFloat) -> CGFloat {
        (designPoint * DesignMetrics.widthScale).rounded(.toNearestOrAwayFromZero)
    }

    static func adaptHeight(_ designPoint: CGFloat) -> CGFloat {
        (designPoint * DesignMetrics.heightScale).rounded(.toNearestOrAwayFromZero)
    }

    static func adaptFont(_ designPoint: CGFloat) -> CGFloat {
        .adaptHeight(designPoint)
    }
}
