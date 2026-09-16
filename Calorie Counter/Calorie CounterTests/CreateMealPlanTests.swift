import XCTest
@testable import Calorie_Counter

@MainActor
final class CreateMealPlanTests: XCTestCase {
    func testSpoonacularSearchUsesFormParameters() {
        let search = CreateMealPlanUseCase.spoonacularSearch(
            meal: .breakfast,
            input: RecipeGenerationInput(
                ingredients: ["шпинат", "авокадо", "лосось"],
                mealTypes: ["breakfast"],
                cuisine: "recipes.filters.italian",
                diet: "recipes.filters.vegetarian",
                maxReadyMinutes: nil,
                maxCalories: nil,
                details: "high protein",
                startDate: Date(),
                endDate: Date()
            ),
            includeIngredients: true
        )
        XCTAssertEqual(search.cuisine, "Italian")
        XCTAssertEqual(search.diet, "vegetarian")
        XCTAssertEqual(search.type, "breakfast")
        XCTAssertEqual(search.includeIngredients, "шпинат, авокадо, лосось")
        XCTAssertTrue(search.query.contains("breakfast"))
        XCTAssertTrue(search.query.contains("high protein"))
        let window = MealPlanPacker.calorieWindow(
            meal: .breakfast,
            calorieGoal: UserGoals.default.calorieTarget,
            mealTypes: [.breakfast, .lunch, .dinner]
        )
        XCTAssertEqual(search.minCalories, window.min)
        XCTAssertEqual(search.maxCalories, window.max)
    }

    func testBreakfastCalorieWindowIsHeavierThanSnack() {
        let meals: [MealType] = [.breakfast, .lunch, .dinner, .snacks]
        let breakfast = MealPlanPacker.calorieWindow(meal: .breakfast, calorieGoal: 2000, mealTypes: meals)
        let lunch = MealPlanPacker.calorieWindow(meal: .lunch, calorieGoal: 2000, mealTypes: meals)
        let dinner = MealPlanPacker.calorieWindow(meal: .dinner, calorieGoal: 2000, mealTypes: meals)
        let snacks = MealPlanPacker.calorieWindow(meal: .snacks, calorieGoal: 2000, mealTypes: meals)
        XCTAssertGreaterThan(breakfast.max, lunch.max)
        XCTAssertGreaterThan(lunch.max, snacks.max)
        XCTAssertGreaterThan(dinner.max, snacks.max)
        XCTAssertGreaterThan(breakfast.min, snacks.min)
        XCTAssertGreaterThan(MealPlanPacker.calorieShare(for: .breakfast), MealPlanPacker.calorieShare(for: .dinner))
        XCTAssertGreaterThan(MealPlanPacker.calorieShare(for: .dinner), MealPlanPacker.calorieShare(for: .snacks))
    }

    func testPackAssignsCalorieFitPerMealAndKeepsOneDishEach() {
        let packed = MealPlanPacker.pack(
            pools: [
                .breakfast: [
                    mealPlanRecipe(title: "Breakfast Heavy", calories: 650),
                    mealPlanRecipe(title: "Breakfast Light", calories: 220)
                ],
                .lunch: [
                    mealPlanRecipe(title: "Lunch Fit", calories: 500),
                    mealPlanRecipe(title: "Lunch Tiny", calories: 120)
                ],
                .dinner: [
                    mealPlanRecipe(title: "Dinner Fit", calories: 430),
                    mealPlanRecipe(title: "Dinner Huge", calories: 980)
                ],
                .snacks: [
                    mealPlanRecipe(title: "Snack Fit", calories: 180),
                    mealPlanRecipe(title: "Snack Dessert", calories: 700)
                ]
            ],
            dayCount: 1,
            mealTypes: [.snacks, .dinner, .breakfast, .lunch],
            calorieGoal: 1800
        )
        XCTAssertEqual(packed.layouts, [4])
        let plan = MealPlan(
            id: UUID(),
            title: "Plan",
            weeks: 1,
            imageURL: nil,
            recipes: packed.recipes,
            createdAt: Date(),
            dayLayouts: packed.layouts,
            mealTypeKeys: ["breakfast", "lunch", "dinner", "snacks"]
        )
        let slots = plan.days()[0].slots
        XCTAssertEqual(slots.map(\.mealType), [.breakfast, .lunch, .dinner, .snacks])
        XCTAssertEqual(slots.map(\.recipe.title), [
            "Breakfast Heavy",
            "Lunch Fit",
            "Dinner Fit",
            "Snack Fit"
        ])
        XCTAssertGreaterThan(slots[0].recipe.calories ?? 0, slots[2].recipe.calories ?? 0)
        XCTAssertGreaterThan(slots[2].recipe.calories ?? 0, slots[3].recipe.calories ?? 0)
    }

    func testPackRotatesUniqueBreakfastsAcrossDays() {
        let packed = MealPlanPacker.pack(
            pools: [
                .breakfast: [
                    mealPlanRecipe(title: "Oats", calories: 600),
                    mealPlanRecipe(title: "Omelette", calories: 590),
                    mealPlanRecipe(title: "Yogurt Bowl", calories: 610)
                ]
            ],
            dayCount: 3,
            mealTypes: [.breakfast],
            calorieGoal: 600
        )
        XCTAssertEqual(packed.layouts, [1, 1, 1])
        XCTAssertEqual(Set(packed.recipes.map(\.title)).count, 3)
    }

    func testPackDailyCaloriesStayNearGoal() {
        let packed = MealPlanPacker.pack(
            pools: [
                .breakfast: [mealPlanRecipe(title: "Oats", calories: 620)],
                .lunch: [mealPlanRecipe(title: "Bowl", calories: 540)],
                .dinner: [mealPlanRecipe(title: "Salmon", calories: 460)]
            ],
            dayCount: 2,
            mealTypes: [.breakfast, .lunch, .dinner],
            calorieGoal: 1600
        )
        XCTAssertEqual(packed.layouts, [3, 3])
        packed.layouts.indices.forEach { day in
            let start = packed.layouts.prefix(day).reduce(0, +)
            let slice = packed.recipes[start..<(start + packed.layouts[day])]
            let total = slice.reduce(0) { $0 + ($1.calories ?? 0) }
            XCTAssertEqual(total, 1620, accuracy: 1)
            XCTAssertGreaterThan(total, 1600 * 0.9)
            XCTAssertLessThan(total, 1600 * 1.12)
        }
    }

    func testDinnerMapsToMainCourseAndSnackMapsToSnack() {
        XCTAssertEqual(CreateMealPlanUseCase.dishType(from: .dinner), "main course")
        XCTAssertEqual(CreateMealPlanUseCase.dishType(from: .snacks), "snack")
        XCTAssertNil(CreateMealPlanUseCase.dishType(from: .lunch))
        XCTAssertEqual(CreateMealPlanUseCase.cuisine(from: "recipes.filters.greek"), "Greek")
        XCTAssertEqual(CreateMealPlanUseCase.diet(from: "recipes.filters.vegan"), "vegan")
        XCTAssertNil(CreateMealPlanUseCase.diet(from: "recipes.filters.lean"))
    }

    func testCreateMealPlanSearchesSpoonacularNotAI() async throws {
        let spoonacular = MealPlanFakeSpoonacular()
        spoonacular.recipes = (1...6).map { index in
            mealPlanRecipe(title: "Dish \(index)", calories: 400)
        }
        let mealPlans = FakeMealPlanRepository()
        let useCase = makeUseCase(spoonacular: spoonacular, mealPlans: mealPlans)
        let plan = try await useCase.execute(
            RecipeGenerationInput(
                ingredients: ["шпинат", "авокадо"],
                mealTypes: ["breakfast", "lunch", "dinner"],
                cuisine: "recipes.filters.mexican",
                diet: "recipes.filters.vegan",
                maxReadyMinutes: nil,
                maxCalories: nil,
                details: "",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())
            )
        )
        XCTAssertNotNil(plan)
        XCTAssertFalse(spoonacular.searches.isEmpty)
        XCTAssertTrue(spoonacular.searches.allSatisfy { $0.cuisine == "Mexican" })
        XCTAssertTrue(spoonacular.searches.allSatisfy { $0.diet == "vegan" })
        XCTAssertTrue(spoonacular.searches.contains { $0.type == "breakfast" })
        XCTAssertTrue(spoonacular.searches.contains { $0.includeIngredients == "шпинат, авокадо" })
        XCTAssertEqual(mealPlans.saved.count, 1)
    }

    func testExecuteKeepsMealTypePoolsAndBreakfastCaloriesHighest() async throws {
        let spoonacular = MealPlanFakeSpoonacular()
        spoonacular.recipesByDishType = [
            "breakfast": [mealPlanRecipe(title: "Oatmeal Bowl", calories: 640)],
            "lunch": [mealPlanRecipe(title: "Chicken Salad", calories: 490)],
            "main course": [mealPlanRecipe(title: "Baked Salmon", calories: 420)],
            "snack": [mealPlanRecipe(title: "Greek Yogurt", calories: 160)]
        ]
        let useCase = makeUseCase(spoonacular: spoonacular, mealPlans: FakeMealPlanRepository())
        let plan = try await useCase.execute(
            RecipeGenerationInput(
                ingredients: [],
                mealTypes: ["dinner", "snacks", "breakfast", "lunch"],
                cuisine: nil,
                diet: nil,
                maxReadyMinutes: nil,
                maxCalories: nil,
                details: "",
                startDate: Date(),
                endDate: Date()
            )
        )
        let slots = try XCTUnwrap(plan?.days().first?.slots)
        XCTAssertEqual(slots.map(\.mealType), [.breakfast, .lunch, .dinner, .snacks])
        XCTAssertEqual(slots.map(\.recipe.title), [
            "Oatmeal Bowl",
            "Chicken Salad",
            "Baked Salmon",
            "Greek Yogurt"
        ])
        XCTAssertGreaterThan(slots[0].recipe.calories ?? 0, slots[1].recipe.calories ?? 0)
        XCTAssertGreaterThan(slots[1].recipe.calories ?? 0, slots[2].recipe.calories ?? 0)
        XCTAssertGreaterThan(slots[2].recipe.calories ?? 0, slots[3].recipe.calories ?? 0)
    }

    func testCreateMealPlanRetriesWithoutIngredientsWhenFirstSearchIsEmpty() async throws {
        let spoonacular = MealPlanFakeSpoonacular()
        spoonacular.recipesWhenNoIngredients = [
            mealPlanRecipe(title: "Fallback Bowl", calories: 420)
        ]
        let useCase = makeUseCase(spoonacular: spoonacular, mealPlans: FakeMealPlanRepository())
        let plan = try await useCase.execute(
            RecipeGenerationInput(
                ingredients: ["кефір", "шпинат"],
                mealTypes: ["breakfast"],
                cuisine: nil,
                diet: nil,
                maxReadyMinutes: nil,
                maxCalories: nil,
                details: "",
                startDate: Date(),
                endDate: Date()
            )
        )
        XCTAssertEqual(plan?.recipes.first?.title, "Fallback Bowl")
        XCTAssertTrue(spoonacular.searches.contains { $0.includeIngredients != nil })
        XCTAssertTrue(spoonacular.searches.contains { $0.includeIngredients == nil })
    }

    func testCreateMealPlanReturnsNilWhenSpoonacularIsEmpty() async throws {
        let useCase = makeUseCase(spoonacular: MealPlanFakeSpoonacular(), mealPlans: FakeMealPlanRepository())
        let plan = try await useCase.execute(
            RecipeGenerationInput(
                ingredients: ["шпинат"],
                mealTypes: ["breakfast"],
                cuisine: nil,
                diet: nil,
                maxReadyMinutes: nil,
                maxCalories: nil,
                details: "",
                startDate: Date(),
                endDate: Date()
            )
        )
        XCTAssertNil(plan)
    }

    func testViewModelCreateMealPlanCallsFinishWithPlan() async {
        let spoonacular = MealPlanFakeSpoonacular()
        spoonacular.recipes = [
            mealPlanRecipe(title: "Omelette", calories: 350)
        ]
        let harness = TestHarness()
        let mealPlans = FakeMealPlanRepository()
        let viewModel = CreateRecipeFormViewModel(
            kind: .mealPlan,
            fetchPantryItemsUseCase: FetchPantryItemsUseCase(pantryRepository: FakePantryRepository()),
            createRecipeUseCase: CreateRecipeUseCase(
                searchRecipesUseCase: SearchRecipesUseCase(
                    spoonacularService: spoonacular,
                    aiFoodSearchService: MealPlanFakeAISearch()
                ),
                recipeRepository: harness.recipes
            ),
            createMealPlanUseCase: makeUseCase(spoonacular: spoonacular, mealPlans: mealPlans, harness: harness),
            voiceRecorder: MealPlanFakeVoiceRecorder(),
            transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase(
                voiceFoodTranscriptionService: MealPlanFakeVoiceTranscription()
            )
        )
        let finished = expectation(description: "create finished")
        viewModel.onCreateFinished = { recipe, plan in
            XCTAssertNil(recipe)
            XCTAssertNotNil(plan)
            finished.fulfill()
        }
        viewModel.createTapped()
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(mealPlans.saved.count, 1)
        XCTAssertFalse(spoonacular.searches.isEmpty)
    }

    private func makeUseCase(
        spoonacular: MealPlanFakeSpoonacular,
        mealPlans: FakeMealPlanRepository,
        harness: TestHarness = TestHarness()
    ) -> CreateMealPlanUseCase {
        CreateMealPlanUseCase(
            mealPlanRepository: mealPlans,
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
        )
    }
}

private func mealPlanRecipe(title: String, calories: Double) -> Recipe {
    Recipe(
        id: UUID(),
        externalId: nil,
        title: title,
        summary: nil,
        imageURL: nil,
        readyInMinutes: nil,
        servings: 1,
        calories: calories,
        protein: nil,
        carbs: nil,
        fats: nil,
        ingredients: [],
        steps: [],
        sourceName: nil
    )
}

private final class FakeMealPlanRepository: MealPlanRepositoryProtocol {
    var saved: [MealPlan] = []

    func fetchAll() throws -> [MealPlan] { saved }

    func save(_ plan: MealPlan) throws {
        saved.removeAll { $0.id == plan.id }
        saved.append(plan)
    }

    func delete(id: UUID) throws {
        saved.removeAll { $0.id == id }
    }
}

private final class FakePantryRepository: PantryRepositoryProtocol {
    func fetchAll() throws -> [PantryItem] { [] }
    func save(_ item: PantryItem) throws {}
    func delete(ids: [UUID]) throws {}
}

private final class MealPlanFakeSpoonacular: SpoonacularServiceProtocol {
    var recipes: [Recipe] = []
    var recipesWhenNoIngredients: [Recipe] = []
    var recipesByDishType: [String: [Recipe]] = [:]
    private let lock = NSLock()
    private var recordedSearches: [SpoonacularRecipeSearch] = []

    var searches: [SpoonacularRecipeSearch] {
        lock.lock()
        defer { lock.unlock() }
        return recordedSearches
    }

    func searchRecipes(query: String, maxCalories: Int?, number: Int) async throws -> [Recipe] {
        recipes
    }

    func searchRecipes(_ search: SpoonacularRecipeSearch) async throws -> [Recipe] {
        lock.lock()
        recordedSearches.append(search)
        lock.unlock()
        if search.includeIngredients == nil, !recipesWhenNoIngredients.isEmpty {
            return recipesWhenNoIngredients
        }
        if let type = search.type, let specific = recipesByDishType[type], !specific.isEmpty {
            return specific
        }
        if search.type == nil, let lunch = recipesByDishType["lunch"], !lunch.isEmpty {
            return lunch
        }
        return recipes
    }

    func recipeDetails(id: String) async throws -> Recipe {
        mealPlanRecipe(title: "Recipe", calories: 100)
    }

    func searchIngredients(query: String, number: Int) async throws -> [FoodProduct] { [] }

    func ingredientDetails(id: String, amount: Double, unit: String) async throws -> FoodProduct {
        FoodProduct(
            id: UUID(),
            externalId: id,
            name: "Ingredient",
            brand: nil,
            kind: .ingredient,
            imageURL: nil,
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            amount: amount,
            unit: unit
        )
    }

    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] { [] }

    func productDetails(id: String) async throws -> FoodProduct {
        FoodProduct(
            id: UUID(),
            externalId: id,
            name: "Product",
            brand: nil,
            kind: .product,
            imageURL: nil,
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            amount: 100,
            unit: "g"
        )
    }

    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct {
        throw BarcodeLookupError.notFound
    }
}

private final class MealPlanFakeAISearch: AIFoodSearching {
    func searchFoods(query: String) async throws -> [FoodProduct] { [] }
    func searchRecipes(query: String) async throws -> [Recipe] { [] }
    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] { [:] }
    func fetchCatalogSection(id: String) async throws -> [FoodProduct] { [] }
    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        FoodSearchCatalogPage(products: [], nextOffset: offset, hasMore: false)
    }
    func enrichDetails(
        title: String,
        imageURL: URL?,
        source: String,
        kind: String
    ) async throws -> FoodProduct? { nil }
}

private final class MealPlanFakeVoiceRecorder: VoiceFoodAudioRecording {
    var isRecording = false
    var onPartialTranscript: ((String) -> Void)?
    var onUtteranceFinal: (() -> Void)?
    func requestPermission() async -> Bool { false }
    func startRecording() throws {}
    func stopRecording() throws -> Data { Data() }
    func cancelRecording() {}
    func normalizedPower() -> CGFloat { 0 }
}

private final class MealPlanFakeVoiceTranscription: VoiceFoodTranscriptionServiceProtocol {
    func transcribe(audioData: Data, mimeType: String) async throws -> VoiceFoodTranscription {
        VoiceFoodTranscription(text: "", language: nil, model: nil)
    }

    func analyze(
        audioData: Data,
        mimeType: String,
        mealType: MealType,
        userContext: AIAssistantUserContext?
    ) async throws -> VoiceFoodAnalysis {
        VoiceFoodAnalysis(
            transcription: "",
            transcriptionLanguage: nil,
            analysis: FoodPhotoAnalysis(
                name: "",
                mealType: mealType,
                calories: 0,
                protein: 0,
                carbs: 0,
                fats: 0,
                fiber: 0,
                sugar: 0,
                sodium: 0,
                portionGrams: nil,
                portionMilliliters: nil,
                confidence: 0,
                notes: "",
                assistantMessage: ""
            )
        )
    }
}
