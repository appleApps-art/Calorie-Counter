import UIKit

enum DesignMetrics {
    static let baseWidth: CGFloat = 402
    static let baseHeight: CGFloat = 874

    static let minimumWidthScale: CGFloat = 0.85
    static let maximumGeometryScale: CGFloat = 1.15

    static var isInterfaceBuilder: Bool {
        let processName = ProcessInfo.processInfo.processName
        if processName.contains("IBAgent")
            || processName.contains("IBDesignables")
            || processName.contains("IBCocoaTouch")
            || processName.contains("IBPreview")
            || processName == "ibtoold" {
            return true
        }
        return ProcessInfo.processInfo.environment.keys.contains { $0.hasPrefix("IB_") }
    }

    static var canvasBounds: CGRect {
        if isInterfaceBuilder {
            return CGRect(x: 0, y: 0, width: baseWidth, height: baseHeight)
        }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        let windows = scene?.windows ?? []

        if let window = windows.first(where: { $0.isKeyWindow && isValid($0.bounds) })
            ?? windows.first(where: { isValid($0.bounds) }) {
            return window.bounds
        }

        if let screenBounds = scene?.screen.bounds, isValid(screenBounds) {
            return screenBounds
        }

        return CGRect(x: 0, y: 0, width: baseWidth, height: baseHeight)
    }

    static var windowSafeAreaBottom: CGFloat {
        if isInterfaceBuilder { return 0 }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        let windows = scene?.windows ?? []
        let window = windows.first(where: { $0.isKeyWindow && isValid($0.bounds) })
            ?? windows.first(where: { isValid($0.bounds) })
        return window?.safeAreaInsets.bottom ?? 0
    }

    private static func isValid(_ bounds: CGRect) -> Bool {
        bounds.width > 0 && bounds.height > 0
    }

    static var isPadIdiom: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var widthScale: CGFloat {
        guard !isInterfaceBuilder else { return 1 }
        return widthScale(for: canvasBounds.size)
    }

    static var heightScale: CGFloat {
        guard !isInterfaceBuilder else { return 1 }
        return heightScale(for: canvasBounds.size)
    }

    /// A sheet or child controller has its own canvas, even when it shares an iPad window.
    static func canvasBounds(for view: UIView?) -> CGRect {
        guard !isInterfaceBuilder else {
            return CGRect(x: 0, y: 0, width: baseWidth, height: baseHeight)
        }
        var candidate = view
        while let current = candidate {
            if current.next is UIViewController, isValid(current.bounds) {
                return current.bounds
            }
            candidate = current.superview
        }
        if let bounds = view?.window?.bounds, isValid(bounds) {
            return bounds
        }
        return canvasBounds
    }

    static func widthScale(for size: CGSize) -> CGFloat {
        guard size.width.isFinite, size.width > 0 else { return 1 }
        return min(max(size.width / baseWidth, minimumWidthScale), maximumGeometryScale)
    }

    static func heightScale(for size: CGSize) -> CGFloat {
        guard size.height.isFinite, size.height > 0 else { return 1 }
        // Short screens can tighten spacing, but must not shrink controls and text by 25–40%.
        // Width also bounds growth so a tall phone does not acquire tablet-sized controls.
        return min(widthScale(for: size), max(0.9, size.height / baseHeight))
    }
}
