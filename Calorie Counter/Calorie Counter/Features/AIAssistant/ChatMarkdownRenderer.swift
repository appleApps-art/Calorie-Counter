import UIKit

/// Bity answers in Markdown. A label shows it as written, so the chat was full of `**` and `###`.
/// This turns the parts a chat reply actually uses into styled text: bold, italics, headings,
/// bullet and numbered lists with a hanging indent, and tables flattened into readable rows.
enum ChatMarkdownRenderer {
    struct Style {
        var font: UIFont
        var color: UIColor
        var kern: CGFloat
    }

    private enum Block: Equatable {
        case paragraph(String)
        case heading(String)
        case bullet(String, depth: Int)
        case numbered(marker: String, text: String, depth: Int)
        case blank
    }

    static func attributed(_ markdown: String, style: Style) -> NSAttributedString {
        // The app's copy uses no long dashes; a reply that slips one in gets a plain hyphen.
        let normalized = markdown
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
        let blocks = parse(normalized)
        let result = NSMutableAttributedString()
        var needsBreak = false
        var pendingGap = false
        for block in blocks {
            if case .blank = block {
                pendingGap = needsBreak
                continue
            }
            if needsBreak {
                result.append(NSAttributedString(string: "\n", attributes: baseAttributes(style)))
            }
            let rendered = render(block, style: style, spacedFromPrevious: pendingGap)
            result.append(rendered)
            needsBreak = true
            pendingGap = false
        }
        return result
    }

    /// The same reply without any markup, for places that show it as one plain line.
    static func plainText(_ markdown: String) -> String {
        attributed(markdown, style: Style(font: .systemFont(ofSize: 17), color: .label, kern: 0)).string
    }

    // MARK: - Blocks

    private static func parse(_ markdown: String) -> [Block] {
        var blocks: [Block] = []
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        for raw in lines {
            let indent = raw.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            let depth = min(indent / 2, 3)
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if blocks.last != .blank { blocks.append(.blank) }
                continue
            }
            if line.allSatisfy({ "-*_=".contains($0) }), line.count >= 3 {
                if blocks.last != .blank { blocks.append(.blank) }
                continue
            }
            if line.hasPrefix("#") {
                let text = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    blocks.append(.heading(text))
                    continue
                }
            }
            if line.hasPrefix("|") {
                let cells = line
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                // The |---|---| line under a table header carries nothing to read.
                if cells.allSatisfy({ $0.allSatisfy { "-:".contains($0) } }) { continue }
                if !cells.isEmpty {
                    blocks.append(.bullet(cells.joined(separator: " · "), depth: 0))
                }
                continue
            }
            if let bullet = bulletText(line) {
                blocks.append(.bullet(bullet, depth: depth))
                continue
            }
            if let numbered = numberedItem(line) {
                blocks.append(.numbered(marker: numbered.marker, text: numbered.text, depth: depth))
                continue
            }
            blocks.append(.paragraph(line))
        }
        while blocks.last == .blank { blocks.removeLast() }
        while blocks.first == .blank { blocks.removeFirst() }
        return blocks
    }

    private static func bulletText(_ line: String) -> String? {
        for marker in ["- ", "* ", "• ", "+ ", "– "] where line.hasPrefix(marker) {
            // "**Bold**" is emphasis, not a bullet.
            if marker == "* ", line.hasPrefix("**") { return nil }
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private static func numberedItem(_ line: String) -> (marker: String, text: String)? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3 else { return nil }
        let rest = line.dropFirst(digits.count)
        guard let separator = rest.first, separator == "." || separator == ")",
              rest.dropFirst().first == " " else { return nil }
        return ("\(digits).", String(rest.dropFirst(2)))
    }

    // MARK: - Rendering

    private static func render(_ block: Block, style: Style, spacedFromPrevious: Bool) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacingBefore = spacedFromPrevious ? style.font.pointSize * 0.5 : 2
        var attributes = baseAttributes(style)
        let text: NSMutableAttributedString
        switch block {
        case .paragraph(let value):
            text = NSMutableAttributedString(attributedString: inline(value, attributes: attributes, style: style))
        case .heading(let value):
            attributes[.font] = weighted(style.font, .semibold)
            if !spacedFromPrevious { paragraph.paragraphSpacingBefore = style.font.pointSize * 0.4 }
            text = NSMutableAttributedString(attributedString: inline(value, attributes: attributes, style: style))
        case .bullet(let value, let depth):
            text = listItem(marker: "•", body: value, depth: depth, paragraph: paragraph, attributes: attributes, style: style)
        case .numbered(let marker, let value, let depth):
            text = listItem(marker: marker, body: value, depth: depth, paragraph: paragraph, attributes: attributes, style: style)
        case .blank:
            text = NSMutableAttributedString()
        }
        text.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: text.length))
        return text
    }

    /// The marker hangs in the margin and wrapped lines line up with the text, not under the dot.
    private static func listItem(
        marker: String,
        body: String,
        depth: Int,
        paragraph: NSMutableParagraphStyle,
        attributes: [NSAttributedString.Key: Any],
        style: Style
    ) -> NSMutableAttributedString {
        let markerWidth = ceil(("\(marker) " as NSString).size(withAttributes: [.font: style.font]).width)
        let step = style.font.pointSize * 1.2
        let start = CGFloat(depth) * step
        let textStart = start + max(markerWidth, step)
        paragraph.firstLineHeadIndent = start
        paragraph.headIndent = textStart
        paragraph.tabStops = [NSTextTab(textAlignment: .natural, location: textStart)]
        paragraph.defaultTabInterval = textStart
        var markerAttributes = attributes
        if marker == "•" { markerAttributes[.foregroundColor] = AppColor.teal }
        let item = NSMutableAttributedString(string: "\(marker)\t", attributes: markerAttributes)
        item.append(inline(body, attributes: attributes, style: style))
        return item
    }

    private static func inline(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        style: Style
    ) -> NSAttributedString {
        let baseFont = attributes[.font] as? UIFont ?? style.font
        guard let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return NSAttributedString(string: strippingMarkers(text), attributes: attributes)
        }
        let out = NSMutableAttributedString()
        for run in parsed.runs {
            var piece = attributes
            let intent = run.inlinePresentationIntent ?? []
            var font = baseFont
            if intent.contains(.stronglyEmphasized) { font = weighted(font, .semibold) }
            if intent.contains(.emphasized) { font = italic(font) }
            if intent.contains(.code) {
                font = .monospacedSystemFont(ofSize: baseFont.pointSize * 0.94, weight: .regular)
            }
            piece[.font] = font
            if intent.contains(.strikethrough) {
                piece[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            if run.link != nil {
                piece[.foregroundColor] = AppColor.tabSelected
            }
            out.append(NSAttributedString(string: String(parsed[run.range].characters), attributes: piece))
        }
        // An unclosed "**" is left as text by the parser; it still should not reach the reader.
        let cleaned = out.mutableString
        for marker in ["**", "__"] {
            cleaned.replaceOccurrences(of: marker, with: "", options: [], range: NSRange(location: 0, length: cleaned.length))
        }
        return out
    }

    private static func strippingMarkers(_ text: String) -> String {
        ["**", "__", "`"].reduce(text) { $0.replacingOccurrences(of: $1, with: "") }
    }

    private static func baseAttributes(_ style: Style) -> [NSAttributedString.Key: Any] {
        [.font: style.font, .foregroundColor: style.color, .kern: style.kern]
    }

    private static func weighted(_ font: UIFont, _ weight: UIFont.Weight) -> UIFont {
        let isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
        let bold = UIFont.systemFont(ofSize: font.pointSize, weight: weight)
        return isItalic ? italic(bold) : bold
    }

    private static func italic(_ font: UIFont) -> UIFont {
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(
            font.fontDescriptor.symbolicTraits.union(.traitItalic)
        ) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
