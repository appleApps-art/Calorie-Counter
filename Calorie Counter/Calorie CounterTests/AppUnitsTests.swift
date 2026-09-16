import XCTest
@testable import Calorie_Counter

@MainActor
final class AppUnitsTests: XCTestCase {
    func testImperialConversionsAndMetricRoundTrip() {
        let imperial = AppUnits(usesMetric: false)
        XCTAssertEqual(imperial.weight(100), 220.46226218, accuracy: 0.00001)
        XCTAssertEqual(imperial.mass(28.349523125), 1, accuracy: 0.00001)
        XCTAssertEqual(imperial.volume(29.5735295625), 1, accuracy: 0.00001)
        XCTAssertEqual(imperial.milliliters(imperial.volume(330)), 330, accuracy: 0.00001)
        let metric = AppUnits(usesMetric: true)
        XCTAssertEqual(metric.weight(100), 100)
        XCTAssertEqual(metric.volume(330), 330)
        XCTAssertEqual(metric.mass(100), 100)
    }

    func testImperialPortionAndIngredientInputKeepsMetricStorage() throws {
        let portion = try XCTUnwrap(ProductDetailsMath.parsePortion("8 fl oz"))
        XCTAssertTrue(portion.isMilliliters)
        XCTAssertEqual(portion.value, 236.5882365, accuracy: 0.00001)
        let solid = try XCTUnwrap(ProductDetailsMath.parsePortion("3,5 oz"))
        XCTAssertFalse(solid.isMilliliters)
        XCTAssertEqual(solid.value, 99.2233309375, accuracy: 0.00001)
        let ingredient = try XCTUnwrap(ProductDetailsMath.parseIngredientLine("Flour 2 oz"))
        XCTAssertEqual(try XCTUnwrap(ingredient.grams), 56.69904625, accuracy: 0.00001)
        let metric = try XCTUnwrap(ProductDetailsMath.parsePortion("100 g"))
        XCTAssertEqual(metric.value, 100)
    }

    func testStoredPreferenceChangesPortionDisplayWithoutChangingNutrientGrams() {
        let store = AppSettingsStore()
        let original = store.settings
        defer { store.settings = original }
        var settings = original
        settings.usesMetric = false
        store.settings = settings
        XCTAssertFalse(AppUnits.current.usesMetric)
        XCTAssertTrue(ProductDetailsMath.formatPortion(grams: 100, milliliters: nil).hasSuffix("oz"))
        XCTAssertTrue(ProductDetailsMath.formatPortion(grams: nil, milliliters: 250).hasSuffix("fl oz"))
        XCTAssertFalse(ProductDetailsMath.formatGrams(20).contains("oz"))
        let ingredient = FoodIngredient(name: "Flour", grams: 100, quantityText: "100 g")
        XCTAssertTrue(ProductDetailsMath.formatIngredientAmount(ingredient).hasSuffix("oz"))
        settings.usesMetric = true
        store.settings = settings
        XCTAssertFalse(ProductDetailsMath.formatPortion(grams: 100, milliliters: nil).contains("oz"))
    }

    func testWeightEditorStartsInPreferredUnitsAndSavesKilograms() throws {
        let harness = TestHarness()
        let model = LogWeightViewModel(logWeightUseCase: harness.logWeight(), initialKilograms: 70, usesMetric: false)
        XCTAssertEqual(model.unitIndex.value, WeightUnit.pounds.rawValue)
        XCTAssertEqual(Double(model.sliderValue.value), WeightConversion.pounds(fromKilograms: 70), accuracy: 0.001)
        model.commitTypedValue("154.323583526")
        model.saveTapped()
        XCTAssertTrue(model.errorText.value.isEmpty)
        let entries = try harness.weight.fetchEntries()
        XCTAssertEqual(try XCTUnwrap(entries.first).weightKilograms, 70, accuracy: 0.001)
    }
}
