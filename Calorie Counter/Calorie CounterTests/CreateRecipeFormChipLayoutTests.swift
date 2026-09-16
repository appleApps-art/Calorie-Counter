import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class CreateRecipeFormChipLayoutTests: XCTestCase {
    private var hostWindow: UIWindow?

    private let pantryNames = [
        "кефір",
        "шпинат",
        "авокадо",
        "лосось",
        "яблучний сік",
        "сирні згустки",
        "помідори",
        "яблучний сир",
        "лососина",
        "томатна паста",
        "smoked salmon",
        "plain yogurt"
    ]

    override func tearDown() {
        hostWindow?.isHidden = true
        hostWindow = nil
        super.tearDown()
    }

    func testCreateRecipePantryTagsShowFullTitlesOnFormWidth() {
        let laidOut = layoutChips(titles: pantryNames, maxWidth: 346)
        XCTAssertEqual(laidOut.buttons.map(\.title), pantryNames)
        XCTAssertGreaterThan(laidOut.rows.count, 1)
        laidOut.buttons.forEach { chip in
            assertRenderedTitleIsComplete(chip.button, title: chip.title, maxWidth: 346)
        }
    }

    func testLongPantryTagIsNotEllipsized() {
        let laidOut = layoutChips(titles: ["томатна паста", "smoked salmon"], maxWidth: 346)
        laidOut.buttons.forEach { chip in
            assertRenderedTitleIsComplete(chip.button, title: chip.title, maxWidth: 346)
        }
    }

    private struct LaidOutChips {
        var rows: [[Int]]
        var buttons: [(button: UIButton, title: String)]
    }

    private func layoutChips(titles: [String], maxWidth: CGFloat) -> LaidOutChips {
        let spacing = CGFloat.adaptWidth(8)
        let buttons = titles.map { ProductChipFlow.makeChip(title: $0, action: {}) }
        let naturals = buttons.map(ProductChipFlow.fittedWidth)
        let rows = ProductChipFlow.wrap(widths: naturals, maxWidth: maxWidth, spacing: spacing)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = .adaptHeight(8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let host = UIView(frame: CGRect(x: 0, y: 0, width: maxWidth, height: 600))
        host.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            stack.topAnchor.constraint(equalTo: host.topAnchor)
        ])
        rows.forEach { indexes in
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = spacing
            indexes.forEach { index in
                let button = buttons[index]
                let constraint = button.widthAnchor.constraint(
                    equalToConstant: min(naturals[index], maxWidth)
                )
                constraint.priority = .required
                constraint.isActive = true
                row.addArrangedSubview(button)
            }
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(spacer)
            stack.addArrangedSubview(row)
        }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: maxWidth, height: 600))
        window.addSubview(host)
        hostWindow = window
        window.layoutIfNeeded()
        host.layoutIfNeeded()
        return LaidOutChips(
            rows: rows,
            buttons: zip(buttons, titles).map { ($0, $1) }
        )
    }

    private func assertRenderedTitleIsComplete(_ button: UIButton, title: String, maxWidth: CGFloat) {
        button.layoutIfNeeded()
        let needed = ProductChipFlow.fittedWidth(button)
        if needed <= maxWidth {
            XCTAssertGreaterThanOrEqual(
                button.bounds.width,
                needed - 1,
                "Tag '\(title)' was squeezed to \(button.bounds.width), needs \(needed)"
            )
        }
        guard let label = button.titleLabel else {
            XCTFail("Tag '\(title)' has no titleLabel")
            return
        }
        XCTAssertEqual(label.text, title, "Tag rendered '\(label.text ?? "")' instead of '\(title)'")
        XCTAssertFalse((label.text ?? "").contains("…"))
        let fitted = (title as NSString).size(withAttributes: [.font: label.font as Any]).width
        XCTAssertLessThanOrEqual(
            fitted,
            label.bounds.width + 1.5,
            "Tag '\(title)' is visually truncated (\(fitted) > \(label.bounds.width))"
        )
    }
}
