import UIKit

enum AppAppearance {
    static func apply(_ mode: AppearanceMode) {
        let style = userInterfaceStyle(for: mode)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.overrideUserInterfaceStyle = style }
    }

    static func userInterfaceStyle(for mode: AppearanceMode) -> UIUserInterfaceStyle {
        switch mode {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}
