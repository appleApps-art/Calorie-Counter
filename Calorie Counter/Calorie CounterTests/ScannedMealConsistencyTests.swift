import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class ScannedMealConsistencyTests: XCTestCase {
    func testOpeningDetailsKeepsTheScannedPhotoAndNumbers() async throws {
        let scan = scannedOmelette()
        let viewModel = makeDetails(for: scan)

        viewModel.viewDidLoad()
        let loaded = await waitUntil { !viewModel.isDetailsLoading.value && viewModel.isDetailsReady.value }
        XCTAssertTrue(loaded)

        // The generated recipe only lends its steps; the meal stays the one on the photo.
        XCTAssertEqual(viewModel.nameText.value, "Овочевий омлет із хлібом")
        XCTAssertEqual(viewModel.steps.value, ["Збийте яйця.", "Запечіть."])
        let heroFromScan = try XCTUnwrap(viewModel.heroImage.value)
        XCTAssertEqual(heroFromScan.size.width, 40, accuracy: 1, "The hero is the user's photo, not a stock one")

        var added: ProductDetailsDraft?
        viewModel.onAddToDiary = { added = $0 }
        viewModel.addToDiaryTapped()
        let didAdd = await waitUntil { added != nil }
        XCTAssertTrue(didAdd)
        XCTAssertEqual(added?.calories, 380, "What gets logged is what the scan showed")
        XCTAssertEqual(added?.imageData, scan.imageData, "The user's photo goes into the diary")
        XCTAssertEqual(added?.source, "photo", "Reopened from Home it must still read as the user's photo")
    }

    func testTheHealthScoreOnTheScanIsTheOneInTheDetails() async {
        let scan = FoodPhotoAnalysis(
            name: "Овочевий омлет із хлібом", mealType: .lunch,
            calories: 365, protein: 21, carbs: 28, fats: 18, fiber: 4, sugar: 5, sodium: 520,
            portionGrams: 245, portionMilliliters: nil, confidence: 0.9, notes: "", assistantMessage: ""
        )
        var draft = ProductDetailsMath.draft(from: scan, imageData: scannedOmelette().imageData, mealType: .lunch, date: Date())
        draft.foodType = .dish
        let viewModel = makeDetails(for: draft)

        viewModel.viewDidLoad()
        _ = await waitUntil { !viewModel.isDetailsLoading.value && viewModel.isDetailsReady.value }

        XCTAssertEqual(viewModel.scoreTitleText.value, L10n.format("photo.result.healthScore", scan.nutritionFacts.score))
        XCTAssertEqual(viewModel.scoreGradeText.value, scan.nutritionFacts.grade.rawValue)
    }

    func testAMealReopenedFromHomeShowsTheSamePhotoAgain() async throws {
        let logged = scannedOmelette().toFoodEntry()
        let viewModel = makeDetails(for: ProductDetailsMath.draft(from: logged))

        viewModel.viewDidLoad()
        _ = await waitUntil { !viewModel.isDetailsLoading.value && viewModel.isDetailsReady.value }

        XCTAssertEqual(viewModel.nameText.value, "Овочевий омлет із хлібом")
        let hero = try XCTUnwrap(viewModel.heroImage.value)
        XCTAssertEqual(hero.size.width, 40, accuracy: 1)
    }

    func testAShutterPressTheCameraNeverAnswersGivesTheShutterBack() async {
        let harness = TestHarness()
        let diary = FetchDailyDiaryUseCase(
            foodEntryRepository: harness.food,
            waterEntryRepository: harness.water,
            userGoalsRepository: harness.goals,
            workoutEntryRepository: harness.workout
        )
        let viewModel = FoodPhotoAnalysisViewModel(analyzeFoodPhotoUseCase: AnalyzeFoodPhotoUseCase(
            foodPhotoAnalysisService: NeverCalledPhotoService(),
            buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase(
                fetchDailyDiaryUseCase: diary,
                userProfileRepository: harness.profile,
                userPreferenceRepository: harness.preferences
            )
        ))
        viewModel.captureTimeoutNanoseconds = 50_000_000

        viewModel.beginCapture()
        XCTAssertEqual(viewModel.phase.value, .identifying)
        let recovered = await waitUntil { viewModel.phase.value == .idle }
        XCTAssertTrue(recovered, "Without a photo the camera must not stay stuck identifying")
        XCTAssertEqual(viewModel.errorText.value, FoodPhotoCaptureError.cameraUnavailable.localizedDescription)

        viewModel.beginCapture()
        XCTAssertEqual(viewModel.phase.value, .identifying, "The next shutter press works again")
    }

    func testACameraThatFailsWhileJustOpeningDoesNotRaiseAnAlert() {
        let viewModel = makeScanner(answering: scannedLeaf())
        viewModel.captureFailed(FoodPhotoCaptureError.permissionDenied)
        XCTAssertEqual(viewModel.errorText.value, "", "The gallery still works; opening the screen must not nag")

        viewModel.beginCapture()
        viewModel.captureFailed(FoodPhotoCaptureError.permissionDenied)
        XCTAssertEqual(viewModel.errorText.value, FoodPhotoCaptureError.permissionDenied.localizedDescription,
                       "A shutter press that fails is explained")
    }

    func testAPhotoWithoutFoodSaysSoInsteadOfOfferingZeroCalories() async {
        let viewModel = makeScanner(answering: scannedLeaf())

        viewModel.analyze(imageData: Data([1, 2, 3]))
        let settled = await waitUntil { !viewModel.isAnalyzing.value }
        XCTAssertTrue(settled)

        XCTAssertNil(viewModel.analysis.value, "No result card, no 70/100 score for a leaf")
        XCTAssertFalse(viewModel.canConfirmLog.value)
        XCTAssertEqual(viewModel.phase.value, .idle, "The shutter is ready for another photo")
        XCTAssertEqual(viewModel.statusText.value, L10n.tr("photo.error.noFood"))
        XCTAssertEqual(viewModel.errorText.value, L10n.tr("photo.error.noFood"), "The user is told why nothing came back")
    }

    func testAGlassOfWaterIsStillAResultEvenWithZeroCalories() async {
        let water = FoodPhotoAnalysis(
            name: "Вода", mealType: .lunch,
            calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, sugar: 0, sodium: 0,
            portionGrams: nil, portionMilliliters: 250, confidence: 0.92, notes: "", assistantMessage: ""
        )
        let viewModel = makeScanner(answering: water)

        viewModel.analyze(imageData: Data([1, 2, 3]))
        _ = await waitUntil { !viewModel.isAnalyzing.value }

        XCTAssertEqual(viewModel.analysis.value?.name, "Вода")
        XCTAssertTrue(viewModel.canConfirmLog.value)
    }

    // MARK: - Helpers

    private func scannedLeaf() -> FoodPhotoAnalysis {
        FoodPhotoAnalysis(
            name: "Невизначений продукт", mealType: .lunch,
            calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, sugar: 0, sodium: 0,
            portionGrams: nil, portionMilliliters: nil, confidence: 0, notes: "На фото листя рослини", assistantMessage: ""
        )
    }

    private func makeScanner(answering result: FoodPhotoAnalysis) -> FoodPhotoAnalysisViewModel {
        let harness = TestHarness()
        let diary = FetchDailyDiaryUseCase(
            foodEntryRepository: harness.food,
            waterEntryRepository: harness.water,
            userGoalsRepository: harness.goals,
            workoutEntryRepository: harness.workout
        )
        return FoodPhotoAnalysisViewModel(analyzeFoodPhotoUseCase: AnalyzeFoodPhotoUseCase(
            foodPhotoAnalysisService: FixedPhotoService(result: result),
            buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase(
                fetchDailyDiaryUseCase: diary,
                userProfileRepository: harness.profile,
                userPreferenceRepository: harness.preferences
            )
        ))
    }

    private func scannedOmelette() -> ProductDetailsDraft {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).pngData { context in
            UIColor.yellow.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        var draft = ProductDetailsDraft(
            name: "Овочевий омлет із хлібом", servingLabel: "", mealType: .lunch, date: Date(), servings: 1,
            calories: 380, protein: 21, carbs: 28, fats: 20, fiber: 3, sugar: 4, sodium: 400,
            portionGrams: 260, portionMilliliters: nil,
            ingredients: [FoodIngredient(name: "Яйця", grams: 120), FoodIngredient(name: "Хліб", grams: 60)],
            tags: [], notes: "", source: "photo", imageData: photo
        )
        draft.foodType = .dish
        return draft
    }

    private func makeDetails(for draft: ProductDetailsDraft) -> RecipeDetailViewModel {
        let harness = TestHarness()
        return RecipeDetailViewModel(
            recipe: draft.toFoodEntry().asRecipe(),
            searchRecipesUseCase: SearchRecipesUseCase(
                spoonacularService: MealPlanFakeSpoonacular(),
                aiFoodSearchService: GeneratedDishSearch()
            ),
            recipeRepository: harness.recipes,
            aiAssistantService: AIAssistantService(),
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                foodEntryRepository: harness.food,
                waterEntryRepository: harness.water,
                userGoalsRepository: harness.goals,
                workoutEntryRepository: harness.workout
            ),
            loggingContext: draft
        )
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

/// Answers the "complete recipe by name" request with a different dish, photo and nutrition.
private final class GeneratedDishSearch: AIFoodSearching {
    func enrichDetails(title: String, imageURL: URL?, source: String, kind: String) async throws -> FoodProduct? {
        FoodProduct(
            id: UUID(), externalId: "generated", name: "Омлет з броколі", brand: nil, kind: .recipe,
            imageURL: URL(string: "https://images.example/stock-omelette.jpg"),
            calories: 360, protein: 18, carbs: 20, fats: 22, amount: 250, unit: "g",
            source: .openAI,
            ingredients: ["Яйця 120 г", "Броколі 80 г"],
            steps: ["Збийте яйця.", "Запечіть."],
            foodType: .dish
        )
    }

    func searchFoods(query: String) async throws -> [FoodProduct] { [] }
    func searchRecipes(query: String) async throws -> [Recipe] { [] }
    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] { [:] }
    func fetchCatalogSection(id: String) async throws -> [FoodProduct] { [] }

    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        FoodSearchCatalogPage(products: [], nextOffset: offset, hasMore: false)
    }
}

private final class NeverCalledPhotoService: FoodPhotoAnalysisServiceProtocol {
    func analyze(
        imageData: Data,
        mealType: MealType,
        note: String?,
        userContext: AIAssistantUserContext?,
        inventoryMode: Bool
    ) async throws -> FoodPhotoAnalysis {
        throw FoodPhotoAnalysisError.invalidResponse
    }
}

private final class FixedPhotoService: FoodPhotoAnalysisServiceProtocol {
    let result: FoodPhotoAnalysis
    init(result: FoodPhotoAnalysis) { self.result = result }

    func analyze(
        imageData: Data,
        mealType: MealType,
        note: String?,
        userContext: AIAssistantUserContext?,
        inventoryMode: Bool
    ) async throws -> FoodPhotoAnalysis {
        result
    }
}
