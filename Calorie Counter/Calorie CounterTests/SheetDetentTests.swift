import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class SheetDetentTests: XCTestCase {
    func testInspectorFitsACompactPresentationInsteadOfExceedingItsMaximum() {
        XCTAssertEqual(
            SheetDetent.inspector(592, canvasSize: CGSize(width: 375, height: 375), safeAreaBottom: 0, maximumHeight: 300),
            300
        )
    }

    func testInspectorUsesItsPresentationCanvasAndSafeArea() {
        XCTAssertEqual(
            SheetDetent.inspector(260, canvasSize: CGSize(width: 402, height: 874), safeAreaBottom: 34, maximumHeight: 800),
            226
        )
        XCTAssertEqual(
            SheetDetent.inspector(260, canvasSize: CGSize(width: 375, height: 1024), safeAreaBottom: 0, maximumHeight: 800),
            243
        )
    }

    func testInspectorRespectsMinimumContentWithoutExceedingPresentation() {
        let size = CGSize(width: 402, height: 874)
        XCTAssertEqual(
            SheetDetent.inspector(198, canvasSize: size, safeAreaBottom: 34, maximumHeight: 800, minimumContentHeight: 174),
            174
        )
        XCTAssertEqual(
            SheetDetent.inspector(198, canvasSize: size, safeAreaBottom: 34, maximumHeight: 150, minimumContentHeight: 174),
            150
        )
    }

    func testInspectorDetentSubtractsHomeIndicatorFromFigmaHeight() {
        let figmaHeight: CGFloat = 260
        let expected = max(0, CGFloat.adaptHeight(figmaHeight) - DesignMetrics.windowSafeAreaBottom)
        XCTAssertEqual(SheetDetent.inspector(figmaHeight), expected, accuracy: 0.5)
        if DesignMetrics.windowSafeAreaBottom > 0 {
            XCTAssertLessThan(SheetDetent.inspector(figmaHeight), .adaptHeight(figmaHeight))
        }
    }

    func testOptionSheetXibsPinToSafeAreaInsteadOfHomeIndicatorPadding() throws {
        let files = [
            "Home/QuickLogSheetViewController.xib",
            "Progress/ProgressLogSheetViewController.xib",
            "Recipes/AddToPantrySheetViewController.xib",
            "Recipes/RecipesCreateSheetViewController.xib"
        ]
        for file in files {
            let xml = try String(contentsOf: featureURL(file), encoding: .utf8)
            XCTAssertTrue(
                xml.contains("firstItem=\"safe\" firstAttribute=\"bottom\" relation=\"greaterThanOrEqual\" secondItem=\"grid\" secondAttribute=\"bottom\" constant=\"6\""),
                file
            )
            XCTAssertFalse(
                xml.contains("firstAttribute=\"bottom\" relation=\"greaterThanOrEqual\" secondItem=\"grid\" secondAttribute=\"bottom\" constant=\"32\""),
                file
            )
        }
    }

    func testGlassVolumeButtonKeepsItsBottomInsetWhenSheetHeightChanges() throws {
        let controller = GlassVolumeSheetViewController(milliliters: 150) { _ in }
        controller.loadViewIfNeeded()
        let button = try XCTUnwrap(controller.value(forKey: "saveButton") as? UIButton)
        for height: CGFloat in [386, 450, 600] {
            controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: height)
            controller.view.refreshAdaptiveLayout()
            controller.view.layoutIfNeeded()
            let frame = button.convert(button.bounds, to: controller.view)
            // Figma: 32 pt to the screen edge minus the sheet's 6 pt floating inset.
            let expected = (26 * DesignMetrics.heightScale(for: controller.view.bounds.size)).rounded()
            XCTAssertEqual(controller.view.bounds.maxY - frame.maxY, expected, accuracy: 1)
            XCTAssertFalse(button.hasAmbiguousLayout)
        }
    }

    func testGlassVolumeFormStaysUnderHeaderWhileKeyboardExpandsSheet() throws {
        let controller = GlassVolumeSheetViewController(milliliters: 150) { _ in }
        controller.loadViewIfNeeded()
        let field = try XCTUnwrap(controller.value(forKey: "valueField") as? UITextField)
        let save = try XCTUnwrap(controller.value(forKey: "saveButton") as? UIButton)
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 386)
        controller.textFieldDidBeginEditing(field)
        controller.view.refreshAdaptiveLayout()
        controller.view.layoutIfNeeded()
        let originalField = field.convert(field.bounds, to: controller.view)
        let originalSave = save.convert(save.bounds, to: controller.view)

        controller.view.frame.size.height = 700
        controller.view.refreshAdaptiveLayout()
        controller.view.layoutIfNeeded()
        let expandedField = field.convert(field.bounds, to: controller.view)
        let expandedSave = save.convert(save.bounds, to: controller.view)
        XCTAssertEqual(expandedField.minY, originalField.minY, accuracy: 1)
        XCTAssertEqual(expandedSave.maxY, originalSave.maxY, accuracy: 1)
        XCTAssertLessThan(expandedSave.maxY, 386)
        XCTAssertEqual(field.text, "150")

        field.text = "275"
        controller.textFieldDidEndEditing(field)
        controller.view.frame.size.height = 386
        controller.view.refreshAdaptiveLayout()
        controller.view.layoutIfNeeded()
        let restoredSave = save.convert(save.bounds, to: controller.view)
        XCTAssertEqual(controller.view.bounds.maxY - restoredSave.maxY, 23, accuracy: 1)
        XCTAssertTrue(field.text?.contains("275") == true)
    }

    func testGlassPresetsFitOnOneLineAfterRepeatedInputChanges() throws {
        let controller = GlassVolumeSheetViewController(milliliters: 150) { _ in }
        controller.loadViewIfNeeded()
        let field = try XCTUnwrap(controller.value(forKey: "valueField") as? UITextField)
        let buttons = try ["chip150", "chip200", "chip250", "chip330"].map {
            try XCTUnwrap(controller.value(forKey: $0) as? UIButton)
        }
        for width: CGFloat in [320, 359, 386, 402] {
            controller.view.frame = CGRect(x: 0, y: 0, width: width, height: 700)
            controller.textFieldDidBeginEditing(field)
            for digits in ["3", "33", "330", "275", ""] {
                field.text = digits
                field.sendActions(for: .editingChanged)
                controller.view.refreshAdaptiveLayout()
                controller.view.layoutIfNeeded()
                for button in buttons {
                    button.layoutIfNeeded()
                    let label = try XCTUnwrap(button.titleLabel)
                    let text = try XCTUnwrap(label.text)
                    let measured = (text as NSString).size(withAttributes: [.font: label.font!])
                    XCTAssertLessThanOrEqual(label.bounds.height, label.font.lineHeight + 1)
                    XCTAssertLessThanOrEqual(measured.width * label.minimumScaleFactor, label.bounds.width + 1)
                }
            }
            controller.textFieldDidEndEditing(field)
        }
    }

    func testOptionSheetsUseFigmaInspectorDetent() throws {
        let files = [
            "Home/QuickLogSheetViewController.swift",
            "Progress/ProgressLogSheetViewController.swift",
            "Recipes/AddToPantrySheetViewController.swift"
        ]
        for file in files {
            let swift = try String(contentsOf: featureURL(file), encoding: .utf8)
            XCTAssertTrue(swift.contains("applyFigmaInspectorDetent(260)"), file)
            XCTAssertFalse(swift.contains("resolver: { _ in 260 }"), file)
        }
        let volume = try String(contentsOf: featureURL("Home/GlassVolumeSheetViewController.swift"), encoding: .utf8)
        XCTAssertTrue(volume.contains("applyFigmaInspectorDetent(386)"))
    }

    private func featureURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Features/\(path)")
    }
}
