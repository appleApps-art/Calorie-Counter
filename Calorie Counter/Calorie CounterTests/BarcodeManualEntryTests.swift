import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class BarcodeManualEntryTests: XCTestCase {
    func testTheKeypadHasNoSecondLookUpButtonAboveIt() throws {
        let screen = loadedScreen()
        let field = try XCTUnwrap(firstView(of: UITextField.self, in: screen.view))
        XCTAssertNil(field.inputAccessoryView, "The design has one button, inside the sheet")
        XCTAssertEqual(field.keyboardType, .numberPad)
    }

    func testTheButtonStaysFilledWhileTheBarcodeIsStillBeingTyped() throws {
        let screen = loadedScreen()
        let field = try XCTUnwrap(firstView(of: UITextField.self, in: screen.view))
        let button = try XCTUnwrap(firstView(of: UIButton.self, in: screen.view) { $0.configuration?.title != nil })

        field.text = "12"
        field.sendActions(for: .editingChanged)
        XCTAssertEqual(button.alpha, 1, accuracy: 0.001, "Never greyed out, as in both states of the design")
        XCTAssertTrue(button.isEnabled)
    }

    func testTheFormSitsAboveTheKeyboardInsteadOfUnderTheTitle() throws {
        let screen = loadedScreen()
        let guide = screen.view.keyboardLayoutGuide
        let pinned = screen.view.constraints.contains { constraint in
            (constraint.firstItem === guide && constraint.firstAttribute == .top)
                || (constraint.secondItem === guide && constraint.secondAttribute == .top)
        }
        XCTAssertTrue(pinned, "The card and the button follow the keyboard, leaving no empty gap")
    }

    func testTheSheetKeepsOneHeightSoTheKeyboardDoesNotStretchIt() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Calorie Counter/Features/FoodLogging/BarcodeScannerViewController.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("applyFigmaInspectorDetent(305)"))
        XCTAssertFalse(source.contains("barcodeManualKeyboard"), "The taller keyboard detent left a gap")
    }

    // MARK: - Helpers

    private func loadedScreen() -> BarcodeManualEntryViewController {
        let screen = BarcodeManualEntryViewController()
        screen.view.frame = CGRect(x: 0, y: 0, width: 402, height: 305)
        screen.loadViewIfNeeded()
        screen.view.layoutIfNeeded()
        return screen
    }

    private func firstView<T: UIView>(of type: T.Type, in root: UIView, where match: (T) -> Bool = { _ in true }) -> T? {
        var stack = [root]
        while let view = stack.popLast() {
            if let found = view as? T, match(found) { return found }
            stack.append(contentsOf: view.subviews)
        }
        return nil
    }
}
