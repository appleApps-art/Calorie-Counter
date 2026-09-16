import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class HomeTabBarBlurTests: XCTestCase {
    func testRecipeShareCardKeepsLongContentReadable() throws {
        let image = try XCTUnwrap(RecipeShareCardRenderer.render(
            title: "Курка з кіноа, овочами та лимонним соусом",
            photo: nil,
            chips: [RecipeMetaChip(symbol: "clock", title: "30 хв"), RecipeMetaChip(symbol: "flame", title: "520 ккал")],
            ingredients: [FoodIngredient(name: "Куряче філе", grams: 200), FoodIngredient(name: "Кіноа", grams: 80), FoodIngredient(name: "Свіжі овочі та зелень", grams: 150)],
            steps: ["Промийте кіноа та відваріть до готовності.", "Наріжте курку, додайте спеції та обсмажте до готовності. Змішайте з овочами, кіноа та лимонним соусом."]
        ))
        XCTAssertEqual(image.size.width, 804)
        XCTAssertLessThan(image.size.height, image.size.width, "Short recipes should remain a compact two-column card")
        let attachment = XCTAttachment(image: image)
        attachment.name = "Recipe share card"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRecipeDiaryCalendarCanScrollFullyAboveSaveButtonInBothThemes() async throws {
        func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }
        for theme in [UIUserInterfaceStyle.light, .dark] {
            let harness = TestHarness()
            let model = AddFoodEntryViewModel(logFoodUseCase: LogFoodUseCase(foodEntryRepository: harness.food))
            let draft = ProductDetailsDraft(name: "Курка з кіноа", servingLabel: "1 порція", mealType: .lunch,
                date: Date(), servings: 1, calories: 420, protein: 34, carbs: 42, fats: 13,
                fiber: 7, sugar: 5, sodium: 480, portionGrams: 350, portionMilliliters: nil,
                ingredients: [], tags: [], notes: "", source: "qa", imageData: nil, suggestion: nil)
            model.configure(draft, presentation: .recipeSheet)
            let controller = AddFoodEntryViewController(viewModel: model)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.overrideUserInterfaceStyle = theme
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.overrideUserInterfaceStyle = theme
            defer { window.isHidden = true }
            try await Task.sleep(nanoseconds: 150_000_000)
            controller.view.layoutIfNeeded()
            XCTAssertEqual(controller.traitCollection.userInterfaceStyle, theme)
            let calendar = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UICalendarView }.first)
            let scroll = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIScrollView }.first)
            XCTAssertGreaterThan(calendar.bounds.height, 300)
            let bottom = max(-scroll.adjustedContentInset.top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
            controller.view.layoutIfNeeded()
            let button = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }.first {
                ($0.configuration?.title ?? $0.title(for: .normal)) == model.addButtonTitle.value
            })
            XCTAssertLessThan(calendar.convert(calendar.bounds, to: controller.view).maxY,
                              button.convert(button.bounds, to: controller.view).minY)
            let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "Recipe calendar \(theme == .dark ? "dark" : "light")"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testBackdropRendersAboveHomeContentAndReachesScreenBottom() async throws {
        let tabs = MainTabBarController(container: DIContainer(coreDataStack: CoreDataStack(inMemory: true)))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(nanoseconds: 150_000_000)
        tabs.view.layoutIfNeeded()
        let blur = try XCTUnwrap(tabs.view.subviews.compactMap { $0 as? TabBarBackgroundBlurView }.first)
        var content = try XCTUnwrap(tabs.selectedViewController?.view)
        while let parent = content.superview, parent !== tabs.view { content = parent }
        let blurIndex = try XCTUnwrap(tabs.view.subviews.firstIndex(of: blur))
        let contentIndex = try XCTUnwrap(tabs.view.subviews.firstIndex(of: content))
        XCTAssertGreaterThan(blurIndex, contentIndex, String(describing: tabs.view.subviews))
        XCTAssertEqual(blur.frame.maxY, tabs.view.bounds.maxY, accuracy: 1)
        XCTAssertFalse(blur.isHidden)
        XCTAssertEqual(blur.bounds.height, 65 + tabs.view.safeAreaInsets.bottom, accuracy: 1)
    }
}
