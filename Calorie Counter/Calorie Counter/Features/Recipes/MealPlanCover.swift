import UIKit

/// A plan holds a week of different dishes, so no single photo stands for it. Its cover is drawn:
/// the plan's name on a colour of its own, the same on the card in the list and on the plan itself.
enum MealPlanCover {
    private static let cache = NSCache<NSString, UIImage>()

    /// One per plan, so two plans side by side never look like the same card.
    private static let palettes: [(top: UIColor, bottom: UIColor)] = [
        (AppColor.teal, AppColor.accentMint),
        (rgb(0xFF, 0x8A, 0x5B), rgb(0xFF, 0xC8, 0x6B)),
        (rgb(0x6C, 0x7B, 0xFF), rgb(0x9B, 0xC1, 0xFF)),
        (rgb(0xE4, 0x5C, 0x8C), rgb(0xFF, 0x9A, 0xC1)),
        (rgb(0x3F, 0xB9, 0x8A), rgb(0x9F, 0xE0, 0xA8)),
        (rgb(0x8A, 0x6B, 0xFF), rgb(0xC6, 0xA8, 0xFF))
    ]

    static func image(
        title: String,
        size: CGSize,
        traits: UITraitCollection
    ) -> UIImage? {
        guard size.width > 1, size.height > 1 else { return nil }
        // Scrolling re-lays out the cards, and drawing a cover on every pass is what made it stutter.
        let key = "\(title)|\(Int(size.width))x\(Int(size.height))|\(traits.userInterfaceStyle.rawValue)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let variant = variantIndex(for: title)
        let palette = palettes[variant % palettes.count]
        let isDark = traits.userInterfaceStyle == .dark
        let top = shade(palette.top.resolvedColor(with: traits), dark: isDark)
        let bottom = shade(palette.bottom.resolvedColor(with: traits), dark: isDark)
        // The gradients stay saturated in both themes, so the name is white on them either way.
        let text = UIColor.white
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            drawBowls(in: context.cgContext, size: size, color: text.withAlphaComponent(0.16), variant: variant)
            draw(title: title, in: context, size: size, color: text)
        }
        cache.setObject(drawn, forKey: key)
        return drawn
    }

    /// A numbered plan keeps its own colour; anything else gets a stable one from its name.
    /// Swift's own hashing is seeded per launch, so the covers would otherwise change on every start.
    static func variantIndex(for title: String) -> Int {
        let digits = title.drop { !$0.isNumber }.prefix { $0.isNumber }
        if let number = Int(digits), number > 0 {
            return (number - 1) % palettes.count
        }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(title.utf8) {
            hash = (hash ^ UInt64(byte)) &* 0x1000_0000_01b3
        }
        return Int(hash % UInt64(palettes.count))
    }

    private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
        UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }

    /// The same palette, calmer in the dark, so a card does not glow on a black screen.
    private static func shade(_ color: UIColor, dark: Bool) -> UIColor {
        guard dark else { return color }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return color }
        return UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.78, alpha: alpha)
    }

    private static func draw(
        title: String,
        in context: UIGraphicsImageRendererContext,
        size: CGSize,
        color: UIColor
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let inset = size.width * 0.08
        let available = CGSize(width: size.width - inset * 2, height: size.height * 0.8)
        // A long name wraps and steps down in size rather than ending in an ellipsis.
        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color, .paragraphStyle: paragraph]
        var height = available.height
        for step in stride(from: 0.18, through: 0.07, by: -0.01) {
            attributes[.font] = UIFont.systemFont(ofSize: max(11, size.height * step), weight: .semibold)
            height = (title as NSString).boundingRect(
                with: CGSize(width: available.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: attributes,
                context: nil
            ).height
            if height <= available.height { break }
        }
        let bounds = CGRect(
            x: inset,
            y: max(0, (size.height - height) / 2),
            width: available.width,
            height: min(height, size.height)
        )
        (title as NSString).draw(with: bounds, options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
    }

    /// Plates, faint enough to read as texture rather than a picture, laid out differently per plan.
    private static func drawBowls(in context: CGContext, size: CGSize, color: UIColor, variant: Int) {
        context.setFillColor(color.cgColor)
        let unit = size.height
        let layouts: [[(x: CGFloat, y: CGFloat, side: CGFloat)]] = [
            [(-0.18, 0.55, 0.62), (0.78, -0.22, 0.72), (0.62, 0.62, 0.46)],
            [(0.70, 0.48, 0.70), (-0.12, -0.20, 0.58), (0.28, 0.74, 0.38)],
            [(-0.22, 0.05, 0.74), (0.66, 0.58, 0.60), (0.34, -0.16, 0.40)],
            [(0.06, 0.62, 0.52), (0.52, -0.24, 0.66), (0.86, 0.46, 0.50)],
            [(0.80, 0.10, 0.64), (-0.16, 0.44, 0.56), (0.40, 0.80, 0.44)],
            [(0.14, -0.18, 0.58), (0.74, 0.66, 0.68), (-0.20, 0.72, 0.42)]
        ]
        let layout = layouts[variant % layouts.count]
        layout.forEach { circle in
            // x is a share of the width, y and the size a share of the height, so it scales with the card.
            let side = unit * circle.side
            context.fillEllipse(in: CGRect(
                x: size.width * circle.x,
                y: unit * circle.y,
                width: side,
                height: side
            ))
        }
    }
}
