import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class MealPlanBalanceTests: XCTestCase {
    private let goals = MealPlanTargets(calories: 2000, protein: 150, carbs: 200, fats: 67)

    // MARK: - Packing

    func testTheDayIsBuiltOnTheMacrosNotOnCaloriesAlone() {
        // Same calories on both sides: only the macros tell a balanced menu from pasta and pastries.
        let pools: [MealType: [Recipe]] = [
            .breakfast: [
                dish("Sweet pastry", 700, protein: 8, carbs: 98, fats: 30),
                dish("Egg white omelette with oats", 700, protein: 52, carbs: 70, fats: 23)
            ],
            .lunch: [
                dish("Creamy pasta", 680, protein: 14, carbs: 98, fats: 25),
                dish("Chicken rice bowl", 680, protein: 55, carbs: 70, fats: 21)
            ],
            .dinner: [
                dish("Cheese pizza", 620, protein: 20, carbs: 70, fats: 29),
                dish("Salmon with quinoa", 620, protein: 48, carbs: 55, fats: 22)
            ]
        ]

        let packed = MealPlanPacker.pack(
            pools: pools,
            dayCount: 1,
            mealTypes: [.breakfast, .lunch, .dinner],
            targets: goals
        )

        XCTAssertEqual(
            packed.recipes.map(\.title),
            ["Egg white omelette with oats", "Chicken rice bowl", "Salmon with quinoa"]
        )
        let totals = MealPlanPacker.dayTotals(packed.recipes, types: [.breakfast, .lunch, .dinner])
        XCTAssertGreaterThanOrEqual(totals.protein, goals.protein * 0.9, "The day feeds the protein goal")
        XCTAssertEqual(totals.calories, goals.calories, accuracy: goals.calories * 0.1)
    }

    func testAShortDayIsTopedUpTowardTheGoal() {
        let pools: [MealType: [Recipe]] = [
            .breakfast: [dish("Toast", 300, protein: 10, carbs: 40, fats: 8), dish("Big breakfast", 650, protein: 45, carbs: 60, fats: 24)],
            .lunch: [dish("Soup", 280, protein: 12, carbs: 30, fats: 10), dish("Beef bowl", 640, protein: 50, carbs: 65, fats: 20)],
            .dinner: [dish("Salad", 250, protein: 9, carbs: 20, fats: 12), dish("Chicken traybake", 600, protein: 48, carbs: 55, fats: 20)]
        ]
        let packed = MealPlanPacker.pack(pools: pools, dayCount: 1, mealTypes: [.breakfast, .lunch, .dinner], targets: goals)
        let totals = MealPlanPacker.dayTotals(packed.recipes, types: [.breakfast, .lunch, .dinner])
        XCTAssertEqual(totals.calories, goals.calories, accuracy: goals.calories * 0.12, "Not a half-empty day")
    }

    /// The whole path a user takes: their saved goals, the catalog search, the packing, the saved plan.
    func testCreatingAPlanUsesTheUsersMacrosFromEndToEnd() async throws {
        let harness = TestHarness()
        try harness.goals.save(UserGoals(
            calorieTarget: 2000, proteinTarget: 150, carbsTarget: 200, fatsTarget: 67,
            fiberTarget: 28, sugarTarget: 25, sodiumTarget: 2300, waterTargetMilliliters: 2500
        ))
        let catalog = MealPlanFakeSpoonacular()
        catalog.recipesByDishType["breakfast"] = [
            dish("Sweet pastry", 700, protein: 8, carbs: 98, fats: 30),
            dish("Egg white omelette with oats", 700, protein: 52, carbs: 70, fats: 23)
        ]
        catalog.recipesByDishType["main course"] = [
            dish("Creamy pasta", 680, protein: 14, carbs: 98, fats: 25),
            dish("Chicken rice bowl", 680, protein: 55, carbs: 70, fats: 21),
            dish("Cheese pizza", 620, protein: 20, carbs: 70, fats: 29),
            dish("Salmon with quinoa", 620, protein: 48, carbs: 55, fats: 22)
        ]
        let useCase = CreateMealPlanUseCase(
            mealPlanRepository: FakeMealPlanRepository(),
            spoonacularService: catalog,
            fetchUserPreferencesUseCase: FetchUserPreferencesUseCase(userPreferenceRepository: harness.preferences),
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                foodEntryRepository: harness.food,
                waterEntryRepository: harness.water,
                userGoalsRepository: harness.goals,
                workoutEntryRepository: harness.workout
            ),
            pantryRepository: FakePantryRepository()
        )

        let created = try await useCase.execute(RecipeGenerationInput(
            ingredients: [], mealTypes: ["breakfast", "lunch", "dinner"], cuisine: nil, diet: nil,
            maxReadyMinutes: nil, maxCalories: nil, details: "", startDate: Date(), endDate: Date()
        ))
        let plan = try XCTUnwrap(created)

        let day = try XCTUnwrap(plan.days().first)
        let totals = MealPlanPacker.dayTotals(day.slots.map(\.recipe), types: day.slots.map(\.mealType))
        XCTAssertFalse(day.slots.contains { ["Sweet pastry", "Creamy pasta", "Cheese pizza"].contains($0.recipe.title) },
                       "Same calories, less protein: \(day.slots.map(\.recipe.title))")
        XCTAssertGreaterThanOrEqual(totals.protein, 135, "At least 90% of the protein goal")
        XCTAssertEqual(totals.fats, 67, accuracy: 67 * 0.2)
        XCTAssertEqual(totals.carbs, 200, accuracy: 200 * 0.2)
        XCTAssertTrue(
            catalog.searches.contains { $0.type == "main course" && ($0.minProtein ?? 0) > 0 },
            "The catalog is asked for dishes with enough protein"
        )
    }

    // MARK: - Search

    func testMainMealsAreSearchedWithAProteinFloor() {
        let input = RecipeGenerationInput(
            ingredients: [], mealTypes: ["breakfast", "lunch", "dinner", "snacks"], cuisine: nil, diet: nil,
            maxReadyMinutes: nil, maxCalories: nil, details: "", startDate: Date(), endDate: Date()
        )
        let types: [MealType] = [.breakfast, .lunch, .dinner, .snacks]
        let lunch = CreateMealPlanUseCase.spoonacularSearch(
            meal: .lunch, input: input, includeIngredients: false,
            calorieGoal: 2000, proteinGoal: 150, mealTypes: types
        )
        XCTAssertEqual(lunch.minProtein, Int((150 * 0.30 * 0.5).rounded()), "Half of lunch's share of protein")
        let snack = CreateMealPlanUseCase.spoonacularSearch(
            meal: .snacks, input: input, includeIngredients: false,
            calorieGoal: 2000, proteinGoal: 150, mealTypes: types
        )
        XCTAssertNil(snack.minProtein, "A snack is not held to a meal's protein")
        let fallback = CreateMealPlanUseCase.spoonacularSearch(
            meal: .lunch, input: input, includeIngredients: false,
            calorieGoal: 2000, proteinGoal: 150, mealTypes: types, applyCalorieWindow: false
        )
        XCTAssertNil(fallback.minProtein, "The wide fallback search still finds something")
    }

    // MARK: - What Bity sees

    func testBitySeesEveryDishsMacrosAndTheDayTotals() throws {
        let plan = MealPlan(
            id: UUID(), title: "План 1", weeks: 1, imageURL: nil,
            recipes: [
                dish("Omelette", 450, protein: 30, carbs: 20, fats: 25),
                dish("Chicken bowl", 600, protein: 45, carbs: 60, fats: 15)
            ],
            createdAt: Date(), dayLayouts: [2], mealTypeKeys: ["breakfast", "lunch"]
        )
        let context = AIAssistantUserContextBuilder.makeMealPlanContext(from: plan, includingDays: true)
        let day = try XCTUnwrap(context.days?.first)
        XCTAssertEqual(day.meals.first?.protein, 30)
        XCTAssertEqual(day.meals.first?.fats, 25)
        XCTAssertEqual(day.totals, .init(calories: 1050, protein: 75, carbs: 80, fats: 40))
    }

    // MARK: - Bity's swap

    func testADishBityPutsInTheShowsAPicture() throws {
        let current = dish("Oatmeal", 420, protein: 14, carbs: 60, fats: 9)
        let url = URL(string: "https://example.com/food/image?name=omelette")
        let swapped = MealPlanSwapProposalMapper.recipe(
            from: MealPlanSwapProposal(replacementTitle: "Омлет зі шпинатом", calories: 410, protein: 28, carbs: 12, fats: 26),
            replacing: current,
            imageURL: url
        )
        XCTAssertEqual(swapped.imageURL, url)
        XCTAssertEqual(swapped.protein, 28)
    }

    // MARK: - Localisation

    func testTheTertiaryButtonShowsItsOwnTitleNotTheNibOne() {
        let button = UIButton(type: .system)
        button.setTitle("Edit with Bity", for: .normal)
        OnboardingStyle.styleTertiaryButton(button, title: "Редагувати з Bity")
        button.layoutIfNeeded()
        XCTAssertEqual(button.title(for: .normal), "Редагувати з Bity", "The nib's English title is replaced")
        XCTAssertEqual(button.configuration?.title, "Редагувати з Bity")
    }

    // MARK: - Helpers

    private func dish(_ title: String, _ calories: Double, protein: Double, carbs: Double, fats: Double) -> Recipe {
        Recipe(
            id: UUID(), externalId: "id-\(title)", title: title, summary: nil, imageURL: nil,
            readyInMinutes: 20, servings: 1, calories: calories, protein: protein, carbs: carbs, fats: fats,
            ingredients: [], steps: [], sourceName: nil
        )
    }
}
