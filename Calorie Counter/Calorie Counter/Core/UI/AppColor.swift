import UIKit

enum AppColor {
    static let primary = color("BityPrimary", light: (93, 191, 31), dark: (107, 204, 46))
    static let primarySoft = color("BityPrimarySoft", light: (234, 247, 214))
    static let teal = color("BityTeal", light: (0, 195, 208), dark: (0, 210, 224))
    static let gray6 = color("BityGray6", light: (242, 242, 247), dark: (28, 28, 30))
    static let footerLabel = color("BityFooterLabel", light: (191, 191, 191, 1), dark: (64, 64, 64, 1))
    static let iconSecondary = color("BityIconSecondary", light: (114, 114, 114), dark: (138, 138, 138))
    static let textPrimary = color("BityTextPrimary", light: (26, 26, 26), dark: (245, 245, 245))
    static let textSecondary = color("BityTextSecondary", light: (60, 60, 67, 0.6), dark: (235, 235, 245, 0.7))
    static let labelVibrantPrimary = dynamic(light: rgb(26, 26, 26), dark: rgb(245, 245, 245))
    static let labelsPrimary = dynamic(light: .black, dark: .white)
    static let labelsSecondary = dynamic(
        light: rgb(60, 60, 67, 0.6),
        dark: rgb(235, 235, 245, 0.7)
    )
    static let labelsTertiary = dynamic(
        light: rgb(60, 60, 67, 0.3),
        dark: rgb(235, 235, 245, 0.3)
    )
    static let accentRed = dynamic(light: rgb(255, 56, 60), dark: rgb(255, 66, 69))
    static let fillPrimary = dynamic(
        light: rgb(120, 120, 128, 0.2),
        dark: rgb(120, 120, 128, 0.36)
    )
    static let fillSecondary = dynamic(
        light: rgb(120, 120, 128, 0.16),
        dark: rgb(120, 120, 128, 0.32)
    )
    static let fillQuaternary = dynamic(
        light: rgb(116, 116, 128, 0.08),
        dark: rgb(118, 118, 128, 0.18)
    )
    static let fillTertiary = dynamic(
        light: rgb(118, 118, 128, 0.12),
        dark: rgb(118, 118, 128, 0.24)
    )
    /// The hairline between rows inside a card: grey on white, lighter grey on a dark card.
    static let separatorOnCard = dynamic(
        light: rgb(230, 230, 230),
        dark: rgb(56, 56, 58)
    )
    static let separatorVibrant = dynamic(light: rgb(230, 230, 230), dark: rgb(26, 26, 26))
    static let fillVibrantTertiary = dynamic(light: rgb(240, 239, 239), dark: rgb(18, 18, 18))
    static let pageIndicator = dynamic(light: rgb(204, 204, 204), dark: rgb(108, 108, 112))
    static let textMuted = color("BityTextMuted", light: (102, 102, 105, 1), dark: (235, 235, 245, 0.45))
    static let textBody = color("BityTextBody", light: (51, 51, 54), dark: (245, 245, 245))
    static let carbs = color("BityCarbs", light: (255, 176, 32))
    static let accentBlue = dynamic(light: rgb(0, 136, 255), dark: rgb(0, 145, 255))
    static let accentIndigo = dynamic(light: rgb(97, 85, 245), dark: rgb(109, 124, 255))
    static let accentMint = dynamic(light: rgb(0, 200, 179), dark: rgb(0, 218, 195))
    static let breakfast = color("BityBreakfast", light: (255, 232, 200))
    static let lunch = color("BityLunch", light: (255, 243, 196))
    static let dinner = color("BityDinner", light: (227, 224, 255))
    static let snacks = color("BitySnacks", light: (234, 247, 214))
    static let canvas = color("BityCanvas", light: (231, 255, 252), dark: (1, 28, 31))
    static let card = color("BityCard", light: (255, 255, 255), dark: (0, 0, 0))
    static let hairline = color("BityHairline", light: (0, 0, 0, 0.12), dark: (255, 255, 255, 0.17))
    static let backgroundsPrimary = dynamic(light: .white, dark: .black)
    /// Progress in dark mode (Figma 441:47938): grey cards on a black canvas. Light keeps the app's
    /// mint canvas and white cards.
    static var progressCanvas: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? .black : canvas.resolvedColor(with: trait)
        }
    }
    static var progressSurface: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? gray6.resolvedColor(with: trait) : .white
        }
    }
    static var backgroundsPrimaryElevated: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? gray6.resolvedColor(with: trait)
                : card.resolvedColor(with: trait)
        }
    }
    static let onAccent = dynamic(light: .white, dark: .black)
    static let tabSelected = dynamic(light: rgb(0, 129, 152), dark: rgb(59, 221, 236))
    static let grabber = dynamic(light: rgb(60, 60, 67, 0.3), dark: rgb(51, 51, 51))
    /// Tint laid over the system glass on every bottom sheet, so sheets and sheet-like panels match.
    static let sheetGlassTint = dynamic(
        light: UIColor(white: 0.96, alpha: 0.35),
        dark: UIColor.black.withAlphaComponent(0.6)
    )
    /// The same tint, lighter, for the panel that shows a recognized meal. It sits over the photo or
    /// the voice screen, and at full strength its solid cards melt into it.
    static let resultPanelTint = dynamic(
        light: UIColor(white: 0.96, alpha: 0.15),
        dark: UIColor.black.withAlphaComponent(0.35)
    )
    static let overlayDefault = dynamic(
        light: rgb(0, 0, 0, 0x33 / 255),
        dark: rgb(0, 0, 0, 0x7A / 255)
    )

    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        }
    }

    static func resolved(_ color: UIColor, with traits: UITraitCollection) -> UIColor {
        color.resolvedColor(with: traits)
    }

    static func fadeColors(from color: UIColor, traits: UITraitCollection) -> [CGColor] {
        let resolved = color.resolvedColor(with: traits)
        return [
            resolved.cgColor,
            resolved.cgColor,
            resolved.withAlphaComponent(0).cgColor
        ]
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
    }

    private static func color(
        _ name: String,
        light: (Double, Double, Double, Double),
        dark: (Double, Double, Double, Double)? = nil
    ) -> UIColor {
        if let named = UIColor(named: name) {
            return named
        }
        let lightColor = rgb(CGFloat(light.0), CGFloat(light.1), CGFloat(light.2), CGFloat(light.3))
        guard let dark else { return lightColor }
        return dynamic(
            light: lightColor,
            dark: rgb(CGFloat(dark.0), CGFloat(dark.1), CGFloat(dark.2), CGFloat(dark.3))
        )
    }

    private static func color(
        _ name: String,
        light: (Double, Double, Double),
        dark: (Double, Double, Double)? = nil
    ) -> UIColor {
        color(name, light: (light.0, light.1, light.2, 1), dark: dark.map { ($0.0, $0.1, $0.2, 1) })
    }
}
