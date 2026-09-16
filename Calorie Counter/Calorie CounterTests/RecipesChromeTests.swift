import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class RecipesChromeTests: XCTestCase {
    func testTabBarBackgroundBlurFlipsForHeader() {
        let blur = TabBarBackgroundBlurView(frame: CGRect(x: 0, y: 0, width: 402, height: 99))
        XCTAssertFalse(blur.flipsVertically)
        blur.flipsVertically = true
        let imageView = blur.subviews.compactMap { $0 as? UIImageView }.first
        XCTAssertEqual(imageView?.transform.d, -1)
    }

    func testRecipesXibPinsScrollUnderHeaderAndRootBottom() throws {
        let xib = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Features/Recipes/RecipesViewController.xib")
        let xml = try String(contentsOf: xib, encoding: .utf8)
        XCTAssertTrue(xml.contains("firstItem=\"scroll\" firstAttribute=\"bottom\" secondItem=\"root\""))
        XCTAssertTrue(xml.contains("firstItem=\"scroll\" firstAttribute=\"top\" secondItem=\"root\""))
        XCTAssertTrue(xml.contains("outlet property=\"hubSlotView\""))
        XCTAssertTrue(xml.contains("clipsSubviews=\"YES\" multipleTouchEnabled=\"YES\" contentMode=\"scaleToFill\" translatesAutoresizingMaskIntoConstraints=\"NO\" id=\"scroll\""))
        XCTAssertTrue(xml.contains("firstItem=\"empty\" firstAttribute=\"top\" secondItem=\"hub-slot\""))
    }

    func testRecipesHeaderChromeDoesNotHangTabSizedBlurOverContent() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Features/Recipes/RecipesViewController.swift")
        let swift = try String(contentsOf: source, encoding: .utf8)
        XCTAssertFalse(swift.contains("adaptHeight(99)"))
        XCTAssertFalse(swift.contains("contentInset.bottom = tabHeight"))
        XCTAssertFalse(swift.contains("bringSubviewToFront(scrollView)"))
        XCTAssertTrue(swift.contains("AppColor.fadeColors("))
        XCTAssertTrue(swift.contains("from: AppColor.canvas"))
        XCTAssertTrue(swift.contains("adaptHeight(24)"))
        XCTAssertTrue(swift.contains("y: hubFrame.maxY"))
        XCTAssertTrue(swift.contains("contentInsetAdjustmentBehavior = .never"))
        XCTAssertTrue(swift.contains("topEdgeEffect.isHidden = true"))
        XCTAssertTrue(swift.contains("clipsToBounds = true"))
        XCTAssertTrue(swift.contains("tabBarOverlapInset()"))
        XCTAssertTrue(swift.contains("contentInset.bottom = bottomInset"))
    }

    func testTabBarBackgroundBlurFadesInsteadOfSolidStrip() {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Navigation/TabBarBackgroundBlurView.swift")
        let swift = try! String(contentsOf: source, encoding: .utf8)
        XCTAssertFalse(swift.contains("blurContainerView.layer.mask = blurMask"))
        XCTAssertTrue(swift.contains("0.13636"))
        XCTAssertTrue(swift.contains("systemThinMaterial"))
        XCTAssertFalse(swift.contains("blurContainerView.isHidden = flipsVertically"))

        let blur = TabBarBackgroundBlurView(frame: CGRect(x: 0, y: 0, width: 402, height: 99))
        blur.layoutIfNeeded()
        let container = blur.subviews.first { view in
            view.subviews.contains { $0 is UIVisualEffectView }
        }
        let effect = container?.subviews.compactMap { $0 as? UIVisualEffectView }.first
        XCTAssertNil(container?.layer.mask)
        XCTAssertNotNil(effect)
        XCTAssertEqual(effect?.mask?.frame, effect?.bounds)
        let footerMask = effect?.mask?.layer.sublayers?.first as? CAGradientLayer
        XCTAssertEqual(footerMask?.locations?.last, 1)
        XCTAssertLessThan(footerMask?.locations?[1].doubleValue ?? 1, 0.3)
        XCTAssertEqual(container?.isHidden, false)
        blur.flipsVertically = true
        XCTAssertEqual(effect?.mask?.frame, effect?.bounds)
        XCTAssertEqual(container?.isHidden, false)
        let mask = effect?.mask?.layer.sublayers?.first as? CAGradientLayer
        XCTAssertEqual(mask?.startPoint.y, 0)
        XCTAssertEqual(mask?.endPoint.y, 1)
        for size in [CGSize(width: 375, height: 95), CGSize(width: 440, height: 120)] {
            blur.frame.size = size
            blur.setNeedsLayout()
            blur.layoutIfNeeded()
            XCTAssertEqual(effect?.mask?.frame.size, size)
            XCTAssertEqual(mask?.frame.size, size)
            XCTAssertNil(container?.mask)
        }
    }

    func testCreateSheetXibSpacesOptionsBelowClose() throws {
        let xml = try String(contentsOf: recipesFeatureURL("RecipesCreateSheetViewController.xib"), encoding: .utf8)
        XCTAssertTrue(
            xml.contains("firstItem=\"grid\" firstAttribute=\"top\" secondItem=\"close-wrap\" secondAttribute=\"bottom\" constant=\"30\"")
        )
        XCTAssertTrue(
            xml.contains("firstItem=\"safe\" firstAttribute=\"bottom\" relation=\"greaterThanOrEqual\" secondItem=\"grid\" secondAttribute=\"bottom\" constant=\"6\"")
        )
        XCTAssertFalse(
            xml.contains("firstItem=\"grid\" firstAttribute=\"top\" secondItem=\"close-wrap\" secondAttribute=\"bottom\" id=\"gt\"")
        )
    }

    func testCreateSheetDetentFitsContentInsteadOfHalfScreen() throws {
        let swift = try String(contentsOf: recipesFeatureURL("RecipesCreateSheetViewController.swift"), encoding: .utf8)
        XCTAssertTrue(swift.contains("16 + 44 + 30 + 68 + 6"))
        XCTAssertFalse(swift.contains("adaptHeight(198)"))
        XCTAssertEqual(
            RecipesCreateSheetViewController.sheetDetentHeight,
            164,
            accuracy: 0.5
        )
        XCTAssertLessThan(
            RecipesCreateSheetViewController.sheetDetentHeight,
            .adaptHeight(260)
        )
    }

    func testCreateSheetLaysOutGapBetweenCloseAndOptions() {
        let sheet = RecipesCreateSheetViewController { _ in }
        sheet.loadViewIfNeeded()
        let height = RecipesCreateSheetViewController.sheetDetentHeight
        sheet.view.frame = CGRect(x: 0, y: 0, width: 402, height: height)
        sheet.view.layoutIfNeeded()

        guard let grid = firstVerticalStack(in: sheet.view) else {
            return XCTFail("Create sheet options stack is missing")
        }
        let closeWrap = sheet.view.subviews.first { subview in
            abs(subview.bounds.height - 44) < 1
                && abs(subview.bounds.width - 44) < 1
        }
        XCTAssertNotNil(closeWrap)
        guard let closeWrap else { return }
        XCTAssertEqual(grid.frame.minY - closeWrap.frame.maxY, 30, accuracy: 1)
        XCTAssertEqual(grid.frame.height, 68, accuracy: 1)
    }

    private func recipesFeatureURL(_ file: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Features/Recipes/\(file)")
    }

    private func firstVerticalStack(in view: UIView) -> UIStackView? {
        if let stack = view as? UIStackView, stack.axis == .vertical {
            return stack
        }
        for subview in view.subviews {
            if let stack = firstVerticalStack(in: subview) {
                return stack
            }
        }
        return nil
    }
}
