import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class FoodPortionAccuracyTests: XCTestCase {
    func testEnteredWeightIsNeverRoundedToNearbyServings() {
        let draft = makeDraft(calories: 200, grams: 100)
        for grams in [110.0, 190.0, 190.5, 210.0] {
            let result = ProductDetailsMath.applyingLoggedPortion(draft, value: grams, isMilliliters: false)
            XCTAssertEqual(result.portionGrams! * Double(result.servings), grams, accuracy: 0.0001)
            XCTAssertEqual(result.loggedCalories, grams * 2, accuracy: 0.0001)
            XCTAssertEqual(result.loggedProtein, grams * 0.1, accuracy: 0.0001)
        }
    }

    func testExactServingMultipleAndFractionalTotalKeepTheirExactNutrition() {
        var draft = makeDraft(calories: 200, grams: 100)
        draft.servings = 2
        let exact = ProductDetailsMath.applyingLoggedPortion(draft, value: 400, isMilliliters: false)
        XCTAssertEqual(exact.servings, 4)
        XCTAssertEqual(exact.loggedCalories, 800)
        let fractional = ProductDetailsMath.applyingLoggedPortion(draft, value: 190.5, isMilliliters: false)
        XCTAssertEqual(fractional.portionGrams! * Double(fractional.servings), 190.5)
        XCTAssertEqual(fractional.loggedCalories, 381)
    }

    func testDrinkNumericFieldPreservesMillilitersThroughControllerAndDiary() throws {
        let harness = TestHarness()
        let viewModel = AddFoodEntryViewModel(logFoodUseCase: harness.logFood())
        var draft = makeDraft(calories: 100, grams: nil)
        draft.portionMilliliters = 250
        viewModel.configure(draft)
        let controller = AddFoodEntryViewController(viewModel: viewModel)
        controller.loadViewIfNeeded()
        let field = try XCTUnwrap(descendants(of: UITextField.self, in: controller.view).first)

        controller.textFieldDidBeginEditing(field)
        XCTAssertEqual(field.text, "250")
        field.text = "500"
        controller.textFieldDidEndEditing(field)
        viewModel.addEntryTapped()

        let logged = try XCTUnwrap(harness.food.fetchEntries(for: draft.date).first)
        XCTAssertEqual(logged.portionMilliliters, 500)
        XCTAssertNil(logged.portionGrams)
        XCTAssertEqual(logged.calories, 200)
    }

    func testBareCommaDecimalUsesCurrentDrinkUnitButExplicitGramsRemainGrams() {
        let drink = ProductDetailsMath.parsePortion("125,5", defaultIsMilliliters: true)
        XCTAssertEqual(drink?.value, 125.5)
        XCTAssertEqual(drink?.isMilliliters, true)
        XCTAssertEqual(ProductDetailsMath.parsePortion("125 g", defaultIsMilliliters: true)?.isMilliliters, false)
    }

    func testIngredientDeletionWaitsForNutritionAndLogsOneServingResultWithCurrentMetadata() async throws {
        let harness = TestHarness()
        let analyzer = IngredientAnalyzer()
        let viewModel = makeViewModel(harness, analyzer: analyzer)
        var draft = makeDraft(calories: 110, grams: 110)
        draft.ingredients = [FoodIngredient(name: "Vegetable", grams: 100), FoodIngredient(name: "Oil", grams: 10)]
        viewModel.configure(draft)
        let requested = expectation(description: "edited ingredient analysis")
        analyzer.onRequest = { requested.fulfill() }
        viewModel.commitIngredient(id: draft.ingredients[1].id, text: "")
        viewModel.addEntryTapped()
        XCTAssertFalse(viewModel.canAddEntry.value)
        XCTAssertEqual(viewModel.caloriesText.value, "—")
        XCTAssertTrue(try harness.food.fetchEntries(for: draft.date).isEmpty)
        await fulfillment(of: [requested], timeout: 2)
        XCTAssertTrue(analyzer.requests[0].text.contains("ONE serving"))
        XCTAssertTrue(analyzer.requests[0].text.contains("Vegetable"))
        XCTAssertFalse(analyzer.requests[0].text.contains("Oil"))

        viewModel.incrementServings()
        viewModel.selectMeal(.dinner)
        await complete(analyzer, request: 0, with: .success(analysis(calories: 20)), viewModel: viewModel)
        let recalculated = try XCTUnwrap(viewModel.draft.value)
        XCTAssertEqual(recalculated.calories, 20)
        XCTAssertEqual(recalculated.portionGrams, 110, "AI must not replace the user's finished portion")
        XCTAssertEqual(recalculated.name, draft.name)
        XCTAssertEqual(recalculated.ingredients.map(\.name), ["Vegetable"])
        XCTAssertEqual(recalculated.mealType, .dinner)
        XCTAssertEqual(recalculated.servings, 2)
        viewModel.addEntryTapped()
        let entry = try XCTUnwrap(harness.food.fetchEntries(for: draft.date).first)
        XCTAssertEqual(entry.calories, 40)
        XCTAssertEqual(entry.mealType, .dinner)
        XCTAssertEqual(ProductDetailsMath.parseIngredientLine(entry.ingredientLines[0])?.grams, 200)
    }

    func testAnalysisFailureRequiresRetryAndCannotSaveStaleNutrition() async throws {
        let harness = TestHarness()
        let analyzer = IngredientAnalyzer()
        let viewModel = makeViewModel(harness, analyzer: analyzer)
        let draft = editableDraft()
        viewModel.configure(draft)
        let firstRequest = expectation(description: "first request")
        analyzer.onRequest = { firstRequest.fulfill() }
        viewModel.commitIngredient(id: draft.ingredients[0].id, text: "Rice 100 g")
        await fulfillment(of: [firstRequest], timeout: 2)
        await complete(analyzer, request: 0, with: .failure(FoodPhotoAnalysisError.invalidResponse), viewModel: viewModel)
        XCTAssertFalse(viewModel.errorText.value.isEmpty)
        XCTAssertEqual(viewModel.caloriesText.value, "—")
        XCTAssertEqual(viewModel.addButtonTitle.value, L10n.tr("product.entry.retryNutrition"))
        XCTAssertTrue(try harness.food.fetchEntries(for: draft.date).isEmpty)

        let retry = expectation(description: "retry request")
        analyzer.onRequest = { retry.fulfill() }
        viewModel.addEntryTapped()
        await fulfillment(of: [retry], timeout: 2)
        XCTAssertTrue(try harness.food.fetchEntries(for: draft.date).isEmpty)
        await complete(analyzer, request: 1, with: .success(analysis(calories: 130)), viewModel: viewModel)
        XCTAssertTrue(try harness.food.fetchEntries(for: draft.date).isEmpty)
        viewModel.addEntryTapped()
        XCTAssertEqual(try harness.food.fetchEntries(for: draft.date).first?.calories, 130)
    }

    func testLatestIngredientEditWinsWhenCancelledAnalysisFinishesLate() async throws {
        let harness = TestHarness()
        let analyzer = IngredientAnalyzer()
        let viewModel = makeViewModel(harness, analyzer: analyzer)
        let draft = editableDraft()
        viewModel.configure(draft)
        let firstRequest = expectation(description: "first edit")
        analyzer.onRequest = { firstRequest.fulfill() }
        viewModel.commitIngredient(id: draft.ingredients[0].id, text: "Rice 100 g")
        await fulfillment(of: [firstRequest], timeout: 2)
        let secondRequest = expectation(description: "second edit")
        analyzer.onRequest = { secondRequest.fulfill() }
        viewModel.commitIngredient(id: draft.ingredients[0].id, text: "Rice 200 g")
        await fulfillment(of: [secondRequest], timeout: 2)
        await complete(analyzer, request: 1, with: .success(analysis(calories: 260)), viewModel: viewModel)
        analyzer.finish(0, with: .success(analysis(calories: 130)))
        for _ in 0..<4 { await Task.yield() }
        XCTAssertEqual(viewModel.draft.value?.calories, 260)
        XCTAssertEqual(viewModel.draft.value?.ingredients.first?.grams, 200)
        viewModel.addEntryTapped()
        XCTAssertEqual(try harness.food.fetchEntries(for: draft.date).first?.calories, 260)
    }

    func testUnknownIngredientsShowClarificationAndRemainUnsavable() async throws {
        let harness = TestHarness()
        let analyzer = IngredientAnalyzer()
        let viewModel = makeViewModel(harness, analyzer: analyzer)
        let draft = editableDraft()
        viewModel.configure(draft)
        let requested = expectation(description: "unknown ingredient")
        analyzer.onRequest = { requested.fulfill() }
        viewModel.commitIngredient(id: draft.ingredients[0].id, text: "mystery ingredient")
        await fulfillment(of: [requested], timeout: 2)
        var result = analysis(calories: 0)
        result.confidence = 0
        result.assistantMessage = "Which ingredient and how much?"
        await complete(analyzer, request: 0, with: .success(result), viewModel: viewModel)
        XCTAssertEqual(viewModel.errorText.value, result.assistantMessage)
        XCTAssertEqual(viewModel.caloriesText.value, "—")
        XCTAssertTrue(try harness.food.fetchEntries(for: draft.date).isEmpty)
    }

    func testInvalidNutritionCannotReplaceTheDraftOrBeLogged() async throws {
        let harness = TestHarness()
        let analyzer = IngredientAnalyzer()
        let viewModel = makeViewModel(harness, analyzer: analyzer)
        let draft = editableDraft()
        viewModel.configure(draft)
        let requested = expectation(description: "analysis")
        analyzer.onRequest = { requested.fulfill() }
        viewModel.commitIngredient(id: draft.ingredients[0].id, text: "Rice 100 g")
        await fulfillment(of: [requested], timeout: 2)
        await complete(analyzer, request: 0, with: .success(analysis(calories: .nan)), viewModel: viewModel)
        XCTAssertEqual(viewModel.draft.value?.calories, draft.calories)
        XCTAssertEqual(viewModel.caloriesText.value, "—")
        XCTAssertFalse(viewModel.errorText.value.isEmpty)
        XCTAssertTrue(try harness.food.fetchEntries(for: draft.date).isEmpty)
    }

    func testUnchangedIngredientDoesNotReanalyzeAndLastIngredientCannotBeRemoved() {
        let harness = TestHarness()
        let analyzer = IngredientAnalyzer()
        let viewModel = makeViewModel(harness, analyzer: analyzer)
        let draft = editableDraft()
        viewModel.configure(draft)
        viewModel.commitIngredient(id: draft.ingredients[0].id, text: ProductDetailsMath.formatIngredient(draft.ingredients[0]))
        XCTAssertFalse(viewModel.isRecalculatingNutrition.value)
        viewModel.commitIngredient(id: draft.ingredients[0].id, text: "")
        XCTAssertEqual(viewModel.draft.value?.ingredients, draft.ingredients)
        XCTAssertFalse(viewModel.errorText.value.isEmpty)
        XCTAssertTrue(analyzer.requests.isEmpty)
    }

    func testRecipeIngredientsNormalizeToOneServingThenScaleWithLoggedPortion() {
        let recipe = Recipe(
            id: UUID(), title: "Rice", servings: 2, calories: 200,
            ingredients: [RecipeIngredient(id: "rice", name: "Rice", amount: 200, unit: "g")],
            steps: [], weightGrams: 150
        )
        var draft = ProductDetailsMath.draft(from: recipe)
        XCTAssertEqual(draft.ingredients.first?.grams, 100)
        XCTAssertEqual(draft.portionGrams, 150)
        draft.servings = 1
        let entry = draft.toFoodEntry()
        XCTAssertEqual(entry.calories, 200)
        XCTAssertEqual(ProductDetailsMath.parseIngredientLine(entry.ingredientLines[0])?.grams, 100)
        draft = ProductDetailsMath.applyingLoggedPortion(draft, value: 190, isMilliliters: false)
        let scaled = draft.toFoodEntry()
        XCTAssertEqual(scaled.portionGrams, 190)
        XCTAssertEqual(scaled.calories, 200 * 190 / 150, accuracy: 0.0001)
        XCTAssertEqual(ProductDetailsMath.parseIngredientLine(scaled.ingredientLines[0])?.grams ?? 0, 100 * 190 / 150, accuracy: 0.001)
    }

    func testRecipeWithKnownVolumeDoesNotInferGramsFromIngredients() {
        let recipe = Recipe(
            id: UUID(), title: "Smoothie", servings: 1, calories: 120,
            ingredients: [RecipeIngredient(id: "fruit", name: "Fruit", amount: 100, unit: "g")],
            steps: [], volumeMilliliters: 250
        )
        let draft = ProductDetailsMath.draft(from: recipe)
        XCTAssertEqual(draft.portionMilliliters, 250)
        XCTAssertNil(draft.portionGrams)
        let scaled = ProductDetailsMath.applyingLoggedPortion(draft, value: 125, isMilliliters: true)
        XCTAssertEqual(scaled.loggedCalories, 60)
    }

    func testUnknownRecipeWeightRemainsOneServingAndCannotBeEditedAsGrams() throws {
        let recipe = Recipe(
            id: UUID(), title: "Cooked rice", servings: 1, calories: 400,
            ingredients: [RecipeIngredient(id: "rice", name: "Dry rice", amount: 100, unit: "g")],
            steps: ["Cook with water"]
        )
        let harness = TestHarness()
        let viewModel = AddFoodEntryViewModel(logFoodUseCase: harness.logFood())
        viewModel.configure(ProductDetailsMath.draft(from: recipe))
        let controller = AddFoodEntryViewController(viewModel: viewModel)
        controller.loadViewIfNeeded()
        let field = try XCTUnwrap(descendants(of: UITextField.self, in: controller.view).first)
        XCTAssertFalse(field.isEnabled)
        XCTAssertEqual(viewModel.portionText.value, L10n.format("recipes.details.serving", 1))
        XCTAssertNil(viewModel.draft.value?.portionGrams)
        viewModel.commitPortion("300")
        XCTAssertNil(viewModel.draft.value?.portionGrams)
        XCTAssertEqual(viewModel.draft.value?.calories, 400)
        viewModel.incrementServings()
        viewModel.addEntryTapped()
        let entry = try XCTUnwrap(harness.food.fetchEntries(for: Date()).first)
        XCTAssertNil(entry.portionGrams)
        XCTAssertEqual(entry.calories, 800)
    }

    func testUnknownBarcodeServingIsNotAssignedAnInventedWeight() {
        let product = BarcodeProduct(
            id: UUID(), barcode: "123", name: "Spread", servingSizeLabel: "1 tbsp",
            caloriesPerServing: 30, proteinPerServing: 0, carbsPerServing: 0, fatsPerServing: 3,
            source: .spoonacular
        )
        let draft = ProductDetailsMath.fillingDefaultPortion(ProductDetailsMath.draft(
            from: product, imageData: nil, mealType: .breakfast, date: Date()
        ))
        XCTAssertNil(draft.portionGrams)
        XCTAssertNil(draft.portionMilliliters)
        XCTAssertEqual(draft.loggedCalories, 30)
        XCTAssertEqual(ProductDetailsMath.scaled(draft, toGrams: 30), draft)
        XCTAssertEqual(ProductDetailsMath.scaled(draft, toMilliliters: 15), draft)
    }

    func testDirectProductLoggingPreservesMicrosPortionAndCatalogMetadata() throws {
        let harness = TestHarness()
        let date = Date(timeIntervalSince1970: 1_800_000_123)
        let product = FoodProduct(
            id: UUID(), externalId: "oats-1", name: "Oats", brand: "Brand", kind: .product,
            imageURL: URL(string: "https://example.com/oats.jpg"),
            calories: 300, protein: 10, carbs: 45, fats: 8, fiber: 7, sugar: 2, sodium: 125,
            amount: 150, unit: "g", source: .spoonacular, ingredients: ["Oats 150 g"]
        )
        let image = Data([1, 2, 3])
        let entry = try harness.logFood().execute(from: product, mealType: .dinner, date: date, imageData: image)
        XCTAssertEqual(entry.name, "Brand · Oats")
        XCTAssertEqual(entry.source, "search")
        XCTAssertEqual(entry.mealType, .dinner)
        XCTAssertEqual(entry.date, date)
        XCTAssertEqual(entry.calories, 300)
        XCTAssertEqual(entry.protein, 10)
        XCTAssertEqual(entry.carbs, 45)
        XCTAssertEqual(entry.fats, 8)
        XCTAssertEqual(entry.fiber, 7)
        XCTAssertEqual(entry.sugar, 2)
        XCTAssertEqual(entry.sodium, 125)
        XCTAssertEqual(entry.portionGrams, 150)
        XCTAssertNil(entry.portionMilliliters)
        XCTAssertEqual(entry.imageData, image)
        XCTAssertEqual(entry.imageURL, product.imageURL)
        XCTAssertEqual(entry.catalogExternalId, product.externalId)
        XCTAssertEqual(entry.catalogKind, .product)
        let saved = try XCTUnwrap(harness.food.fetchEntry(id: entry.id))
        XCTAssertEqual(saved.fiber, 7)
        XCTAssertEqual(saved.sugar, 2)
        XCTAssertEqual(saved.sodium, 125)
    }

    func testDirectProductLoggingKeepsUnknownServingUnknown() throws {
        let harness = TestHarness()
        for kind in [FoodProductKind.product, .recipe] {
            for unit in ["tbsp", "serving", ""] {
                let product = FoodProduct(
                    id: UUID(), externalId: "", name: "Spread", kind: kind, calories: 30,
                    fiber: 1, sugar: 2, sodium: 15, amount: 1, unit: unit,
                    ingredients: ["Unknown ingredient"], servingSizeLabel: unit.isEmpty ? nil : "1 \(unit)"
                )
                let entry = try harness.logFood().execute(from: product, mealType: .breakfast)
                XCTAssertNil(entry.portionGrams, "\(kind): \(unit)")
                XCTAssertNil(entry.portionMilliliters, "\(kind): \(unit)")
                XCTAssertEqual(entry.calories, 30)
                XCTAssertEqual(entry.fiber, 1)
                XCTAssertNil(entry.catalogExternalId)
            }
        }
    }

    func testDirectRecipeLoggingKeepsKnownVolumeIncludingUnitAliases() throws {
        let harness = TestHarness()
        for unit in ["ml", "milliliters", "мл"] {
            let product = FoodProduct(
                id: UUID(), externalId: "soup", name: "Soup", kind: .recipe,
                calories: 120, protein: 5, carbs: 15, fats: 4, fiber: 2, sugar: 1, sodium: 200,
                amount: 250, unit: unit, ingredients: ["Water 200 ml", "Carrot 50 g"], steps: ["Cook"]
            )
            let entry = try harness.logFood().execute(from: product, mealType: .lunch)
            XCTAssertEqual(entry.portionMilliliters, 250)
            XCTAssertNil(entry.portionGrams)
            XCTAssertEqual(entry.calories, 120)
            XCTAssertEqual(entry.fiber, 2)
            XCTAssertEqual(entry.recipeSteps, ["Cook"])
            XCTAssertEqual(entry.catalogKind, .recipe)
            XCTAssertEqual(entry.scaled(toMilliliters: 125).calories, 60)
        }
    }

    private func makeViewModel(_ harness: TestHarness, analyzer: IngredientAnalyzer) -> AddFoodEntryViewModel {
        AddFoodEntryViewModel(logFoodUseCase: harness.logFood()) { text, meal in
            try await analyzer.analyze(text: text, meal: meal)
        }
    }

    private func complete(
        _ analyzer: IngredientAnalyzer,
        request: Int,
        with result: Result<FoodPhotoAnalysis, Error>,
        viewModel: AddFoodEntryViewModel
    ) async {
        let completed = expectation(description: "nutrition request completed")
        var didComplete = false
        viewModel.isRecalculatingNutrition.bind { running in
            guard !running, !didComplete else { return }
            didComplete = true
            completed.fulfill()
        }
        analyzer.finish(request, with: result)
        await fulfillment(of: [completed], timeout: 2)
    }

    private func makeDraft(calories: Double, grams: Double?) -> ProductDetailsDraft {
        ProductDetailsDraft(
            name: "Edited dish", servingLabel: "", mealType: .lunch, date: Date(), servings: 1,
            calories: calories, protein: 10, carbs: 10, fats: 1, fiber: 1, sugar: 1, sodium: 1,
            portionGrams: grams, portionMilliliters: nil, ingredients: [], tags: [], notes: "", source: "text", imageData: nil
        )
    }

    private func editableDraft() -> ProductDetailsDraft {
        var draft = makeDraft(calories: 200, grams: 100)
        draft.ingredients = [FoodIngredient(name: "Oats", grams: 100, quantityText: "100 g")]
        return draft
    }

    private func analysis(calories: Double) -> FoodPhotoAnalysis {
        FoodPhotoAnalysis(
            name: "AI renamed dish", mealType: .breakfast, calories: calories, protein: 2, carbs: 3, fats: 1,
            fiber: 1, sugar: 0, sodium: 0, portionGrams: 999, portionMilliliters: nil,
            confidence: 0.9, notes: "", assistantMessage: ""
        )
    }

    private func descendants<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(of: type, in: $0) }
    }
}

@MainActor
private final class IngredientAnalyzer {
    struct Request {
        let text: String
        let meal: MealType
        let continuation: CheckedContinuation<FoodPhotoAnalysis, Error>
    }
    var requests: [Request] = []
    var onRequest: (() -> Void)?

    func analyze(text: String, meal: MealType) async throws -> FoodPhotoAnalysis {
        try await withCheckedThrowingContinuation { continuation in
            requests.append(Request(text: text, meal: meal, continuation: continuation))
            onRequest?()
        }
    }

    func finish(_ index: Int, with result: Result<FoodPhotoAnalysis, Error>) {
        requests[index].continuation.resume(with: result)
    }
}
