import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class AdaptiveLayoutTests: XCTestCase {
    func testListFadesFollowScrollingAndKeyboardResizeWithoutReplacingDelegate() throws {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let scroll = UIScrollView(frame: root.bounds)
        root.addSubview(scroll)
        scroll.contentSize = CGSize(width: 402, height: 1800)
        let binder = ScrollEdgeFadeBinder()
        binder.refresh(in: root)
        let mask = try XCTUnwrap(scroll.layer.mask as? CAGradientLayer)
        for height in [CGFloat(874), 430, 667] {
            scroll.frame.size.height = height
            scroll.contentOffset.y = 240
            XCTAssertEqual(mask.frame, scroll.bounds)
            let locations = try XCTUnwrap(mask.locations)
            XCTAssertEqual(locations[1].doubleValue * Double(height), Double(CGFloat.adaptHeight(16)), accuracy: 0.01)
            XCTAssertEqual((1 - locations[2].doubleValue) * Double(height), Double(CGFloat.adaptHeight(16)), accuracy: 0.01)
        }
        binder.refresh(in: root)
        XCTAssertTrue(scroll.layer.mask === mask)
        scroll.removeFromSuperview()
        binder.refresh(in: root)
        XCTAssertNil(scroll.layer.mask)
    }

    func testContentThatFitsIsNeverFadedAndFadesOnceItOverflows() throws {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 400))
        let scroll = UIScrollView(frame: root.bounds)
        root.addSubview(scroll)
        scroll.contentSize = CGSize(width: 402, height: 380)
        let binder = ScrollEdgeFadeBinder()
        binder.refresh(in: root)
        let mask = try XCTUnwrap(scroll.layer.mask as? CAGradientLayer)
        let opaque = UIColor.black.cgColor
        XCTAssertEqual(mask.colors as? [CGColor], [opaque, opaque, opaque, opaque],
                       "Nothing is hidden past the edge, so the bottom cards must stay fully visible")

        scroll.contentSize.height = 900
        XCTAssertEqual((mask.colors as? [CGColor])?.first?.alpha, 0)
        XCTAssertEqual((mask.colors as? [CGColor])?.last?.alpha, 0)
        withExtendedLifetime(binder) {}
    }

    func testListFadesExcludeTextEditorsCarouselsAndExistingMasks() {
        let root = UIView()
        let text = UITextView()
        let carousel = UIScrollView()
        carousel.isPagingEnabled = true
        let custom = UIScrollView()
        let mask = CALayer()
        custom.layer.mask = mask
        [text, carousel, custom].forEach(root.addSubview)
        let binder = ScrollEdgeFadeBinder()
        binder.refresh(in: root)
        XCTAssertNil(text.layer.mask)
        XCTAssertNil(carousel.layer.mask)
        XCTAssertTrue(custom.layer.mask === mask)
    }

    func testDesignCanvasKeepsOriginalGeometryAndReadableFont() {
        let size = CGSize(width: 402, height: 874)
        XCTAssertEqual(DesignMetrics.widthScale(for: size), 1)
        XCTAssertEqual(DesignMetrics.heightScale(for: size), 1)
        XCTAssertEqual(CGFloat.adaptFont(17), 17)
    }

    func testShortPhoneTightensGeometryWithoutShrinkingTextToThirteenPoints() {
        let size = CGSize(width: 375, height: 667)
        XCTAssertEqual(DesignMetrics.widthScale(for: size), 375 / 402, accuracy: 0.0001)
        XCTAssertEqual(DesignMetrics.heightScale(for: size), 0.9, accuracy: 0.0001)
        XCTAssertEqual(CGFloat.adaptFont(17), 17)
    }

    func testTabletWindowUsesItsWidthWithoutAnIdiomMinimumScale() {
        let narrow = CGSize(width: 375, height: 1024)
        let full = CGSize(width: 1366, height: 1024)
        XCTAssertLessThan(DesignMetrics.widthScale(for: narrow), 1)
        XCTAssertEqual(DesignMetrics.widthScale(for: full), 1.15)
        XCTAssertLessThanOrEqual(DesignMetrics.heightScale(for: full), 1.15)
    }

    func testAdaptiveConstraintTracksItsControllerCanvasOnResize() {
        let controller = UIViewController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        let content = UIView()
        controller.view.addSubview(content)
        let width = AdaptiveConstraint(
            item: content, attribute: .width, relatedBy: .equal,
            toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100
        )
        width.designConstant = 100
        width.adaptToWidth = true
        content.addConstraint(width)
        controller.view.refreshAdaptiveLayout()
        XCTAssertEqual(width.constant, 93)

        controller.view.frame.size = CGSize(width: 820, height: 1180)
        controller.view.refreshAdaptiveLayout()
        XCTAssertEqual(width.constant, 115)
    }

    func testCompactContainerPreservesStandardButtonTapTarget() {
        let controller = UIViewController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        let button = UIButton()
        controller.view.addSubview(button)
        let height = AdaptiveConstraint(
            item: button, attribute: .height, relatedBy: .equal,
            toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 44
        )
        height.designConstant = 44
        height.adaptToHeight = true
        height.refreshConstant()
        XCTAssertEqual(height.constant, 44)
    }

    func testLocalCanvasIsNotTheContainingWindowSize() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 1366))
        let controller = UIViewController()
        window.addSubview(controller.view)
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 600)
        let label = AdaptiveLabel()
        controller.view.addSubview(label)
        XCTAssertEqual(DesignMetrics.canvasBounds(for: label).size, CGSize(width: 375, height: 600))
        XCTAssertEqual(CGFloat.adaptWidth(100, in: label), 93)
    }

    func testReadableColumnCapsTabletWidthAndRemainsFluidOnPhone() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 1024, height: 1366))
        let guide = view.makeReadableContentGuide()
        view.layoutIfNeeded()
        XCTAssertEqual(guide.layoutFrame.width, 760, accuracy: 0.5)
        XCTAssertEqual(guide.layoutFrame.midX, 512, accuracy: 0.5)

        view.frame.size = CGSize(width: 375, height: 667)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertEqual(guide.layoutFrame.width, 343, accuracy: 0.5)
        XCTAssertEqual(guide.layoutFrame.minX, 16, accuracy: 0.5)
    }

    func testOptedInLabelRespectsLargerTextWithoutCompoundingScaling() {
        let label = AdaptiveLabel()
        label.font = .systemFont(ofSize: 17)
        label.usesDynamicType = true
        label.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        label.refreshFont()
        let enlargedSize = label.font.pointSize
        XCTAssertGreaterThan(enlargedSize, 17)
        label.refreshFont()
        XCTAssertEqual(label.font.pointSize, enlargedSize, accuracy: 0.01)
    }

    func testStyledWrappingLabelCanOptIntoDynamicTypeAndKeepItsAttributedAppearance() throws {
        let label = AdaptiveLabel()
        label.text = "Налаштування харчування"
        OnboardingStyle.lockFigmaFont(label, size: 15, weight: .semibold, color: .systemBlue, kern: -0.25)
        label.applyWrapping()
        label.traitOverrides.preferredContentSizeCategory = .accessibilityLarge
        label.enableDynamicType(textStyle: .subheadline)
        let attributed = try XCTUnwrap(label.attributedText)
        let font = try XCTUnwrap(attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertGreaterThan(font.pointSize, 15)
        XCTAssertEqual(attributed.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat, -0.25)
        XCTAssertEqual(attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .systemBlue)
        XCTAssertEqual(label.numberOfLines, 0)
        label.refreshFont()
        let refreshed = try XCTUnwrap(label.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertEqual(refreshed.pointSize, font.pointSize, accuracy: 0.01)
    }
}
