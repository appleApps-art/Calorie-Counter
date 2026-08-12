import UIKit

enum DesignMetrics {
    static let baseWidth: CGFloat = 393
    static let baseHeight: CGFloat = 852

    static let padMaxWidthScale: CGFloat = 1.35
    static let padMaxHeightScale: CGFloat = 1.25
    static let padMinScale: CGFloat = 1.0

    static var canvasBounds: CGRect {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first

        if let window = scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first {
            return window.bounds
        }

        return scene?.screen.bounds ?? CGRect(x: 0, y: 0, width: baseWidth, height: baseHeight)
    }

    static var isPadIdiom: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var widthScale: CGFloat {
        scaledCoefficient(
            current: canvasBounds.width,
            reference: baseWidth,
            maxScale: padMaxWidthScale
        )
    }

    static var heightScale: CGFloat {
        scaledCoefficient(
            current: canvasBounds.height,
            reference: baseHeight,
            maxScale: padMaxHeightScale
        )
    }

    private static func scaledCoefficient(
        current: CGFloat,
        reference: CGFloat,
        maxScale: CGFloat
    ) -> CGFloat {
        guard reference > 0 else { return 1 }
        let raw = current / reference
        guard isPadIdiom else { return raw }
        return min(max(raw, padMinScale), maxScale)
    }
}
