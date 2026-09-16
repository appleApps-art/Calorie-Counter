import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class SegmentControlResizeTests: XCTestCase {
    func testRecipeSelectionPillStaysUnderItsLabelAcrossParentResizes() throws {
        let host = UIViewController()
        let control = RecipeHubSegmentControl()
        control.configure(titles: ["Усі", "Збережені", "Плани"], selectedIndex: 0)
        host.view.addSubview(control)

        for width: CGFloat in [375, 834, 320] {
            resize(control, in: host, to: width)
            try assertSelection(in: control, title: "Усі", identifier: "recipeHub.selectionIndicator", segments: 3)
        }
    }

    func testProgressSelectionPillStaysUnderItsLabelAcrossParentResizes() throws {
        let host = UIViewController()
        let control = ProgressPeriodControl()
        control.selectedPeriod = .month
        host.view.addSubview(control)

        for width: CGFloat in [375, 834, 320] {
            resize(control, in: host, to: width)
            try assertSelection(in: control, title: ProgressChartPeriod.month.title, identifier: "progressPeriod.selectionIndicator", segments: 4)
        }
    }

    func testSelectionMovesToEveryLabelAfterTabletLayout() throws {
        let host = UIViewController()
        let recipes = RecipeHubSegmentControl()
        let titles = ["Усі", "Збережені", "Плани"]
        recipes.configure(titles: titles, selectedIndex: 0)
        host.view.addSubview(recipes)
        resize(recipes, in: host, to: 834)
        for index in titles.indices {
            recipes.selectedIndex = index
            try assertSelection(in: recipes, title: titles[index], identifier: "recipeHub.selectionIndicator", segments: 3)
        }

        let progress = ProgressPeriodControl()
        host.view.addSubview(progress)
        resize(progress, in: host, to: 834)
        for period in ProgressChartPeriod.allCases {
            progress.selectedPeriod = period
            try assertSelection(in: progress, title: period.title, identifier: "progressPeriod.selectionIndicator", segments: 4)
        }
    }

    private func resize(_ control: UIView, in host: UIViewController, to width: CGFloat) {
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: 1000)
        control.frame = CGRect(x: 0, y: 20, width: width, height: control.intrinsicContentSize.height)
        host.view.refreshAdaptiveLayout()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        control.layoutIfNeeded()
    }

    private func assertSelection(in control: UIView, title: String, identifier: String, segments: CGFloat) throws {
        let views = descendants(of: control)
        let label = try XCTUnwrap(views.compactMap { $0 as? UILabel }.first { $0.text == title })
        let pill = try XCTUnwrap(views.first { $0.accessibilityIdentifier == identifier })
        let labelFrame = label.convert(label.bounds, to: control)
        let pillFrame = pill.convert(pill.bounds, to: control)
        XCTAssertEqual(pillFrame.minX, labelFrame.minX, accuracy: 0.5)
        XCTAssertEqual(pillFrame.maxX, labelFrame.maxX, accuracy: 0.5)
        XCTAssertGreaterThan(pillFrame.width, (control.bounds.width - 40) / segments)
        XCTAssertGreaterThan(pillFrame.height, 20)
        XCTAssertLessThanOrEqual(pillFrame.minY, labelFrame.minY + 0.5)
        XCTAssertGreaterThanOrEqual(pillFrame.maxY + 0.5, labelFrame.maxY)
        XCTAssertGreaterThanOrEqual(pillFrame.minX, 0)
        XCTAssertLessThanOrEqual(pillFrame.maxX, control.bounds.width)
        let track = try XCTUnwrap(pill.superview)
        let stack = try XCTUnwrap(label.superview)
        let pillIndex = try XCTUnwrap(track.subviews.firstIndex(of: pill))
        let stackIndex = try XCTUnwrap(track.subviews.firstIndex(of: stack))
        XCTAssertLessThan(pillIndex, stackIndex)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
