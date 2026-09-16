import XCTest
@testable import Calorie_Counter

@MainActor
final class DomainLogicTests: XCTestCase {
    func testNutritionPlanMaleLoseUsesCalorieFloor() {
        let profile = UserProfile(
            id: UUID(),
            sex: .female,
            age: 30,
            heightCm: 150,
            weightKg: 40,
            activityLevel: .sedentary,
            goalType: .lose,
            avatarFileName: nil,
            avatarURL: nil,
            onboardingStep: .plan,
            onboardingCompleted: false,
            updatedAt: Date()
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let plan = CalculateNutritionPlanUseCase().execute(
            profile: profile,
            now: now,
            calendar: Calendar(identifier: .gregorian)
        )
        XCTAssertEqual(plan?.goals.calorieTarget, 1200)
        XCTAssertEqual(plan?.goalType, .lose)
        XCTAssertEqual(plan?.goals.proteinTarget, 80)
        XCTAssertEqual(plan?.goals.fiberTarget, 25)
        XCTAssertEqual(plan?.goals.sugarTarget, 15)
        XCTAssertEqual(plan?.goals.sodiumTarget, 2300)
        XCTAssertEqual(plan?.estimatedGoalDate, now)
        XCTAssertGreaterThanOrEqual(plan?.goals.waterTargetMilliliters ?? 0, 2000)
    }

    func testNutritionPlanFiberSugarScaleWithCalories() {
        let profile = UserProfile(
            id: UUID(),
            sex: .male,
            age: 28,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderate,
            goalType: .maintain,
            avatarFileName: nil,
            avatarURL: nil,
            onboardingStep: .plan,
            onboardingCompleted: false,
            updatedAt: Date()
        )
        let plan = CalculateNutritionPlanUseCase().execute(profile: profile)
        let calories = plan?.goals.calorieTarget ?? 0
        XCTAssertEqual(plan?.goals.fiberTarget, max(25, (14 * calories / 1000).rounded()))
        XCTAssertEqual(plan?.goals.sugarTarget, (calories * 0.05 / 4).rounded())
        XCTAssertNil(plan?.estimatedGoalDate)
    }

    func testNutritionPlanLoseGoalDateUsesBMI22() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = UserProfile(
            id: UUID(),
            sex: .male,
            age: 28,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderate,
            goalType: .lose,
            avatarFileName: nil,
            avatarURL: nil,
            onboardingStep: .plan,
            onboardingCompleted: false,
            updatedAt: Date()
        )
        let plan = CalculateNutritionPlanUseCase().execute(
            profile: profile,
            now: now,
            calendar: calendar
        )
        let targetKg = 22.0 * 1.8 * 1.8
        let days = Int((((80.0 - targetKg) / 0.5) * 7).rounded())
        let expected = calendar.date(byAdding: .day, value: days, to: now)
        XCTAssertEqual(plan?.estimatedGoalDate, expected)
    }

    func testNutritionPlanGainGoalDateUsesFiveKilograms() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = UserProfile(
            id: UUID(),
            sex: .male,
            age: 28,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderate,
            goalType: .gain,
            avatarFileName: nil,
            avatarURL: nil,
            onboardingStep: .plan,
            onboardingCompleted: false,
            updatedAt: Date()
        )
        let plan = CalculateNutritionPlanUseCase().execute(
            profile: profile,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(
            plan?.estimatedGoalDate,
            calendar.date(byAdding: .day, value: 140, to: now)
        )
    }

    func testNutritionPlanMaleMaintainAndGain() {
        let base = UserProfile(
            id: UUID(),
            sex: .male,
            age: 28,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderate,
            goalType: .maintain,
            avatarFileName: nil,
            avatarURL: nil,
            onboardingStep: .plan,
            onboardingCompleted: false,
            updatedAt: Date()
        )
        let maintain = CalculateNutritionPlanUseCase().execute(profile: base)
        var gainProfile = base
        gainProfile.goalType = .gain
        let gain = CalculateNutritionPlanUseCase().execute(profile: gainProfile)
        let gainCalories = gain?.goals.calorieTarget ?? 0
        let maintainCalories = maintain?.goals.calorieTarget ?? 0
        XCTAssertEqual(gainCalories - maintainCalories, 300)
        let expectedBMR = (10.0 * 80.0 + 6.25 * 180.0 - 5.0 * 28.0 + 5.0).rounded()
        XCTAssertEqual(maintain?.bmr, expectedBMR)
    }

    func testIncompleteProfileHasNoPlan() {
        XCTAssertNil(CalculateNutritionPlanUseCase().execute(profile: .empty))
    }

    func testDefaultWeightGoalUsesExistingPlanGuidelines() {
        let lose = UserProfile(
            id: UUID(),
            sex: .male,
            age: 28,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderate,
            goalType: .lose,
            avatarFileName: nil,
            avatarURL: nil,
            onboardingStep: .plan,
            onboardingCompleted: false,
            updatedAt: Date()
        )
        XCTAssertEqual(
            CalculateNutritionPlanUseCase.defaultTargetWeightKilograms(
                goal: .lose,
                heightCm: 180,
                weightKg: 80
            ),
            22.0 * 1.8 * 1.8
        )
        XCTAssertEqual(
            CalculateNutritionPlanUseCase.defaultTargetWeightKilograms(
                goal: .maintain,
                heightCm: 180,
                weightKg: 80
            ),
            80
        )
        XCTAssertEqual(
            CalculateNutritionPlanUseCase.defaultTargetWeightKilograms(
                goal: .gain,
                heightCm: 180,
                weightKg: 80
            ),
            85
        )
        XCTAssertEqual(
            CalculateNutritionPlanUseCase.defaultTargetWeightKilograms(
                goal: .lose,
                heightCm: 180,
                weightKg: 70
            ),
            70
        )
        XCTAssertEqual(
            CalculateNutritionPlanUseCase.resolvedTargetWeightKilograms(profile: lose),
            22.0 * 1.8 * 1.8
        )
        var custom = lose
        custom.targetWeightKg = 74
        XCTAssertEqual(
            CalculateNutritionPlanUseCase.resolvedTargetWeightKilograms(profile: custom),
            74
        )
    }

    func testCustomWeightGoalDrivesEstimatedDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var profile = UserProfile(
            id: UUID(),
            sex: .male,
            age: 28,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderate,
            goalType: .lose,
            avatarFileName: nil,
            avatarURL: nil,
            onboardingStep: .plan,
            onboardingCompleted: false,
            updatedAt: Date()
        )
        profile.targetWeightKg = 75
        let plan = CalculateNutritionPlanUseCase().execute(
            profile: profile,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(
            plan?.estimatedGoalDate,
            calendar.date(byAdding: .day, value: 70, to: now)
        )
    }

    func testFoodScalingUsesHundredGramsWhenMissing() {
        let entry = FoodEntry(
            id: UUID(),
            name: "Rice",
            mealType: .lunch,
            calories: 200,
            protein: 4,
            carbs: 40,
            fats: 1,
            fiber: 1,
            sugar: 0,
            sodium: 10,
            date: Date()
        )
        let scaled = ScaleFoodPortionUseCase().execute(entry: entry, grams: 50)
        XCTAssertEqual(scaled.calories, 100)
        XCTAssertEqual(scaled.protein, 2)
        XCTAssertEqual(scaled.portionGrams, 50)
        XCTAssertEqual(scaled.id, entry.id)
    }

    func testDailyDiaryTotalsNetAndNegativeRemaining() {
        let summary = DailyDiarySummary(
            date: Date(),
            foodEntries: [
                FoodEntry(
                    id: UUID(),
                    name: "Pizza",
                    mealType: .dinner,
                    calories: 2300,
                    protein: 80,
                    carbs: 220,
                    fats: 90,
                    fiber: 8,
                    sugar: 12,
                    sodium: 1800,
                    date: Date(),
                    isEaten: true
                )
            ],
            waterEntries: [
                WaterEntry(id: UUID(), amountMilliliters: 400, date: Date()),
                WaterEntry(id: UUID(), amountMilliliters: 300, date: Date()),
            ],
            workouts: [
                WorkoutEntry(id: UUID(), name: "Run", durationMinutes: 30, caloriesBurned: 400, date: Date())
            ],
            waterMilliliters: 700,
            goals: .default
        )
        XCTAssertEqual(summary.totalCalories, 2300)
        XCTAssertEqual(summary.waterMilliliters, 700)
        XCTAssertEqual(summary.burnedCalories, 400)
        XCTAssertEqual(summary.netCalories, 1900)
        XCTAssertEqual(summary.remainingCalories, -300)
        XCTAssertEqual(summary.entries(for: .dinner).count, 1)
        XCTAssertTrue(summary.entries(for: .breakfast).isEmpty)
        XCTAssertEqual(summary.nutritionFacts.grade, NutritionFactsCalculator.facts(for: summary.foodEntries[0]).grade)
    }

    func testDailyDiaryTotalsIgnoreUneatenFood() {
        let uneaten = FoodEntry(
            id: UUID(),
            name: "Snack",
            mealType: .snacks,
            calories: 400,
            protein: 10,
            carbs: 40,
            fats: 12,
            fiber: 3,
            sugar: 8,
            sodium: 200,
            date: Date(),
            isEaten: false
        )
        let eaten = FoodEntry(
            id: UUID(),
            name: "Yogurt",
            mealType: .snacks,
            calories: 150,
            protein: 12,
            carbs: 16,
            fats: 4,
            fiber: 0,
            sugar: 12,
            sodium: 80,
            date: Date(),
            isEaten: true
        )
        let summary = DailyDiarySummary(
            date: Date(),
            foodEntries: [uneaten, eaten],
            waterEntries: [],
            workouts: [],
            waterMilliliters: 0,
            goals: .default
        )
        XCTAssertEqual(summary.totalCalories, 150)
        XCTAssertEqual(summary.totalProtein, 12)
        XCTAssertEqual(summary.totalCarbs, 16)
        XCTAssertEqual(summary.totalFats, 4)
        XCTAssertEqual(summary.remainingCalories, summary.goals.calorieTarget - 150)
        XCTAssertEqual(summary.entries(for: .snacks).count, 2)
        XCTAssertEqual(summary.eatenEntries.count, 1)
    }

    func testBadgeCelebrationWaitsUntilSeen() {
        let unlocked = BadgeProgress(badge: .hydrationHero, current: 7, goal: 7)
        let locked = BadgeProgress(badge: .proteinMaster, current: 1, goal: 3)
        XCTAssertEqual(
            BadgeProgress.awaitingCelebration(in: [unlocked, locked], seenIDs: []).map(\.badge),
            [.hydrationHero]
        )
        XCTAssertTrue(
            BadgeProgress.awaitingCelebration(
                in: [unlocked, locked],
                seenIDs: [RewardBadge.hydrationHero.rawValue]
            ).isEmpty
        )
    }

    func testNutritionBadges() {
        let highProtein = NutritionFactsCalculator.facts(
            calories: 300,
            protein: 40,
            carbs: 10,
            fats: 8,
            fiber: 6,
            sugar: 3,
            sodium: 200
        )
        XCTAssertTrue(highProtein.badges.contains(.highProtein))
        XCTAssertTrue(highProtein.badges.contains(.lowCarb))
        XCTAssertTrue(highProtein.badges.contains(.highFiber))
        XCTAssertTrue(highProtein.badges.contains(.lowSugar))
        XCTAssertGreaterThanOrEqual(highProtein.score, 70)
        let lowSodium = NutritionFactsCalculator.facts(
            calories: 200,
            protein: 8,
            carbs: 20,
            fats: 8,
            fiber: 2,
            sugar: 4,
            sodium: 80
        )
        XCTAssertTrue(lowSodium.badges.contains(.lowSodium))
    }

    func testNutritionDailyValueIncludesCaloriesAndSugar() {
        let facts = NutritionFactsCalculator.facts(
            calories: 200,
            protein: 10,
            carbs: 20,
            fats: 5,
            fiber: 2,
            sugar: 10,
            sodium: 230
        )
        XCTAssertEqual(facts.dailyValue.calories, 10, accuracy: 0.01)
        XCTAssertEqual(facts.dailyValue.sugar, 20, accuracy: 0.01)
    }

    func testProductDetailsParsesIngredientsAndScalesPortion() {
        let chicken = ProductDetailsMath.parseIngredientLine("Chicken 150g")
        XCTAssertEqual(chicken?.name, "Chicken")
        XCTAssertEqual(chicken?.grams, 150)
        let portion = ProductDetailsMath.parsePortion("450g")
        XCTAssertEqual(portion?.value, 450)
        XCTAssertEqual(portion?.isMilliliters, false)
        let analysis = FoodPhotoAnalysis(
            name: "Bowl",
            mealType: .lunch,
            calories: 420,
            protein: 38,
            carbs: 42,
            fats: 12,
            fiber: 8,
            sugar: 4,
            sodium: 200,
            portionGrams: 450,
            portionMilliliters: nil,
            confidence: 0.9,
            notes: "",
            assistantMessage: "",
            ingredients: [
                FoodIngredient(name: "Chicken", grams: 150),
                FoodIngredient(name: "Rice", grams: 300)
            ]
        )
        let draft = ProductDetailsMath.draft(from: analysis, imageData: nil, mealType: .lunch, date: Date())
        let scaled = ProductDetailsMath.scaled(draft, toGrams: 225)
        XCTAssertEqual(scaled.calories, 210, accuracy: 0.01)
        XCTAssertEqual(scaled.portionGrams, 225)
        XCTAssertEqual(scaled.ingredients.first?.grams, 75)
        var doubled = scaled
        doubled.servings = 2
        let entry = doubled.toFoodEntry()
        XCTAssertEqual(entry.calories, 420, accuracy: 0.01)
        XCTAssertEqual(entry.mealType, .lunch)
        XCTAssertEqual(FoodNutritionBadge.fromTag("gluten-free"), .glutenFree)
    }

    func testVoiceAnalysisDraftUsesVoiceSource() {
        var analysis = FoodPhotoAnalysis(
            name: "Chicken breast",
            mealType: .dinner,
            calories: 330,
            protein: 62,
            carbs: 0,
            fats: 7,
            fiber: 0,
            sugar: 0,
            sodium: 140,
            portionGrams: 200,
            portionMilliliters: nil,
            confidence: 0.9,
            notes: "200g",
            assistantMessage: "",
            source: "voice"
        )
        analysis.source = "voice"
        let draft = ProductDetailsMath.draft(
            from: analysis,
            imageData: nil,
            mealType: .dinner,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(draft.source, "voice")
        XCTAssertEqual(draft.name, "Chicken breast")
        XCTAssertEqual(draft.mealType, .dinner)
        XCTAssertEqual(draft.portionGrams, 200)
    }

    func testFoodEntryMapsToProductDetailsDraft() {
        let image = URL(string: "https://example.com/food.jpg")
        let entry = FoodEntry(
            id: UUID(),
            name: "Пельмені",
            mealType: .breakfast,
            calories: 520,
            protein: 25,
            carbs: 55,
            fats: 22,
            fiber: 3,
            sugar: 2,
            sodium: 800,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            portionGrams: 250,
            notes: "борошно 200g, фарш 150g",
            source: "search",
            imageURL: image
        )
        let draft = ProductDetailsMath.draft(from: entry)
        XCTAssertEqual(draft.name, "Пельмені")
        XCTAssertEqual(draft.calories, 520)
        XCTAssertEqual(draft.portionGrams, 250)
        XCTAssertEqual(draft.imageURL, image)
        XCTAssertEqual(draft.source, "search")
        XCTAssertEqual(draft.ingredients.map(\.name), ["борошно", "фарш"])
        XCTAssertEqual(draft.toFoodEntry().imageURL, image)
        XCTAssertFalse(entry.opensAsRecipe)
    }

    func testAILoggedDishOpensAsRecipeWithIngredients() {
        let entry = FoodLogProposal(
            name: "Борщ",
            mealType: .snacks,
            calories: 180,
            protein: 8,
            carbs: 22,
            fats: 6,
            source: "text",
            ingredientLines: ["буряк 150g", "капуста 80g"],
            recipeSteps: ["Нарізати овочі", "Варити 40 хвилин"],
            catalogKind: .recipe
        ).toFoodEntry()
        XCTAssertTrue(entry.opensAsRecipe)
        let recipe = entry.asRecipe()
        XCTAssertEqual(recipe.title, "Борщ")
        XCTAssertEqual(recipe.ingredients.map(\.name), ["буряк", "капуста"])
        XCTAssertEqual(recipe.steps, ["Нарізати овочі", "Варити 40 хвилин"])
        let draft = ProductDetailsMath.draft(from: entry)
        XCTAssertEqual(draft.catalogKind, .recipe)
        XCTAssertEqual(draft.ingredients.map(\.name), ["буряк", "капуста"])
        XCTAssertEqual(draft.recipeSteps.count, 2)
    }

    func testLegacyFoodSourceNeedsSemanticClassificationBeforeRecipeRouting() {
        let borscht = FoodEntry(
            id: UUID(),
            name: "Борщ",
            mealType: .snacks,
            calories: 60,
            protein: 3,
            carbs: 8,
            fats: 2,
            fiber: 0,
            sugar: 0,
            sodium: 0,
            date: Date(),
            portionGrams: 300,
            source: "text"
        )
        XCTAssertNil(borscht.resolvedFoodType)
        XCTAssertFalse(borscht.opensAsRecipe)
        var classifiedDish = borscht
        classifiedDish.foodType = .dish
        XCTAssertTrue(classifiedDish.opensAsRecipe)
        let drink = FoodEntry(
            id: UUID(),
            name: "Cola",
            mealType: .snacks,
            calories: 140,
            protein: 0,
            carbs: 36,
            fats: 0,
            fiber: 0,
            sugar: 36,
            sodium: 10,
            date: Date(),
            portionMilliliters: 330,
            source: "text"
        )
        XCTAssertFalse(drink.opensAsRecipe)
        let yogurt = FoodEntry(
            id: UUID(),
            name: "Yogurt",
            mealType: .breakfast,
            calories: 120,
            protein: 10,
            carbs: 8,
            fats: 4,
            fiber: 0,
            sugar: 8,
            sodium: 40,
            date: Date(),
            portionGrams: 150,
            source: "barcode",
            catalogKind: .product
        )
        XCTAssertFalse(yogurt.opensAsRecipe)
    }

    func testFoodProductMapsToProductDetailsDraft() {
        let product = FoodProduct(
            id: UUID(),
            externalId: "ai-1",
            name: "Пельмені з куркою",
            brand: nil,
            kind: .recipe,
            imageURL: URL(string: "https://example.com/recipe.jpg"),
            calories: 390,
            protein: 29,
            carbs: 48,
            fats: 9,
            fiber: 2,
            sugar: 4,
            sodium: 620,
            amount: 1,
            unit: "serving",
            source: .openAI,
            ingredients: ["курячий фарш 200g", "борошно 180g"],
            steps: ["Замісити тісто", "Зліпити пельмені", "Варити 8 хвилин"]
        )
        let draft = ProductDetailsMath.draft(
            from: product,
            imageData: nil,
            mealType: .lunch,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(draft.name, "Пельмені з куркою")
        XCTAssertEqual(draft.calories, 390)
        XCTAssertEqual(draft.fiber, 2)
        XCTAssertEqual(draft.sugar, 4)
        XCTAssertEqual(draft.sodium, 620)
        XCTAssertEqual(draft.source, "openai")
        XCTAssertEqual(draft.ingredients.count, 2)
        XCTAssertEqual(draft.recipeSteps, ["Замісити тісто", "Зліпити пельмені", "Варити 8 хвилин"])
        XCTAssertEqual(draft.imageURL?.absoluteString, "https://example.com/recipe.jpg")
        XCTAssertEqual(draft.catalogExternalId, "ai-1")
        XCTAssertEqual(draft.catalogKind, .recipe)
    }

    func testMealSuggestionMapsToProductDetailsDraft() {
        let option = MealSuggestionOption(
            title: "Грецький салат",
            summary: "Легкий обід",
            calories: 320,
            protein: 12,
            carbs: 18,
            fats: 22,
            cookTimeMinutes: 15,
            externalRecipeId: nil,
            ingredients: ["огірок 100g", "фета 50g"],
            steps: ["Нарізати овочі", "Додати фету"]
        )
        let draft = ProductDetailsMath.draft(from: option, mealType: .lunch, date: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(draft.name, "Грецький салат")
        XCTAssertEqual(draft.calories, 320)
        XCTAssertEqual(draft.protein, 12)
        XCTAssertEqual(draft.carbs, 18)
        XCTAssertEqual(draft.fats, 22)
        XCTAssertEqual(draft.source, "openai")
        XCTAssertEqual(draft.catalogKind, .recipe)
        XCTAssertEqual(draft.ingredients.map(\.name), ["огірок", "фета"])
        XCTAssertEqual(draft.recipeSteps, ["Нарізати овочі", "Додати фету"])
        XCTAssertEqual(draft.notes, "Легкий обід")
    }

    func testMealSuggestionWithSpoonacularIdUsesCatalogSource() {
        let option = MealSuggestionOption(
            title: "Salmon bowl",
            summary: "",
            calories: 480,
            protein: 38,
            carbs: 30,
            fats: 18,
            cookTimeMinutes: nil,
            externalRecipeId: "716429",
            ingredients: ["Salmon"]
        )
        let draft = ProductDetailsMath.draft(from: option, mealType: .dinner)
        XCTAssertEqual(draft.source, "spoonacular")
        XCTAssertEqual(draft.catalogExternalId, "716429")
        XCTAssertEqual(draft.catalogKind, .recipe)
    }

    func testMealSuggestionMergesMissingNutrition() {
        let option = MealSuggestionOption(
            title: "Oatmeal",
            summary: "",
            calories: 0,
            protein: 0,
            carbs: 0,
            fats: 0,
            cookTimeMinutes: nil,
            externalRecipeId: nil,
            ingredients: []
        )
        XCTAssertTrue(option.needsNutritionEnrichment)
        let product = FoodProduct(
            id: UUID(),
            externalId: "ai-oats",
            name: "Oatmeal",
            brand: nil,
            kind: .recipe,
            imageURL: URL(string: "https://example.com/oats.jpg"),
            calories: 250,
            protein: 8,
            carbs: 40,
            fats: 5,
            amount: 1,
            unit: "serving",
            ingredients: ["oats 50g"],
            steps: ["Boil water"]
        )
        let merged = option.merging(product)
        XCTAssertEqual(merged.calories, 250)
        XCTAssertEqual(merged.protein, 8)
        XCTAssertEqual(merged.carbs, 40)
        XCTAssertEqual(merged.fats, 5)
        XCTAssertEqual(merged.ingredients, ["oats 50g"])
        XCTAssertEqual(merged.steps, ["Boil water"])
        XCTAssertEqual(merged.externalRecipeId, "ai-oats")
        XCTAssertFalse(merged.needsNutritionEnrichment)
    }

    func testChatHistoryRecipeDecodesWithoutSteps() throws {
        let json = """
        {"mealType":"lunch","option":{"title":"Borscht","summary":"Soup","calories":180,"protein":8,"carbs":22,"fats":6,"ingredients":["beet"]}}
        """
        let message = ChatHistoryMessage(id: UUID(), role: "recipe", content: json, createdAt: Date())
        let item = ChatHistoryVisualCodec.chatItem(from: message)
        guard case .recipe(let option, let mealType)? = item?.kind else {
            return XCTFail("expected recipe card")
        }
        XCTAssertEqual(mealType, .lunch)
        XCTAssertEqual(option.title, "Borscht")
        XCTAssertEqual(option.calories, 180)
        XCTAssertEqual(option.ingredients, ["beet"])
        XCTAssertEqual(option.steps, [])
    }

    func testBarcodeProductMapsToProductDetailsDraft() {
        let product = BarcodeProduct(
            id: UUID(),
            barcode: "5449000000996",
            name: "Cola",
            brand: "Test",
            quantityLabel: "330 ml",
            servingSizeLabel: "330ml",
            imageURL: nil,
            caloriesPer100g: 42,
            proteinPer100g: 0,
            carbsPer100g: 10.6,
            fatsPer100g: 0,
            caloriesPerServing: 139,
            proteinPerServing: 0,
            carbsPerServing: 35,
            fatsPerServing: 0,
            source: .openFoodFacts
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let draft = ProductDetailsMath.draft(
            from: product,
            imageData: nil,
            mealType: .snacks,
            date: date
        )
        XCTAssertEqual(draft.name, "Cola")
        XCTAssertEqual(draft.servingLabel, "330ml")
        XCTAssertEqual(draft.calories, 42)
        XCTAssertEqual(draft.carbs, 10.6, accuracy: 0.01)
        XCTAssertEqual(draft.portionGrams, 100)
        XCTAssertEqual(draft.source, "barcode")
        XCTAssertEqual(draft.mealType, .snacks)
        XCTAssertEqual(draft.date, date)
        XCTAssertEqual(BarcodeNormalization.normalize("0 000000 000000"), "0000000000000")
        XCTAssertEqual(BarcodeNormalization.groupedDisplay("5449000000996"), "5 449000 000996")
        XCTAssertEqual(BarcodeNormalization.groupedDisplay("5449"), "5 449")
        XCTAssertEqual(BarcodeNormalization.groupedDisplay(""), "")
    }

    func testAppSettingsDecodesLegacyJSON() throws {
        let json = """
        {"healthSyncEnabled":true,"healthSyncWeight":false,"healthSyncWater":true,"healthSyncWorkouts":false}
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertTrue(settings.healthSyncEnabled)
        XCTAssertFalse(settings.healthSyncWeight)
        XCTAssertTrue(settings.healthSyncWater)
        XCTAssertFalse(settings.healthSyncWorkouts)
        XCTAssertTrue(settings.healthSyncFood)
        XCTAssertTrue(settings.healthSyncProfile)
        XCTAssertFalse(settings.healthAuthorizationRequested)
        XCTAssertFalse(settings.hasSeenAppRating)
        XCTAssertTrue(settings.usesMetric)
        XCTAssertEqual(settings.appearanceMode, .system)
        XCTAssertNil(settings.healthLastSyncedAt)
    }

    func testAppSettingsStoreRoundTrip() {
        let defaults = UserDefaults(suiteName: "bity.tests.settings.\(UUID().uuidString)")!
        let store = AppSettingsStore(defaults: defaults)
        var next = AppSettings.default
        next.healthSyncEnabled = true
        next.healthSyncFood = false
        next.hasSeenAppRating = true
        store.settings = next
        XCTAssertEqual(store.settings, next)
        XCTAssertTrue(store.settings.hasSeenAppRating)
    }

    func testAppRatingEventsIncludeSourceAndAction() {
        let shown = AnalyticsEvent.appRatingShown(source: "food_logged")
        XCTAssertEqual(shown.name, "app_rating_shown")
        XCTAssertEqual(shown.properties["source"] as? String, "food_logged")
        let rate = AnalyticsEvent.appRatingTapped(action: "rate")
        XCTAssertEqual(rate.name, "app_rating_tapped")
        XCTAssertEqual(rate.properties["action"] as? String, "rate")
        let later = AnalyticsEvent.appRatingTapped(action: "later")
        XCTAssertEqual(later.name, "app_rating_tapped")
        XCTAssertEqual(later.properties["action"] as? String, "later")
        XCTAssertEqual(AnalyticsScreen.appRating.rawValue, "app_rating")
    }

    func testCompletedUserActionsTriggerAppRatingPrompt() {
        XCTAssertEqual(
            AnalyticsEvent.foodLogged(method: "search", mealType: "lunch", calories: 200).appRatingTriggerSource,
            "food_logged"
        )
        XCTAssertEqual(
            AnalyticsEvent.foodSearchPerformed(queryLength: 3, resultCount: 1).appRatingTriggerSource,
            "food_search"
        )
        XCTAssertEqual(
            AnalyticsEvent.waterLogged(amountMilliliters: 250).appRatingTriggerSource,
            "water_logged"
        )
        XCTAssertEqual(
            AnalyticsEvent.mealAICompleted(mealType: "lunch", success: true).appRatingTriggerSource,
            "meal_ai"
        )
        XCTAssertNil(AnalyticsEvent.mealAICompleted(mealType: "lunch", success: false).appRatingTriggerSource)
        XCTAssertNil(AnalyticsEvent.foodLogStarted(method: "search", source: "home", mealType: "lunch").appRatingTriggerSource)
        XCTAssertNil(AnalyticsEvent.foodLogFailed(method: "search").appRatingTriggerSource)
    }

    func testDateRangeIsHalfOpenDay() {
        let date = testDate(hour: 15)
        let range = DateRangeHelper.dayInterval(for: date)
        XCTAssertEqual(range.start, Calendar.current.startOfDay(for: date))
        XCTAssertEqual(range.end, Calendar.current.date(byAdding: .day, value: 1, to: range.start))
        XCTAssertGreaterThanOrEqual(date, range.start)
        XCTAssertLessThan(date, range.end)
    }

    func testRecipeIngredientSwapReplacesAndUpdatesMacros() {
        let recipe = Recipe(
            id: UUID(),
            externalId: "r1",
            title: "Bowl",
            summary: nil,
            imageURL: nil,
            readyInMinutes: 20,
            servings: 1,
            calories: 500,
            protein: 20,
            carbs: 60,
            fats: 15,
            ingredients: [
                RecipeIngredient(id: "1", name: "White rice", amount: 100, unit: "g", originalText: "100 g White rice")
            ],
            steps: ["Cook"],
            sourceName: "AI"
        )
        let updated = ApplyRecipeIngredientSwapUseCase.execute(
            recipe: recipe,
            proposal: RecipeIngredientSwapProposal(
                recipeExternalId: "r1",
                originalName: "rice",
                originalAmount: 100,
                originalUnit: "g",
                replacementName: "Quinoa",
                replacementAmount: 90,
                replacementUnit: "g",
                replacementCalories: nil,
                replacementProtein: nil,
                replacementCarbs: nil,
                replacementFats: nil,
                updatedRecipeCalories: 480,
                updatedRecipeProtein: 24,
                updatedRecipeCarbs: 50,
                updatedRecipeFats: 14,
                reason: "More protein"
            )
        )
        XCTAssertEqual(updated.ingredients[0].name, "Quinoa")
        XCTAssertEqual(updated.ingredients[0].amount, 90)
        XCTAssertEqual(updated.calories, 480)
        XCTAssertEqual(updated.protein, 24)
    }

    func testRecipeIngredientSwapAppendsWhenNoMatch() {
        let recipe = Recipe(
            id: UUID(),
            externalId: nil,
            title: "Soup",
            summary: nil,
            imageURL: nil,
            readyInMinutes: nil,
            servings: nil,
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            ingredients: [
                RecipeIngredient(id: "1", name: "Carrot", amount: 1, unit: nil, originalText: "Carrot")
            ],
            steps: [],
            sourceName: nil
        )
        let updated = ApplyRecipeIngredientSwapUseCase.execute(
            recipe: recipe,
            proposal: RecipeIngredientSwapProposal(
                recipeExternalId: nil,
                originalName: "Chicken",
                originalAmount: nil,
                originalUnit: nil,
                replacementName: "Tofu",
                replacementAmount: nil,
                replacementUnit: nil,
                replacementCalories: nil,
                replacementProtein: nil,
                replacementCarbs: nil,
                replacementFats: nil,
                updatedRecipeCalories: nil,
                updatedRecipeProtein: nil,
                updatedRecipeCarbs: nil,
                updatedRecipeFats: nil,
                reason: nil
            )
        )
        XCTAssertEqual(updated.ingredients.count, 2)
        XCTAssertEqual(updated.ingredients.last?.name, "Tofu")
    }

    func testParseAIAssistantActions() {
        let parser = ParseAIAssistantActionsUseCase()
        let food = AIAssistantToolCall(
            id: "1",
            name: "propose_food_log",
            arguments: [
                "name": AnyCodable("Yogurt"),
                "mealType": AnyCodable("breakfast"),
                "calories": AnyCodable("180"),
                "protein": AnyCodable(12),
            ]
        )
        let water = AIAssistantToolCall(
            id: "2",
            name: "propose_water_log",
            arguments: ["amountMilliliters": AnyCodable(250)]
        )
        let unknown = AIAssistantToolCall(id: "3", name: "do_hack", arguments: [:])
        let emptyName = AIAssistantToolCall(
            id: "4",
            name: "propose_food_log",
            arguments: ["name": AnyCodable("")]
        )
        let actions = parser.execute(toolCalls: [food, water, unknown, emptyName])
        XCTAssertEqual(actions.count, 2)
        if case .logFood(let proposal) = actions[0] {
            XCTAssertEqual(proposal.name, "Yogurt")
            XCTAssertEqual(proposal.mealType, .breakfast)
            XCTAssertEqual(proposal.calories, 180)
            XCTAssertEqual(proposal.protein, 12)
        } else {
            XCTFail("expected food log")
        }
        if case .logWater(let proposal) = actions[1] {
            XCTAssertEqual(proposal.amountMilliliters, 250)
        } else {
            XCTFail("expected water log")
        }
    }

    func testParseFoodLogKeepsRecipePayload() {
        let parser = ParseAIAssistantActionsUseCase()
        let food = AIAssistantToolCall(
            id: "1",
            name: "propose_food_log",
            arguments: [
                "name": AnyCodable("Борщ"),
                "mealType": AnyCodable("snacks"),
                "calories": AnyCodable(180),
                "protein": AnyCodable(8),
                "carbs": AnyCodable(22),
                "fats": AnyCodable(6),
                "kind": AnyCodable("recipe"),
                "steps": AnyCodable(["Нарізати овочі", "Варити"]),
                "ingredients": AnyCodable([
                    ["name": "буряк", "grams": 150],
                    ["name": "капуста", "grams": 80]
                ])
            ]
        )
        let actions = parser.execute(toolCalls: [food])
        guard case .logFood(let proposal) = actions.first else {
            return XCTFail("expected food log")
        }
        XCTAssertEqual(proposal.catalogKind, .recipe)
        XCTAssertEqual(proposal.recipeSteps, ["Нарізати овочі", "Варити"])
        XCTAssertEqual(proposal.ingredientLines.count, 2)
        XCTAssertTrue(proposal.ingredientLines[0].contains("буряк"))
        let entry = proposal.toFoodEntry()
        XCTAssertTrue(entry.opensAsRecipe)
        XCTAssertEqual(entry.catalogKind, .recipe)
    }

    func testMealSuggestionLogKeepsRecipePayload() {
        let option = MealSuggestionOption(
            title: "Борщ",
            summary: "Класичний суп",
            calories: 180,
            protein: 8,
            carbs: 22,
            fats: 6,
            ingredients: ["буряк 150g", "капуста 80g"],
            steps: ["Нарізати", "Варити"]
        )
        let entry = option.asFoodLogProposal(mealType: .snacks).toFoodEntry()
        XCTAssertTrue(entry.opensAsRecipe)
        XCTAssertEqual(entry.catalogKind, .recipe)
        XCTAssertEqual(entry.ingredientLines, ["буряк 150g", "капуста 80g"])
        XCTAssertEqual(entry.recipeSteps, ["Нарізати", "Варити"])
    }

    func testEditMealAddMessageDoesNotScanExistingItems() {
        let borscht = UUID()
        let items = [editMealItem(id: borscht, name: "Борщ")]
        XCTAssertTrue(EditMealAssistantScan.targetItemIDs(for: "додай плов", items: items).isEmpty)
        XCTAssertTrue(EditMealAssistantScan.targetItemIDs(for: "Add pilaf please", items: items).isEmpty)
        XCTAssertTrue(EditMealAssistantScan.targetItemIDs(for: "", items: items).isEmpty)
    }

    func testEditMealReplaceMessageScansNamedItem() {
        let borscht = UUID()
        let yogurt = UUID()
        let items = [
            editMealItem(id: borscht, name: "Борщ"),
            editMealItem(id: yogurt, name: "Йогурт")
        ]
        XCTAssertEqual(EditMealAssistantScan.targetItemIDs(for: "заміни борщ на салат", items: items), [borscht])
        XCTAssertEqual(EditMealAssistantScan.targetItemIDs(for: "додай плов замість борщу", items: items), [borscht])
        XCTAssertEqual(EditMealAssistantScan.targetItemIDs(for: "Зміни йогурт на 1%", items: items), [yogurt])
    }

    func testEditMealReplaceWithoutNameScansAllItems() {
        let first = UUID()
        let second = UUID()
        let items = [
            editMealItem(id: first, name: "Борщ"),
            editMealItem(id: second, name: "Плов")
        ]
        XCTAssertEqual(EditMealAssistantScan.targetItemIDs(for: "заміни на салат", items: items), [first, second])
    }

    func testParseFoodLogKeepsImageURL() {
        let parser = ParseAIAssistantActionsUseCase()
        let food = AIAssistantToolCall(
            id: "1",
            name: "propose_food_log",
            arguments: [
                "name": AnyCodable("Плов"),
                "mealType": AnyCodable("snacks"),
                "calories": AnyCodable(520),
                "imageURL": AnyCodable("https://img.spoonacular.com/recipes/plov-636x393.jpg")
            ]
        )
        let actions = parser.execute(toolCalls: [food])
        guard case .logFood(let proposal) = actions.first else {
            return XCTFail("expected food log")
        }
        XCTAssertEqual(proposal.imageURL?.absoluteString, "https://img.spoonacular.com/recipes/plov-636x393.jpg")
        XCTAssertEqual(proposal.toFoodEntry().imageURL?.absoluteString, "https://img.spoonacular.com/recipes/plov-636x393.jpg")
    }

    private func editMealItem(id: UUID, name: String) -> EditMealItem {
        EditMealItem(
            id: id,
            name: name,
            detailText: "300г · 180 ккал",
            portionText: "300г",
            imageURL: nil,
            imageData: nil
        )
    }

    func testParseMealSuggestionsUsesOptionMealType() throws {
        let json = """
        {
          "id": "1",
          "name": "propose_meal_suggestions",
          "arguments": {
            "mealType": "lunch",
            "remainingCaloriesTarget": 900,
            "options": [
              {
                "title": "Chicken bowl",
                "summary": "Lunch",
                "mealType": "lunch",
                "calories": 400,
                "protein": 35,
                "carbs": 30,
                "fats": 12
              },
              {
                "title": "Yogurt",
                "summary": "Snack",
                "mealType": "snacks",
                "calories": 150,
                "protein": 12,
                "carbs": 16,
                "fats": 4
              },
              {
                "title": "Salmon",
                "summary": "Dinner",
                "mealType": "dinner",
                "calories": 350,
                "protein": 32,
                "carbs": 20,
                "fats": 14
              }
            ]
          }
        }
        """
        let call = try JSONDecoder().decode(AIAssistantToolCall.self, from: Data(json.utf8))
        let actions = ParseAIAssistantActionsUseCase().execute(toolCalls: [call])
        guard case .mealSuggestions(let proposal) = actions.first else {
            return XCTFail("expected meal suggestions")
        }
        XCTAssertEqual(proposal.options.map(\.mealType), [.lunch, .snacks, .dinner])
        XCTAssertEqual(proposal.options.map(\.title), ["Chicken bowl", "Yogurt", "Salmon"])
    }

    func testParseSwapReadsImageURLs() throws {
        let json = """
        {
          "id": "1",
          "name": "propose_food_swap",
          "arguments": {
            "original": {
              "name": "Rice",
              "calories": 200,
              "imageURL": "https://example.com/rice.jpg"
            },
            "alternative": {
              "name": "Cauliflower rice",
              "calories": 50,
              "image": "https://example.com/cauli.jpg"
            },
            "savingsKcal": 150
          }
        }
        """
        let call = try JSONDecoder().decode(AIAssistantToolCall.self, from: Data(json.utf8))
        let actions = ParseAIAssistantActionsUseCase().execute(toolCalls: [call])
        guard case .swapFood(let proposal) = actions.first else {
            return XCTFail("expected swap")
        }
        XCTAssertEqual(proposal.original.imageURL?.absoluteString, "https://example.com/rice.jpg")
        XCTAssertEqual(proposal.alternative.imageURL?.absoluteString, "https://example.com/cauli.jpg")
    }

    func testParseWaterRejectsZero() {
        let actions = ParseAIAssistantActionsUseCase().execute(
            toolCalls: [
                AIAssistantToolCall(
                    id: "1",
                    name: "propose_water_log",
                    arguments: ["amountMilliliters": AnyCodable(0)]
                )
            ]
        )
        XCTAssertTrue(actions.isEmpty)
    }

    func testUserPreferenceProfileGroupsKinds() {
        let profile = UserPreferenceProfile(preferences: [
            UserPreference(id: UUID(), kind: .allergy, value: "Peanuts", note: nil, createdAt: Date()),
            UserPreference(id: UUID(), kind: .dislike, value: "Olives", note: nil, createdAt: Date()),
            UserPreference(id: UUID(), kind: .diet, value: "Keto", note: nil, createdAt: Date()),
            UserPreference(id: UUID(), kind: .diet, value: "Vegan", note: nil, createdAt: Date()),
        ])
        XCTAssertEqual(profile.allergies, ["Peanuts"])
        XCTAssertEqual(profile.dislikes, ["Olives"])
        XCTAssertEqual(profile.diet, "Vegan")
    }

    func testEmptyPreferenceRejected() {
        let harness = TestHarness()
        XCTAssertThrowsError(
            try SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences)
                .execute(kind: .allergy, value: "   ")
        )
    }

    func testActivityMultipliers() {
        XCTAssertEqual(ActivityLevel.sedentary.tdeeMultiplier, 1.2)
        XCTAssertEqual(ActivityLevel.veryActive.tdeeMultiplier, 1.9)
    }

    func testWeightConversionRoundTripsThroughPounds() {
        let kilograms = 68.5
        let pounds = WeightConversion.pounds(fromKilograms: kilograms)
        XCTAssertEqual(pounds, kilograms * 2.204_622_621_8, accuracy: 0.000_000_1)
        XCTAssertEqual(WeightConversion.kilograms(fromPounds: pounds), kilograms, accuracy: 0.000_000_1)
    }

    func testProgressBarScaleKeepsTargetBelowCeiling() {
        XCTAssertEqual(ProgressChartMath.niceCeiling(2150), 2500)
        XCTAssertEqual(ProgressChartMath.niceCeiling(1500), 2000)
        let scale = ProgressChartScale.bars(values: [1800, 2100], target: 2150)
        XCTAssertEqual(scale.min, 0)
        XCTAssertEqual(scale.max, 2500)
        XCTAssertLessThan(2150, scale.max)
        let plot = CGRect(x: 0, y: 0, width: 300, height: 150)
        let targetY = scale.y(for: 2150, in: plot)
        XCTAssertGreaterThan(targetY, plot.minY)
        XCTAssertLessThan(targetY, plot.maxY)
    }

    func testProgressLineScaleUsesPlottedRangeNotZero() {
        let scale = ProgressChartMath.lineScale(values: [78.5, 82.0, 80.0])
        XCTAssertGreaterThan(scale.min, 0)
        XCTAssertLessThan(scale.min, 78.5)
        XCTAssertGreaterThan(scale.max, 82.0)
    }

    func testProgressPhotoPreviewsTakeThreeNewestDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day: (Int) -> Date = { offset in
            calendar.date(from: DateComponents(year: 2026, month: 10, day: offset))!
        }
        let photos = [
            ProgressPhoto(id: UUID(), fileName: "a", kind: .progress, pose: .front, note: nil, date: day(1), fileURL: nil),
            ProgressPhoto(id: UUID(), fileName: "b", kind: .progress, pose: .side, note: nil, date: day(1), fileURL: nil),
            ProgressPhoto(id: UUID(), fileName: "c", kind: .progress, pose: .front, note: nil, date: day(15), fileURL: nil),
            ProgressPhoto(id: UUID(), fileName: "d", kind: .progress, pose: .front, note: nil, date: day(22), fileURL: nil),
            ProgressPhoto(id: UUID(), fileName: "e", kind: .progress, pose: .front, note: nil, date: day(8), fileURL: nil)
        ]
        let previews = ProgressChartMath.photoPreviews(photos, calendar: calendar)
        XCTAssertEqual(previews.map(\.photo.fileName), ["d", "c", "e"])
    }

    func testBrowseSectionsKeepsRemoteRecipesWithPhotos() async {
        final class RemoteSections: RecipeSectionsFetching {
            func fetchSections(locale _: String) async throws -> [RecipeBrowseSection] {
                [
                    RecipeBrowseSection(
                        id: .healthyBreakfast,
                        recipes: [
                            Recipe(
                                id: UUID(),
                                externalId: "1",
                                title: "Вівсянка",
                                summary: nil,
                                imageURL: URL(string: "https://img.spoonacular.com/recipes/1-636x393.jpg"),
                                readyInMinutes: 10,
                                servings: 1,
                                calories: 320,
                                protein: 12,
                                carbs: 48,
                                fats: 8,
                                ingredients: [],
                                steps: [],
                                sourceName: nil,
                                origin: .spoonacular
                            )
                        ]
                    )
                ]
            }

            func fetchSectionPage(
                id _: RecipeBrowseSectionKind,
                locale _: String,
                offset _: Int,
                limit _: Int
            ) async throws -> RecipeSectionPage {
                RecipeSectionPage(recipes: [], nextOffset: 0, hasMore: false)
            }
        }

        let useCase = FetchRecipeBrowseSectionsUseCase(service: RemoteSections())
        let sections = await useCase.execute()
        XCTAssertEqual(sections.map(\.id), [.healthyBreakfast])
        XCTAssertEqual(sections.first?.recipes.first?.title, "Вівсянка")
        XCTAssertEqual(sections.first?.recipes.first?.hasPhoto, true)
    }

    func testBrowseSectionsStayEmptyWhenRemoteIsEmpty() async {
        final class EmptySections: RecipeSectionsFetching {
            func fetchSections(locale _: String) async throws -> [RecipeBrowseSection] { [] }

            func fetchSectionPage(
                id _: RecipeBrowseSectionKind,
                locale _: String,
                offset _: Int,
                limit _: Int
            ) async throws -> RecipeSectionPage {
                RecipeSectionPage(recipes: [], nextOffset: 0, hasMore: false)
            }
        }

        let useCase = FetchRecipeBrowseSectionsUseCase(service: EmptySections())
        let sections = await useCase.execute()
        XCTAssertTrue(sections.isEmpty)
    }

    func testRecipeDetailSubtitleUsesServingsAndGrams() {
        let recipe = Recipe(
            id: UUID(),
            externalId: "1",
            title: "Turkey pie",
            summary: nil,
            imageURL: nil,
            readyInMinutes: 45,
            servings: 1,
            calories: 728,
            protein: nil,
            carbs: nil,
            fats: nil,
            ingredients: [],
            steps: [],
            sourceName: nil,
            origin: .spoonacular,
            weightGrams: 480
        )
        XCTAssertEqual(
            ProductDetailsMath.recipeDetailSubtitle(for: recipe),
            "\(L10n.format("recipes.details.serving", 1)) · \(ProductDetailsMath.formatGrams(480))"
        )
        let servingsOnly = Recipe(
            id: UUID(),
            externalId: "2",
            title: "Soup",
            summary: nil,
            imageURL: nil,
            readyInMinutes: nil,
            servings: nil,
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            ingredients: [],
            steps: [],
            sourceName: nil
        )
        XCTAssertEqual(
            ProductDetailsMath.recipeDetailSubtitle(for: servingsOnly),
            L10n.format("recipes.details.serving", 1)
        )
    }

    func testRecipeDiaryDraftPreservesKnownPortionAndScalesWithServings() {
        let recipe = Recipe(
            id: UUID(),
            externalId: "3",
            title: "Oats",
            summary: nil,
            imageURL: nil,
            readyInMinutes: nil,
            servings: 4,
            calories: 200,
            protein: nil,
            carbs: nil,
            fats: nil,
            ingredients: [],
            steps: [],
            sourceName: nil,
            weightGrams: 100
        )
        var draft = ProductDetailsMath.fillingDefaultPortion(ProductDetailsMath.draft(from: recipe))
        draft.servings = 1
        XCTAssertEqual(draft.portionGrams, 100)
        XCTAssertEqual(ProductDetailsMath.loggedPortionText(for: draft), ProductDetailsMath.formatGrams(100))
        draft.servings = 2
        XCTAssertEqual(ProductDetailsMath.loggedPortionText(for: draft), ProductDetailsMath.formatGrams(200))
        let scaledServings = ProductDetailsMath.applyingLoggedPortion(draft, value: 400, isMilliliters: false)
        XCTAssertEqual(scaledServings.servings, 4)
        XCTAssertEqual(ProductDetailsMath.loggedPortionText(for: scaledServings), ProductDetailsMath.formatGrams(400))
        let parsed = ProductDetailsMath.parsePortion("431")
        XCTAssertEqual(parsed?.value, 431)
        XCTAssertEqual(parsed?.isMilliliters, false)
        XCTAssertNil(ProductDetailsMath.parsePortion("431г142442"))
        var millilitersZero = ProductDetailsMath.draft(from: recipe)
        millilitersZero.portionGrams = nil
        millilitersZero.portionMilliliters = 0
        let filledFromZero = ProductDetailsMath.fillingDefaultPortion(millilitersZero)
        XCTAssertNil(filledFromZero.portionGrams)
        XCTAssertNil(filledFromZero.portionMilliliters)
    }

    func testSavingSamePantryProductFromSearchMergesIntoOneItem() throws {
        let repository = MemoryPantryRepository()
        let useCase = SavePantryItemUseCase(pantryRepository: repository)
        XCTAssertTrue(PantryItem.namesMatch("Молоко", "молоко"))
        let first = pantryItem(name: "Молоко", amount: 100, unit: "g")
        let second = pantryItem(name: "молоко", amount: 100, unit: "g")
        try useCase.execute(first)
        try useCase.execute(second)
        XCTAssertEqual(repository.items.count, 1)
        XCTAssertEqual(repository.items[0].id, first.id)
        XCTAssertEqual(repository.items[0].amount, 200)
        XCTAssertEqual(repository.items[0].quantityText, "200 g")
    }

    func testEditingPantryItemDoesNotMergeIntoAnotherProduct() throws {
        let repository = MemoryPantryRepository()
        let useCase = SavePantryItemUseCase(pantryRepository: repository)
        let milk = pantryItem(name: "Milk", amount: 100, unit: "g")
        var yogurt = pantryItem(name: "Yogurt", amount: 150, unit: "g")
        try useCase.execute(milk)
        try useCase.execute(yogurt)
        yogurt.name = "Milk"
        yogurt.quantityText = "150 g"
        try useCase.execute(yogurt)
        XCTAssertEqual(repository.items.count, 2)
        XCTAssertEqual(Set(repository.items.map(\.id)), Set([milk.id, yogurt.id]))
    }

    func testFridgeScanSkipsProductAlreadyInPantry() {
        let tomato = URL(string: "https://img.spoonacular.com/ingredients_100x100/tomato.jpg")
        let existing = pantryItem(name: "Помідор", amount: 100, unit: "g")
        var scanned = pantryItem(name: "помідори", amount: 80, unit: "g")
        XCTAssertTrue(PantryItem.namesMatch("помідор", "Помідори"))
        XCTAssertTrue(PantryItem.namesMatch("tomato", "Tomatoes"))
        XCTAssertEqual(PantryItem.excludingExisting([scanned], in: [existing]).count, 0)
        scanned.name = "Roma tomato"
        scanned.imageURL = tomato
        var stored = existing
        stored.imageURL = tomato
        XCTAssertEqual(PantryItem.excludingExisting([scanned], in: [stored]).count, 0)
        let cucumber = pantryItem(name: "Огірок", amount: 1, unit: "pcs")
        XCTAssertEqual(PantryItem.excludingExisting([scanned, cucumber], in: [stored]).map(\.name), ["Огірок"])
    }

    func testSavingFridgeScanWithSamePhotoMergesIntoExistingItem() throws {
        let repository = MemoryPantryRepository()
        let useCase = SavePantryItemUseCase(pantryRepository: repository)
        let photo = URL(string: "https://img.spoonacular.com/ingredients_250x250/tomato.jpg")
        var first = pantryItem(name: "Tomato", amount: 100, unit: "g")
        first.imageURL = URL(string: "https://img.spoonacular.com/ingredients_100x100/tomato.jpg")
        var second = pantryItem(name: "помідор", amount: 100, unit: "g")
        second.imageURL = photo
        try useCase.execute(first)
        try useCase.execute(second)
        XCTAssertEqual(repository.items.count, 1)
        XCTAssertEqual(repository.items[0].id, first.id)
    }

    private func pantryItem(
        name: String,
        amount: Double?,
        unit: String?,
        id: UUID = UUID()
    ) -> PantryItem {
        let now = Date()
        let quantity: String
        if let amount, let unit {
            quantity = PantryItem.amountText(amount, unit: unit)
        } else {
            quantity = ""
        }
        return PantryItem(
            id: id,
            name: name,
            quantityText: quantity,
            amount: amount,
            unit: unit,
            useBy: nil,
            imageURL: nil,
            imageData: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}

private final class MemoryPantryRepository: PantryRepositoryProtocol {
    var items: [PantryItem] = []

    func fetchAll() throws -> [PantryItem] {
        items.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ item: PantryItem) throws {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func delete(ids: [UUID]) throws {
        items.removeAll { ids.contains($0.id) }
    }
}
