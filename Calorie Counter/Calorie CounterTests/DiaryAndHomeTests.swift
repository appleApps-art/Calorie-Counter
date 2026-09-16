import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class DiaryAndHomeTests: XCTestCase {
    func testWaterUpdatePreservesFoodRows() throws {
        let harness = TestHarness()
        try harness.goals.save(.default)
        _ = try harness.logFood().execute(harness.foodEntry(name: "Breakfast", date: Date()))
        let vm = harness.homeViewModel()
        let controller = HomeViewController(viewModel: vm)
        controller.loadViewIfNeeded()

        func foodRows(in view: UIView) -> [FoodItemRowView] {
            view.subviews.flatMap { child -> [FoodItemRowView] in
                if let row = child as? FoodItemRowView { return [row] }
                return foodRows(in: child)
            }
        }

        let before = foodRows(in: controller.view)
        XCTAssertFalse(before.isEmpty)
        vm.logWater(amountMilliliters: 250)
        let after = foodRows(in: controller.view)
        XCTAssertEqual(before.map(ObjectIdentifier.init), after.map(ObjectIdentifier.init))
        XCTAssertEqual(vm.diary.value?.waterMilliliters, 250)
    }

    func testUnchangedReloadDoesNotRepublishHomeOrStreak() throws {
        let harness = TestHarness()
        try harness.goals.save(.default)
        let vm = harness.homeViewModel()
        vm.viewDidLoad()
        var screenUpdates = 0
        var streakUpdates = 0
        vm.screen.bind { _ in screenUpdates += 1 }
        vm.streakCount.bind { _ in streakUpdates += 1 }
        screenUpdates = 0
        streakUpdates = 0

        vm.reload()
        XCTAssertEqual(screenUpdates, 0)
        XCTAssertEqual(streakUpdates, 0)
        vm.logWater(amountMilliliters: 250)
        XCTAssertEqual(screenUpdates, 1)
        vm.reload()
        XCTAssertEqual(screenUpdates, 1)
    }

    func testHomeLogsWaterWorkoutWeightAndDeletes() async throws {
        let harness = TestHarness()
        try harness.goals.save(.default)
        let vm = harness.homeViewModel()
        vm.viewDidLoad()
        XCTAssertEqual(vm.diary.value?.foodEntries.count, 0)

        vm.logWater(amountMilliliters: 250)
        XCTAssertEqual(vm.diary.value?.waterMilliliters, 250)

        vm.logWorkout(name: "Cycling", durationMinutes: 40, caloriesBurned: 360)
        XCTAssertEqual(vm.diary.value?.workouts.count, 1)
        XCTAssertEqual(vm.diary.value?.burnedCalories, 360)

        vm.logWeight(kilograms: 77.7)
        XCTAssertEqual(try harness.weight.fetchEntries().last?.weightKilograms, 77.7)

        let food = try harness.logFood().execute(harness.foodEntry(calories: 500, date: Date()))
        vm.reload()
        XCTAssertEqual(vm.diary.value?.totalCalories, 0)
        XCTAssertEqual(vm.diary.value?.foodEntries.count, 1)

        vm.toggleEaten(id: food.id)
        XCTAssertEqual(vm.diary.value?.totalCalories, 500)

        vm.scaleFood(id: food.id, grams: 50)
        XCTAssertEqual(vm.diary.value?.totalCalories, 250)

        vm.deleteFood(id: food.id)
        vm.deleteWater(id: vm.diary.value?.waterEntries.first?.id ?? UUID())
        vm.deleteWorkout(id: vm.diary.value?.workouts.first?.id ?? UUID())
        vm.reload()
        XCTAssertEqual(vm.diary.value?.foodEntries.count, 0)
        XCTAssertEqual(vm.diary.value?.waterMilliliters, 0)
        XCTAssertEqual(vm.diary.value?.workouts.count, 0)
    }

    func testHomeDayNavigationIsolatesEntries() throws {
        let harness = TestHarness()
        try harness.goals.save(.default)
        let todayFood = try harness.logFood().execute(harness.foodEntry(name: "Today", date: Date()))
        _ = try harness.logFood().execute(
            harness.foodEntry(name: "Yesterday", date: testDate(hour: 12, daysFromNow: -1))
        )
        let vm = harness.homeViewModel()
        vm.viewDidLoad()
        XCTAssertEqual(vm.diary.value?.foodEntries.map(\.name), ["Today"])
        vm.selectPreviousDay()
        XCTAssertEqual(vm.diary.value?.foodEntries.map(\.name), ["Yesterday"])
        vm.selectToday()
        XCTAssertEqual(vm.diary.value?.foodEntries.first?.id, todayFood.id)
    }

    func testCompleteOnboardingPersistsGoalsAndFlag() throws {
        let harness = TestHarness()
        var profile = try harness.profile.fetchProfile()
        profile.sex = .male
        profile.age = 26
        profile.heightCm = 178
        profile.weightKg = 76
        profile.activityLevel = .active
        profile.goalType = .maintain
        let plan = try CompleteOnboardingUseCase(
            userProfileRepository: harness.profile,
            userGoalsRepository: harness.goals
        ).execute(profile: profile)
        let stored = try harness.profile.fetchProfile()
        XCTAssertTrue(stored.onboardingCompleted)
        XCTAssertEqual(stored.onboardingStep, .completed)
        XCTAssertEqual(try harness.goals.fetchGoals(), plan.goals)
    }

    func testCompleteOnboardingRejectsIncompleteProfile() {
        let harness = TestHarness()
        XCTAssertThrowsError(
            try CompleteOnboardingUseCase(
                userProfileRepository: harness.profile,
                userGoalsRepository: harness.goals
            ).execute(profile: .empty)
        )
    }

    func testAIConfirmLogsFoodAndWaterAndReplaceByName() throws {
        let harness = TestHarness()
        let confirm = ConfirmAIAssistantActionUseCase(
            logFoodUseCase: harness.logFood(),
            replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
            logWaterUseCase: harness.logWater(),
            saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
            recipeRepository: harness.recipes,
            foodEntryRepository: harness.food
        )
        try confirm.execute(
            .logFood(
                FoodLogProposal(name: "Eggs", mealType: .breakfast, calories: 180, protein: 14, carbs: 1, fats: 12)
            )
        )
        try confirm.execute(.logWater(WaterLogProposal(amountMilliliters: 300, note: nil)))
        try confirm.execute(
            .replaceFood(
                FoodReplaceProposal(
                    targetEntryId: nil,
                    targetName: "eggs",
                    targetMealType: nil,
                    newItem: FoodLogProposal(
                        name: "Egg whites",
                        mealType: .breakfast,
                        calories: 90,
                        protein: 18,
                        carbs: 1,
                        fats: 0
                    ),
                    reason: nil
                )
            )
        )
        let foods = try harness.food.fetchEntries(for: Date())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods[0].name, "Egg whites")
        XCTAssertEqual(foods[0].calories, 90)
        XCTAssertEqual(try harness.water.fetchEntries(for: Date()).first?.amountMilliliters, 300)
    }

    func testAIReplacementRequiresSeparateEatenConfirmation() throws {
        for matchByID in [true, false] {
            for wasEaten in [true, false] {
                let harness = TestHarness()
                var original = harness.foodEntry(name: "Eggs", date: Date())
                original.isEaten = wasEaten
                try harness.food.save(original)
                let confirm = ConfirmAIAssistantActionUseCase(
                    logFoodUseCase: harness.logFood(),
                    replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
                    logWaterUseCase: harness.logWater(),
                    saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
                    recipeRepository: harness.recipes,
                    foodEntryRepository: harness.food
                )
                try confirm.execute(.replaceFood(FoodReplaceProposal(
                    targetEntryId: matchByID ? original.id : nil,
                    targetName: original.name,
                    targetMealType: nil,
                    newItem: FoodLogProposal(
                        name: "Egg whites", mealType: original.mealType,
                        calories: 90, protein: 18, carbs: 1, fats: 0
                    ),
                    reason: nil
                )))

                let replacement = try XCTUnwrap(harness.food.fetchEntry(id: original.id))
                XCTAssertEqual(try harness.food.fetchEntries(for: original.date).count, 1)
                XCTAssertEqual(replacement.name, "Egg whites")
                XCTAssertEqual(replacement.date, original.date)
                XCTAssertFalse(replacement.isEaten)

                let home = harness.homeViewModel()
                home.viewDidLoad()
                home.toggleEaten(id: replacement.id)
                XCTAssertEqual(try harness.food.fetchEntry(id: replacement.id)?.isEaten, true)
            }
        }
    }

    func testAIReplaceWithoutMatchLogsNewItem() throws {
        let harness = TestHarness()
        let confirm = ConfirmAIAssistantActionUseCase(
            logFoodUseCase: harness.logFood(),
            replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
            logWaterUseCase: harness.logWater(),
            saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
            recipeRepository: harness.recipes,
            foodEntryRepository: harness.food
        )
        try confirm.execute(
            .replaceFood(
                FoodReplaceProposal(
                    targetEntryId: nil,
                    targetName: "Missing",
                    targetMealType: nil,
                    newItem: FoodLogProposal(
                        name: "Salad",
                        mealType: .lunch,
                        calories: 220,
                        protein: 8,
                        carbs: 12,
                        fats: 14
                    ),
                    reason: nil
                )
            )
        )
        XCTAssertEqual(try harness.food.fetchEntries(for: Date()).first?.name, "Salad")
    }

    func testAISavesRecipeAndSwapsIngredient() throws {
        let harness = TestHarness()
        let confirm = ConfirmAIAssistantActionUseCase(
            logFoodUseCase: harness.logFood(),
            replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
            logWaterUseCase: harness.logWater(),
            saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
            recipeRepository: harness.recipes,
            foodEntryRepository: harness.food
        )
        try confirm.execute(
            .saveRecipe(
                RecipeSaveProposal(
                    title: "Bowl",
                    summary: nil,
                    calories: 500,
                    protein: 30,
                    carbs: 40,
                    fats: 18,
                    cookTimeMinutes: nil,
                    externalRecipeId: "bowl-1",
                    ingredients: ["Rice", "Chicken"],
                    steps: ["Mix"]
                )
            )
        )
        try confirm.execute(
            .swapRecipeIngredient(
                RecipeIngredientSwapProposal(
                    recipeExternalId: "bowl-1",
                    originalName: "Rice",
                    originalAmount: nil,
                    originalUnit: nil,
                    replacementName: "Cauliflower rice",
                    replacementAmount: nil,
                    replacementUnit: nil,
                    replacementCalories: nil,
                    replacementProtein: nil,
                    replacementCarbs: nil,
                    replacementFats: nil,
                    updatedRecipeCalories: 320,
                    updatedRecipeProtein: nil,
                    updatedRecipeCarbs: nil,
                    updatedRecipeFats: nil,
                    reason: nil
                )
            )
        )
        let saved = try harness.recipes.fetchSaved(externalId: "bowl-1")
        XCTAssertEqual(saved?.ingredients.first(where: { $0.name.contains("Cauliflower") })?.name, "Cauliflower rice")
        XCTAssertEqual(saved?.calories, 320)
    }

    func testMealSuggestionLogsFood() throws {
        let harness = TestHarness()
        let confirm = ConfirmAIAssistantActionUseCase(
            logFoodUseCase: harness.logFood(),
            replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
            logWaterUseCase: harness.logWater(),
            saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
            recipeRepository: harness.recipes,
            foodEntryRepository: harness.food
        )
        try confirm.executeMealSuggestion(
            MealSuggestionOption(
                title: "Salmon bowl",
                summary: "High protein",
                calories: 480,
                protein: 38,
                carbs: 30,
                fats: 18,
                cookTimeMinutes: nil,
                externalRecipeId: nil,
                ingredients: ["Salmon"]
            ),
            mealType: .dinner
        )
        let entry = try harness.food.fetchEntries(for: Date())[0]
        XCTAssertEqual(entry.name, "Salmon bowl")
        XCTAssertEqual(entry.mealType, .dinner)
        XCTAssertEqual(entry.source, "suggestion")
    }

    func testEmptyProgressPhotoRejectedAndValidPhotoPersists() throws {
        let harness = TestHarness()
        let useCase = SaveProgressPhotoUseCase(
            progressPhotoRepository: harness.photos,
            fileStore: harness.photoStore
        )
        XCTAssertThrowsError(
            try useCase.execute(imageData: Data(), kind: .progress, pose: .front)
        )
        let photo = try useCase.execute(
            imageData: Data([0xFF, 0xD8, 0xFF]),
            kind: .progress,
            pose: .front,
            awardsXP: false
        )
        XCTAssertTrue(harness.photoStore.fileExists(fileName: photo.fileName))
        XCTAssertEqual(try harness.photos.fetchAll().count, 1)
    }

    func testLogFoodFromProductUsesBrandAndSearchSource() throws {
        let harness = TestHarness()
        let product = FoodProduct(
            id: UUID(),
            externalId: "p1",
            name: "Oat drink",
            brand: "Oatly",
            kind: .product,
            imageURL: nil,
            calories: 140,
            protein: 3,
            carbs: 16,
            fats: 5,
            amount: 100,
            unit: "g"
        )
        let entry = try harness.logFood().execute(from: product, mealType: .snacks)
        XCTAssertEqual(entry.name, "Oatly · Oat drink")
        XCTAssertEqual(entry.source, "search")
        XCTAssertEqual(entry.portionGrams, 100)
    }
}
