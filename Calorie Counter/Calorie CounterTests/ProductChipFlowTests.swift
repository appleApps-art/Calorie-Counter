import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class ProductChipFlowTests: XCTestCase {
    func testWrapPutsOverflowChipOnNextRow() {
        let rows = ProductChipFlow.wrap(
            widths: [120, 120, 120],
            maxWidth: 250,
            spacing: 8
        )
        XCTAssertEqual(rows, [[0, 1], [2]])
    }

    func testWrapKeepsSingleChipEvenWhenWiderThanRow() {
        let rows = ProductChipFlow.wrap(
            widths: [400],
            maxWidth: 250,
            spacing: 8
        )
        XCTAssertEqual(rows, [[0]])
    }

    func testFittedWidthGrowsWithTitle() {
        let short = ProductChipFlow.makeChip(title: "Egg", action: {})
        let long = ProductChipFlow.makeChip(title: "Tomato", action: {})
        XCTAssertGreaterThan(ProductChipFlow.fittedWidth(long), ProductChipFlow.fittedWidth(short))
        XCTAssertGreaterThan(ProductChipFlow.fittedWidth(short), 40)
    }

    func testTwelvePantryChipsDoNotShareOneRow() {
        let widths = Array(repeating: CGFloat(90), count: 12)
        let rows = ProductChipFlow.wrap(widths: widths, maxWidth: 346, spacing: 8)
        XCTAssertGreaterThan(rows.count, 1)
        rows.forEach { row in
            let used = row.enumerated().reduce(CGFloat(0)) { total, item in
                total + widths[item.element] + (item.offset == 0 ? 0 : 8)
            }
            XCTAssertLessThanOrEqual(used, 346)
        }
    }
}
