import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class ScannedProductImagesTests: XCTestCase {
    func testAProductWithoutItsOwnPhotoShowsAPictureOfTheFoodByName() async throws {
        let picture = try writePicture()
        var requested: String?
        let model = ProductDetailsViewModel(fallbackImageURL: { name in
            requested = name
            return picture
        })
        model.configure(draft(named: "Чипси картопляні смак сиру"))

        let loaded = await waitUntil { model.heroImage.value != nil }
        XCTAssertTrue(loaded, "The header and the tip of the day both show this picture")
        XCTAssertEqual(requested, "Чипси картопляні смак сиру")
    }

    func testWhenNoRecipeUsesTheProductTheRowGoesAwayInsteadOfAskingToRetry() async {
        let model = ProductDetailsViewModel(relatedRecipeLoader: { _ in [] })
        model.configure(draft(named: "Чипси картопляні смак сиру"))
        let settled = await waitUntil { !model.relatedRecipeLoading.value }
        XCTAssertTrue(settled)
        XCTAssertFalse(model.wantToCookVisible.value)
        model.refreshInsights()
        XCTAssertFalse(model.wantToCookVisible.value, "Coming back to the screen does not bring it back")
    }

    func testAFailedRecipeSearchStillOffersARetry() async {
        struct Offline: Error {}
        let model = ProductDetailsViewModel(relatedRecipeLoader: { _ in throw Offline() })
        model.configure(draft(named: "Йогурт"))
        _ = await waitUntil { !model.relatedRecipeLoading.value }
        XCTAssertTrue(model.wantToCookVisible.value)
        XCTAssertTrue(model.relatedRecipeUnavailable.value)
    }

    func testRecipesAreSearchedByWhatThePackagedProductIsNotItsFlavour() {
        XCTAssertEqual(SearchRecipesUseCase.cookingIngredient(from: "Чипси картопляні смак сиру"), "чипси картопляні")
        XCTAssertEqual(SearchRecipesUseCase.cookingIngredient(from: "Greek yogurt, strawberry flavour (150 g)"), "greek yogurt")
        XCTAssertEqual(SearchRecipesUseCase.cookingIngredient(from: "Сир кисломолочний 9%"), "сир кисломолочний")
        XCTAssertEqual(SearchRecipesUseCase.cookingIngredient(from: "Йогурт"), "йогурт")
    }

    // MARK: - Helpers

    private func draft(named name: String) -> ProductDetailsDraft {
        ProductDetailsDraft(
            name: name, servingLabel: "28 g", mealType: .snacks, date: Date(), servings: 1,
            calories: 511, protein: 6.1, carbs: 52.9, fats: 30, fiber: 0, sugar: 0, sodium: 0,
            portionGrams: 100, portionMilliliters: nil, ingredients: [], tags: [], notes: "",
            source: "openfoodfacts", imageData: nil
        )
    }

    private func writePicture() throws -> URL {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40), format: format).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func waitUntil(timeout: TimeInterval = 3, _ condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }
}
