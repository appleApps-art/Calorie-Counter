import XCTest
@testable import Calorie_Counter

@MainActor
final class PantryRecipeSuggestionTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testSoonestUseByFirstAndExpiredFoodSkipped() {
        let today = date(hour: 9)
        let items = [
            item("Olive oil"),
            item("Chicken breast", useBy: day(2, from: today)),
            item("Old milk", useBy: day(-1, from: today)),
            item("Spinach", useBy: day(0, from: today)),
            item("spinach"),
            item("Eggs", useBy: day(5, from: today))
        ]

        XCTAssertEqual(
            SuggestPantryRecipeUseCase.rankedIngredientNames(items, date: today, calendar: calendar),
            ["Spinach", "Chicken breast", "Eggs", "Olive oil"]
        )
    }

    func testDishTypeFollowsTimeOfDayAndCaloriesFollowTheRemainingBudget() {
        let items = [item("Eggs")]
        let breakfast = SuggestPantryRecipeUseCase.plan(for: items, remainingCalories: 1450.6, date: date(hour: 8), calendar: calendar)
        XCTAssertEqual(breakfast, PantryRecipeSuggestionPlan(ingredients: ["Eggs"], type: "breakfast", maxCalories: 1450))
        XCTAssertEqual(SuggestPantryRecipeUseCase.plan(for: items, remainingCalories: 900, date: date(hour: 13), calendar: calendar)?.type, "main course")
        XCTAssertEqual(SuggestPantryRecipeUseCase.plan(for: items, remainingCalories: 900, date: date(hour: 19), calendar: calendar)?.type, "main course")
        XCTAssertEqual(SuggestPantryRecipeUseCase.plan(for: items, remainingCalories: 900, date: date(hour: 22), calendar: calendar)?.type, "snack")
    }

    func testSpentBudgetSuggestsALightSnack() {
        let plan = SuggestPantryRecipeUseCase.plan(for: [item("Yogurt")], remainingCalories: -120, date: date(hour: 13), calendar: calendar)
        XCTAssertEqual(plan?.type, "snack")
        XCTAssertEqual(plan?.maxCalories, 200)
        XCTAssertNil(SuggestPantryRecipeUseCase.plan(for: [], remainingCalories: 800, date: date(hour: 13), calendar: calendar))
    }

    func testPrefersTheRecipeWithFewestMissingIngredientsThenMealTypeAndBudget() async {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let spoonacular = PantrySpoonacularStub()
        spoonacular.pantryMatches = [
            PantryRecipeMatch(id: "5", missedIngredientCount: 2),
            PantryRecipeMatch(id: "6", missedIngredientCount: 0),
            PantryRecipeMatch(id: "1", missedIngredientCount: 0),
            PantryRecipeMatch(id: "2", missedIngredientCount: 0),
            PantryRecipeMatch(id: "3", missedIngredientCount: 1),
            PantryRecipeMatch(id: "4", missedIngredientCount: 0)
        ]
        spoonacular.details = [
            "1": recipe("1", "No photo", photo: false, calories: 300, dishTypes: ["main course"]),
            "2": recipe("2", "Spinach Smoothie", calories: 250, dishTypes: ["breakfast"]),
            "3": recipe("3", "Salmon Pasta", calories: 500, dishTypes: ["main course"]),
            "4": recipe("4", "Salmon Salad", calories: 450, dishTypes: ["main course", "lunch"]),
            "5": recipe("5", "Eggs Benedict", calories: 400, dishTypes: ["main course"]),
            "6": recipe("6", "Frittata without steps", calories: 160, dishTypes: ["main course"], steps: [])
        ]
        let useCase = SuggestPantryRecipeUseCase(spoonacularService: spoonacular, fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase)

        let lunch = await useCase.execute(PantryRecipeSuggestionPlan(ingredients: ["Spinach", "Salmon"], type: "main course", maxCalories: 700))
        XCTAssertEqual(lunch?.title, "Salmon Salad")

        let snack = await useCase.execute(PantryRecipeSuggestionPlan(ingredients: ["Spinach"], type: "snack", maxCalories: 300))
        XCTAssertEqual(snack?.title, "Spinach Smoothie", "A complete pantry match wins over a closer meal type")

        spoonacular.pantryMatches = [
            PantryRecipeMatch(id: "5", missedIngredientCount: 2),
            PantryRecipeMatch(id: "3", missedIngredientCount: 1)
        ]
        let closest = await useCase.execute(PantryRecipeSuggestionPlan(ingredients: ["Salmon"], type: "breakfast", maxCalories: 700))
        XCTAssertEqual(closest?.title, "Salmon Pasta", "Without a complete match the fewest missing ingredients win")
    }

    func testFallsBackToIncludedIngredientSearchWhenPantryMatchingFindsNothing() async {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let spoonacular = PantrySpoonacularStub()
        spoonacular.searchResults = ["Spinach,Salmon": [
            recipe("8", "Frittata", calories: 160, dishTypes: []),
            recipe("9", "Salmon Bowl", calories: 500, dishTypes: [])
        ]]
        spoonacular.details = [
            "8": recipe("8", "Frittata", calories: 160, dishTypes: [], steps: []),
            "9": recipe("9", "Salmon Bowl", calories: 500, dishTypes: [])
        ]
        let useCase = SuggestPantryRecipeUseCase(spoonacularService: spoonacular, fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase)

        let recipe = await useCase.execute(PantryRecipeSuggestionPlan(ingredients: ["Spinach", "Salmon", "Eggs"], type: "main course", maxCalories: 700))

        XCTAssertEqual(recipe?.title, "Salmon Bowl")
        XCTAssertEqual(spoonacular.searches.first?.type, "main course")
        XCTAssertEqual(spoonacular.searches.first?.maxCalories, 700)
    }

    func testAddingAnyProductAsksForANewSuggestion() async throws {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        for (index, name) in ["Spinach", "Salmon", "Eggs"].enumerated() {
            try container.savePantryItemUseCase.execute(item(name, useBy: day(index + 1, from: Date())))
        }
        let spoonacular = PantrySpoonacularStub()
        let viewModel = makePantryViewModel(container, spoonacular: spoonacular)
        viewModel.viewDidLoad()
        await waitUntil(timeout: 2) { !viewModel.isSuggestionLoading.value }

        try container.savePantryItemUseCase.execute(item("Kiwi"))
        viewModel.reload()
        await waitUntil(timeout: 2) { !viewModel.isSuggestionLoading.value }

        XCTAssertEqual(spoonacular.pantryRequests.count, 2)
        XCTAssertTrue(spoonacular.pantryRequests.last?.contains("Kiwi") == true)
    }

    private func recipe(
        _ id: String,
        _ title: String,
        photo: Bool = true,
        calories: Double,
        dishTypes: [String],
        steps: [String] = ["Cook"]
    ) -> Recipe {
        Recipe(
            id: UUID(),
            externalId: id,
            title: title,
            imageURL: photo ? URL(string: "https://img.spoonacular.com/recipes/\(id)-312x231.jpg") : nil,
            calories: calories,
            protein: 10,
            carbs: 10,
            fats: 10,
            ingredients: [RecipeIngredient(id: "1", name: "Spinach")],
            steps: steps,
            dishTypes: dishTypes
        )
    }

    func testPantryShowsLoadingUntilTheSuggestionArrivesAndHidesWhenNothingIsFound() async throws {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        try container.savePantryItemUseCase.execute(item("Spinach"))
        let spoonacular = PantrySpoonacularStub()
        spoonacular.delayNanoseconds = 150_000_000
        spoonacular.pantryMatches = [PantryRecipeMatch(id: "7", missedIngredientCount: 0)]
        spoonacular.details = ["7": recipe("7", "Spinach Soup", calories: 150, dishTypes: [])]
        let viewModel = makePantryViewModel(container, spoonacular: spoonacular)

        viewModel.viewDidLoad()
        XCTAssertTrue(viewModel.isSuggestionLoading.value)
        XCTAssertNil(viewModel.suggestion.value)
        await waitUntil(timeout: 2) { !viewModel.isSuggestionLoading.value }
        XCTAssertEqual(viewModel.suggestion.value?.title, "Spinach Soup")

        spoonacular.pantryMatches = []
        try container.savePantryItemUseCase.execute(item("Tofu"))
        viewModel.reload()
        XCTAssertTrue(viewModel.isSuggestionLoading.value)
        XCTAssertNil(viewModel.suggestion.value)
        await waitUntil(timeout: 2) { !viewModel.isSuggestionLoading.value }
        XCTAssertNil(viewModel.suggestion.value)
    }

    private func makePantryViewModel(_ container: DIContainer, spoonacular: PantrySpoonacularStub) -> MyPantryViewModel {
        MyPantryViewModel(
            fetchPantryItemsUseCase: container.fetchPantryItemsUseCase,
            savePantryItemUseCase: container.savePantryItemUseCase,
            deletePantryItemsUseCase: container.deletePantryItemsUseCase,
            suggestPantryRecipeUseCase: SuggestPantryRecipeUseCase(
                spoonacularService: spoonacular,
                fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase
            )
        )
    }

    private func date(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: hour))!
    }

    private func day(_ offset: Int, from date: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: date)!
    }

    private func item(_ name: String, useBy: Date? = nil) -> PantryItem {
        PantryItem(
            id: UUID(),
            name: name,
            quantityText: "",
            amount: nil,
            unit: nil,
            useBy: useBy,
            imageURL: nil,
            imageData: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

private final class PantrySpoonacularStub: SpoonacularServiceProtocol, @unchecked Sendable {
    var pantryMatches: [PantryRecipeMatch] = []
    var details: [String: Recipe] = [:]
    var searchResults: [String: [Recipe]] = [:]
    var delayNanoseconds: UInt64 = 0
    private(set) var pantryRequests: [[String]] = []
    private(set) var searches: [SpoonacularRecipeSearch] = []

    func pantryRecipeMatches(ingredients: [String], number: Int) async throws -> [PantryRecipeMatch] {
        pantryRequests.append(ingredients)
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return pantryMatches
    }
    func searchRecipes(_ search: SpoonacularRecipeSearch) async throws -> [Recipe] {
        searches.append(search)
        return searchResults[search.includeIngredients ?? ""] ?? []
    }
    func searchRecipes(query: String, maxCalories: Int?, number: Int) async throws -> [Recipe] { [] }
    func searchIngredients(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] { [] }
    func recipeDetails(id: String) async throws -> Recipe {
        guard let recipe = details[id] else { throw URLError(.badServerResponse) }
        return recipe
    }
    func ingredientDetails(id: String, amount: Double, unit: String) async throws -> FoodProduct { throw URLError(.badServerResponse) }
    func productDetails(id: String) async throws -> FoodProduct { throw URLError(.badServerResponse) }
    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct { throw BarcodeLookupError.notFound }
}

@MainActor
final class PantrySuggestionLayoutTests: XCTestCase {
    func testLongPantryListNeverSquashesTheSuggestionCard() async throws {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        for index in 0..<14 {
            try container.savePantryItemUseCase.execute(PantryItem(
                id: UUID(), name: "Item \(index)", quantityText: "100 g", amount: nil, unit: nil, useBy: nil,
                imageURL: nil, imageData: nil, createdAt: Date(), updatedAt: Date()
            ))
        }
        let viewModel = MyPantryViewModel(
            fetchPantryItemsUseCase: container.fetchPantryItemsUseCase,
            savePantryItemUseCase: container.savePantryItemUseCase,
            deletePantryItemsUseCase: container.deletePantryItemsUseCase,
            suggestPantryRecipeUseCase: container.suggestPantryRecipeUseCase
        )
        let controller = MyPantryViewController(viewModel: viewModel)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        viewModel.isSuggestionLoading.value = false
        viewModel.suggestion.value = nil
        for _ in 0..<3 { controller.view.setNeedsLayout(); controller.view.layoutIfNeeded() }

        viewModel.isSuggestionLoading.value = true
        for _ in 0..<3 { controller.view.setNeedsLayout(); controller.view.layoutIfNeeded() }

        let section = try XCTUnwrap(controller.value(forKey: "suggestionSection") as? UIView)
        let card = try XCTUnwrap(controller.value(forKey: "suggestionCard") as? UIView)
        let list = try XCTUnwrap(controller.value(forKey: "listCard") as? UIView)
        XCTAssertGreaterThan(card.bounds.height, 60, "The suggestion card must keep its design height")
        let sectionBottom = section.convert(section.bounds, to: controller.view).maxY
        let listTop = list.convert(list.bounds, to: controller.view).minY
        XCTAssertGreaterThanOrEqual(listTop, sectionBottom)
        XCTAssertLessThanOrEqual(list.convert(list.bounds, to: controller.view).maxY, controller.view.bounds.height)
    }

    func testSuggestionCardKeepsItsHeightWhenReloadTogglesItInsideAnAnimation() async throws {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let viewModel = MyPantryViewModel(
            fetchPantryItemsUseCase: container.fetchPantryItemsUseCase,
            savePantryItemUseCase: container.savePantryItemUseCase,
            deletePantryItemsUseCase: container.deletePantryItemsUseCase,
            suggestPantryRecipeUseCase: container.suggestPantryRecipeUseCase
        )
        let controller = MyPantryViewController(viewModel: viewModel)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        let section = try XCTUnwrap(controller.value(forKey: "suggestionSection") as? UIView)
        let recipe = Recipe(id: UUID(), externalId: "1", title: "Soup", imageURL: nil, ingredients: [], steps: [])

        viewModel.suggestion.value = recipe
        viewModel.isSuggestionLoading.value = false
        controller.view.layoutIfNeeded()
        XCTAssertGreaterThan(section.bounds.height, 60)

        for _ in 0..<3 {
            UIView.animate(withDuration: 0.3) {
                viewModel.suggestion.value = nil
                viewModel.isSuggestionLoading.value = false
                viewModel.suggestion.value = nil
                viewModel.isSuggestionLoading.value = true
                controller.view.layoutIfNeeded()
            }
        }
        try await Task.sleep(nanoseconds: 600_000_000)
        controller.view.layoutIfNeeded()

        XCTAssertFalse(section.isHidden)
        XCTAssertGreaterThan(section.bounds.height, 60, "A visible loading card must not collapse")
    }
}
