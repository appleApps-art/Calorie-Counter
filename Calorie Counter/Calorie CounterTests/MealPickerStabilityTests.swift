import XCTest
@testable import Calorie_Counter

@MainActor
final class MealPickerStabilityTests: XCTestCase {
    func testPickingAMealMovesTheCheckmarkWithoutRebuildingTheSection() throws {
        // The design canvas is 402x874: a shorter screen scales the row metrics, which is where a
        // rebuilt row used to come back with a different height.
        try assertMealPickerKeepsItsRows(in: CGSize(width: 402, height: 874))
        try assertMealPickerKeepsItsRows(in: CGSize(width: 375, height: 667))
    }

    private func assertMealPickerKeepsItsRows(in size: CGSize) throws {
        let harness = TestHarness()
        let viewModel = AddFoodEntryViewModel(logFoodUseCase: harness.logFood())
        viewModel.configure(makeDraft())
        let controller = AddFoodEntryViewController(viewModel: viewModel)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.layoutIfNeeded()

        let rows = mealRows(in: controller)
        XCTAssertEqual(rows.count, viewModel.mealTypes.count)
        let identities = rows.map(ObjectIdentifier.init)
        let heights = rows.map { $0.systemLayoutSizeFitting(
            CGSize(width: 370, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height }
        XCTAssertEqual(selectedIndexes(in: rows), [try XCTUnwrap(viewModel.mealTypes.firstIndex(of: .lunch))])

        viewModel.selectMeal(.breakfast)
        controller.view.layoutIfNeeded()

        let afterRows = mealRows(in: controller)
        XCTAssertEqual(afterRows.map(ObjectIdentifier.init), identities, "The rows must be reused, not rebuilt at \(size)")
        XCTAssertEqual(selectedIndexes(in: afterRows), [try XCTUnwrap(viewModel.mealTypes.firstIndex(of: .breakfast))])
        let afterHeights = afterRows.map { $0.systemLayoutSizeFitting(
            CGSize(width: 370, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height }
        XCTAssertEqual(afterHeights, heights, "The section must keep its height when a meal is picked at \(size)")
    }

    private func mealRows(in controller: UIViewController) -> [NutritionFactRowView] {
        let stack = controller.value(forKey: "mealStackView") as? UIStackView
        return stack?.arrangedSubviews.compactMap { $0 as? NutritionFactRowView } ?? []
    }

    private func selectedIndexes(in rows: [NutritionFactRowView]) -> [Int] {
        rows.enumerated()
            .filter { _, row in
                descendants(of: UIImageView.self, in: row).contains { !$0.isHidden && $0.image != nil }
            }
            .map(\.offset)
    }

    private func descendants<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(of: type, in: $0) }
    }

    private func makeDraft() -> ProductDetailsDraft {
        ProductDetailsDraft(
            name: "Chicken bowl", servingLabel: "", mealType: .lunch, date: Date(), servings: 1,
            calories: 320, protein: 10, carbs: 10, fats: 1, fiber: 1, sugar: 1, sodium: 1,
            portionGrams: 350, portionMilliliters: nil, ingredients: [], tags: [], notes: "",
            source: "text", imageData: nil
        )
    }
}
