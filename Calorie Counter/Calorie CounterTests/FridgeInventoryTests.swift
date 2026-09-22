import XCTest
@testable import Calorie_Counter

final class FridgeInventoryTests: XCTestCase {
    func testCountedAmountFromAPhotoBecomesTheQuantityLabel() {
        let item = PantryItem.from(ingredient: FoodIngredient(name: "Яйця", quantityText: "6 шт"))
        XCTAssertEqual(item.name, "Яйця")
        XCTAssertEqual(item.quantityText, "6 шт")
        // A count is not a weight, so it must not turn into 6 g and be merged with other amounts.
        XCTAssertNil(item.amount)
        XCTAssertNil(item.unit)
    }

    func testAWeightOnThePackagingStaysAMergeableAmount() {
        let item = PantryItem.from(ingredient: FoodIngredient(name: "Сир", quantityText: "500 г"))
        XCTAssertEqual(item.amount, 500)
        XCTAssertEqual(item.unit, "g")
    }

    func testAnUnknownAmountLeavesTheQuantityEmpty() {
        let item = PantryItem.from(ingredient: FoodIngredient(name: "Молоко"))
        XCTAssertEqual(item.quantityText, "")
        XCTAssertNil(item.amount)
    }

    func testGramsFromTheModelStillWin() {
        let item = PantryItem.from(ingredient: FoodIngredient(name: "Сир", grams: 250, quantityText: "1 пачка"))
        XCTAssertEqual(item.amount, 250)
        XCTAssertEqual(item.unit, "g")
    }

    func testAnalyzePhotoResponseCarriesTheQuantityLabel() throws {
        let payload = """
        {
          "analysis": {
            "name": "Вміст холодильника",
            "mealType": "snacks",
            "calories": 0, "protein": 0, "carbs": 0, "fats": 0,
            "confidence": 0.8,
            "source": "photo",
            "ingredients": [
              { "name": "Яйця", "quantity": "6 шт" },
              { "name": "Молоко", "quantity": "  " },
              { "name": "Сир", "grams": 250 }
            ]
          }
        }
        """
        let decoded = try JSONDecoder().decode(FoodPhotoAnalyzeAPIResponse.self, from: Data(payload.utf8))
        let ingredients = FoodPhotoAnalysisService.ingredients(from: decoded.analysis?.ingredients)
        XCTAssertEqual(ingredients.map(\.quantityText), ["6 шт", nil, nil])
        XCTAssertEqual(ingredients.map(\.grams), [nil, nil, 250])
    }
}
