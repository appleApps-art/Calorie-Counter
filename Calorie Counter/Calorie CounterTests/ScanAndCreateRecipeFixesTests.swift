import XCTest
@testable import Calorie_Counter

@MainActor
final class ScanAndCreateRecipeFixesTests: XCTestCase {
    // MARK: - Barcode reads

    func testOnlyPackCodesWithACorrectCheckDigitAreRead() {
        XCTAssertTrue(BarcodeNormalization.isProductCode("4006381333931"), "EAN-13")
        XCTAssertTrue(BarcodeNormalization.isProductCode("96385074"), "EAN-8")
        XCTAssertTrue(BarcodeNormalization.isProductCode("036000291452"), "UPC-A")
        XCTAssertTrue(BarcodeNormalization.isProductCode("04252614"), "UPC-E")
        XCTAssertTrue(BarcodeNormalization.isProductCode("10012345678902"), "GTIN-14")

        XCTAssertFalse(BarcodeNormalization.isProductCode("4006381333932"), "A misread digit")
        XCTAssertFalse(BarcodeNormalization.isProductCode("400638133"), "A partial read")
        XCTAssertFalse(BarcodeNormalization.isProductCode("https://example.com/4006381333931"), "A QR link")
        XCTAssertFalse(BarcodeNormalization.isProductCode("ABC-1234567"), "Code 39 text")
    }

    // MARK: - Recipe without ingredients

    func testARecipeWithNoProductsAsksForIngredientsInsteadOfFailing() {
        let viewModel = makeViewModel(kind: .recipe)
        viewModel.selectedPantryIds.value = []

        XCTAssertTrue(viewModel.acceptPendingIngredientAndCheckMissing())
        XCTAssertEqual(viewModel.missingIngredientsMessage, L10n.tr("recipes.create.noIngredientsEmptyPantry"))

        viewModel.pantryItems.value = [pantryItem("Eggs")]
        XCTAssertEqual(viewModel.missingIngredientsMessage, L10n.tr("recipes.create.noIngredientsPantry"))

        viewModel.selectSource(.custom)
        XCTAssertTrue(viewModel.acceptPendingIngredientAndCheckMissing())
        XCTAssertEqual(viewModel.missingIngredientsMessage, L10n.tr("recipes.create.noIngredientsCustom"))
    }

    func testAnIngredientTypedButNotConfirmedStillCounts() {
        let viewModel = makeViewModel(kind: .recipe)
        viewModel.selectSource(.custom)
        viewModel.updateIngredientQuery("  Chicken breast ")

        XCTAssertFalse(viewModel.acceptPendingIngredientAndCheckMissing())
        XCTAssertEqual(viewModel.customIngredients.value, ["Chicken breast"])
    }

    func testIngredientsTypedWithCommasBecomeSeparateTags() {
        let viewModel = makeViewModel(kind: .recipe)
        viewModel.selectSource(.custom)
        viewModel.addCustomIngredient("огірки, помідори; капуста")

        XCTAssertEqual(viewModel.customIngredients.value, ["огірки", "помідори", "капуста"])
        viewModel.addCustomIngredient("капуста, морква")
        XCTAssertEqual(
            viewModel.customIngredients.value,
            ["огірки", "помідори", "капуста", "морква"],
            "A product already on the list is not added twice"
        )
    }

    func testAMealPlanCanStillBeMadeWithoutProducts() {
        let viewModel = makeViewModel(kind: .mealPlan)
        viewModel.selectedPantryIds.value = []
        XCTAssertFalse(viewModel.acceptPendingIngredientAndCheckMissing())
    }

    // MARK: - Helpers

    private func pantryItem(_ name: String) -> PantryItem {
        PantryItem(
            id: UUID(), name: name, quantityText: "", amount: nil, unit: nil, useBy: nil,
            imageURL: nil, imageData: nil, createdAt: Date(), updatedAt: Date()
        )
    }

    private func makeViewModel(kind: CreateRecipeFormKind) -> CreateRecipeFormViewModel {
        let harness = TestHarness()
        let spoonacular = MealPlanFakeSpoonacular()
        return CreateRecipeFormViewModel(
            kind: kind,
            fetchPantryItemsUseCase: FetchPantryItemsUseCase(pantryRepository: FakePantryRepository()),
            createRecipeUseCase: CreateRecipeUseCase(
                searchRecipesUseCase: SearchRecipesUseCase(
                    spoonacularService: spoonacular,
                    aiFoodSearchService: MealPlanFakeAISearch()
                ),
                recipeRepository: harness.recipes
            ),
            createMealPlanUseCase: CreateMealPlanUseCase(
                mealPlanRepository: FakeMealPlanRepository(),
                spoonacularService: spoonacular,
                fetchUserPreferencesUseCase: FetchUserPreferencesUseCase(
                    userPreferenceRepository: harness.preferences
                ),
                fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                    foodEntryRepository: harness.food,
                    waterEntryRepository: harness.water,
                    userGoalsRepository: harness.goals,
                    workoutEntryRepository: harness.workout
                ),
                pantryRepository: FakePantryRepository()
            ),
            voiceRecorder: MealPlanFakeVoiceRecorder(),
            transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase(
                voiceFoodTranscriptionService: MealPlanFakeVoiceTranscription()
            )
        )
    }
}
