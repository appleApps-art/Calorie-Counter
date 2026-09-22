import UIKit
import XCTest
@testable import Calorie_Counter

final class ChatMarkdownRendererTests: XCTestCase {
    private let style = ChatMarkdownRenderer.Style(font: .systemFont(ofSize: 17), color: .black, kern: -0.43)

    func testBoldIsShownBoldWithoutItsStars() throws {
        let text = ChatMarkdownRenderer.attributed("**Білки:** 120 г на день", style: style)
        XCTAssertEqual(text.string, "Білки: 120 г на день")
        let bold = try XCTUnwrap(text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let regular = try XCTUnwrap(text.attribute(.font, at: text.length - 1, effectiveRange: nil) as? UIFont)
        XCTAssertGreaterThan(weight(of: bold), weight(of: regular))
    }

    func testHeadingsLoseTheirHashes() {
        let text = ChatMarkdownRenderer.attributed("### Ваш план\nВсе добре.", style: style)
        XCTAssertEqual(text.string, "Ваш план\nВсе добре.")
    }

    func testListsGetABulletAndAHangingIndent() throws {
        let text = ChatMarkdownRenderer.attributed("- Сніданок: омлет\n- Обід: курка з рисом\n1. Перше\n2) Друге", style: style)
        XCTAssertEqual(text.string, "•\tСніданок: омлет\n•\tОбід: курка з рисом\n1.\tПерше\n2.\tДруге")
        let paragraph = try XCTUnwrap(text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertGreaterThan(paragraph.headIndent, 0, "Wrapped lines line up with the text, not the dot")
    }

    func testATableReadsAsRows() {
        let text = ChatMarkdownRenderer.attributed("| День | Ккал |\n|---|---|\n| 1 | 2 000 |", style: style)
        XCTAssertEqual(text.string, "•\tДень · Ккал\n•\t1 · 2 000")
    }

    func testStrayMarkersNeverReachTheReader() {
        let text = ChatMarkdownRenderer.attributed("Це **важливо і забуто закрити", style: style)
        XCTAssertFalse(text.string.contains("**"))
        XCTAssertEqual(ChatMarkdownRenderer.plainText("**Разом:** `1 800` ккал"), "Разом: 1 800 ккал")
    }

    func testABlankLineSeparatesParagraphsWithoutAnEmptyLine() throws {
        let text = ChatMarkdownRenderer.attributed("Перший абзац.\n\n\nДругий абзац.", style: style)
        XCTAssertEqual(text.string, "Перший абзац.\nДругий абзац.")
        let second = (text.string as NSString).range(of: "Другий").location
        let paragraph = try XCTUnwrap(text.attribute(.paragraphStyle, at: second, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertGreaterThan(paragraph.paragraphSpacingBefore, 2, "The gap is spacing, not an empty line")
    }

    private func weight(of font: UIFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return traits?[.weight] as? CGFloat ?? 0
    }
}
