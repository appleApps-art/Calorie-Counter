import XCTest
@testable import Calorie_Counter

@MainActor
final class HealthSyncTests: XCTestCase {
    func testImportsWeightWaterWorkoutAndFood() async throws {
        let harness = TestHarness()
        let weightID = UUID()
        let waterID = UUID()
        let workoutID = UUID()
        let foodID = UUID()
        harness.health.weightChanges = HealthAnchoredChange(
            added: [HealthQuantitySample(id: weightID, value: 74.2, date: testDate(hour: 8))],
            deletedIDs: []
        )
        harness.health.waterChanges = HealthAnchoredChange(
            added: [HealthQuantitySample(id: waterID, value: 350, date: testDate(hour: 9))],
            deletedIDs: []
        )
        harness.health.workoutChanges = HealthAnchoredChange(
            added: [
                HealthWorkoutSample(
                    id: workoutID,
                    name: "Running",
                    durationMinutes: 32,
                    caloriesBurned: 310,
                    date: testDate(hour: 7)
                )
            ],
            deletedIDs: []
        )
        harness.health.nutritionChanges = HealthAnchoredChange(
            added: [
                HealthNutritionSample(
                    id: foodID,
                    date: testDate(hour: 8),
                    calories: 520,
                    protein: 28,
                    carbs: 45,
                    fats: 18,
                    fiber: 6,
                    sugar: 8,
                    sodium: 640
                )
            ],
            deletedIDs: []
        )

        try await harness.syncUseCase().execute()

        let weights = try harness.weight.fetchEntries()
        XCTAssertEqual(weights.count, 1)
        XCTAssertEqual(weights[0].weightKilograms, 74.2)
        XCTAssertEqual(weights[0].source, HealthSyncSource.healthKit)
        XCTAssertEqual(weights[0].healthSampleID, weightID.uuidString)

        let waters = try harness.water.fetchEntries(for: Date())
        XCTAssertEqual(waters.count, 1)
        XCTAssertEqual(waters[0].amountMilliliters, 350)

        let workouts = try harness.workout.fetchEntries()
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts[0].caloriesBurned, 310)

        let foods = try harness.food.fetchEntries(for: Date())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods[0].calories, 520)
        XCTAssertEqual(foods[0].protein, 28)
        XCTAssertEqual(foods[0].mealType, .breakfast)
        XCTAssertEqual(foods[0].source, HealthSyncSource.healthKit)
        XCTAssertTrue(foods[0].isEaten)
    }

    func testDoesNotDuplicateSameHealthSampleOnSecondSync() async throws {
        let harness = TestHarness()
        let sampleID = UUID()
        harness.health.weightChanges = HealthAnchoredChange(
            added: [HealthQuantitySample(id: sampleID, value: 80, date: Date())],
            deletedIDs: []
        )
        let useCase = harness.syncUseCase()
        try await useCase.execute()
        try await useCase.execute()
        XCTAssertEqual(try harness.weight.fetchEntries().count, 1)
    }

    func testDuplicatesManualWeightWhenHealthHasSameValue() async throws {
        let harness = TestHarness()
        try harness.weight.save(
            WeightEntry(id: UUID(), weightKilograms: 80, date: Date(), source: "manual")
        )
        harness.health.weightChanges = HealthAnchoredChange(
            added: [HealthQuantitySample(id: UUID(), value: 80, date: Date())],
            deletedIDs: []
        )
        try await harness.syncUseCase().execute()
        XCTAssertEqual(try harness.weight.fetchEntries().count, 2)
    }

    func testSkipsZeroWaterAndZeroCalorieFood() async throws {
        let harness = TestHarness()
        harness.health.waterChanges = HealthAnchoredChange(
            added: [HealthQuantitySample(id: UUID(), value: 0, date: Date())],
            deletedIDs: []
        )
        harness.health.nutritionChanges = HealthAnchoredChange(
            added: [
                HealthNutritionSample(
                    id: UUID(),
                    date: Date(),
                    calories: 0,
                    protein: 10,
                    carbs: 10,
                    fats: 1,
                    fiber: 0,
                    sugar: 0,
                    sodium: 0
                )
            ],
            deletedIDs: []
        )
        try await harness.syncUseCase().execute()
        XCTAssertTrue(try harness.water.fetchEntries(for: Date()).isEmpty)
        XCTAssertTrue(try harness.food.fetchEntries(for: Date()).isEmpty)
    }

    func testImportsZeroCalorieWorkout() async throws {
        let harness = TestHarness()
        harness.health.workoutChanges = HealthAnchoredChange(
            added: [
                HealthWorkoutSample(
                    id: UUID(),
                    name: "Yoga",
                    durationMinutes: 20,
                    caloriesBurned: 0,
                    date: Date()
                )
            ],
            deletedIDs: []
        )
        try await harness.syncUseCase().execute()
        XCTAssertEqual(try harness.workout.fetchEntries().count, 1)
    }

    func testDeletesLocalEntriesWhenHealthDeletesSamples() async throws {
        let harness = TestHarness()
        let sampleID = UUID()
        try harness.water.save(
            WaterEntry(
                id: UUID(),
                amountMilliliters: 250,
                date: Date(),
                source: HealthSyncSource.healthKit,
                healthSampleID: sampleID.uuidString
            )
        )
        harness.health.waterChanges = HealthAnchoredChange(added: [], deletedIDs: [sampleID])
        try await harness.syncUseCase().execute()
        XCTAssertTrue(try harness.water.fetchEntries(for: Date()).isEmpty)
    }

    func testMealTypesByHour() async throws {
        let harness = TestHarness()
        let samples = [
            (4, MealType.snacks),
            (5, MealType.breakfast),
            (10, MealType.breakfast),
            (11, MealType.lunch),
            (15, MealType.lunch),
            (16, MealType.dinner),
            (21, MealType.dinner),
            (22, MealType.snacks),
        ]
        harness.health.nutritionChanges = HealthAnchoredChange(
            added: samples.map { hour, _ in
                HealthNutritionSample(
                    id: UUID(),
                    date: testDate(hour: hour),
                    calories: 100,
                    protein: 1,
                    carbs: 1,
                    fats: 1,
                    fiber: 0,
                    sugar: 0,
                    sodium: 0
                )
            },
            deletedIDs: []
        )
        try await harness.syncUseCase().execute()
        let foods = try harness.food.fetchEntries(for: Date()).sorted { $0.date < $1.date }
        XCTAssertEqual(foods.map(\.mealType), samples.map(\.1))
    }

    func testProfileFillsOnlyEmptyFieldsButAlwaysUpdatesWeight() async throws {
        let harness = TestHarness()
        var existing = try harness.profile.fetchProfile()
        existing.sex = .female
        existing.age = 31
        existing.heightCm = 168
        existing.weightKg = 90
        try harness.profile.save(existing)

        harness.health.profileSnapshot = HealthProfileSnapshot(
            sex: .male,
            age: 40,
            heightCm: 180,
            weightKg: 74
        )
        try await harness.syncUseCase().execute()

        let updated = try harness.profile.fetchProfile()
        XCTAssertEqual(updated.sex, .female)
        XCTAssertEqual(updated.age, 31)
        XCTAssertEqual(updated.heightCm, 168)
        XCTAssertEqual(updated.weightKg, 74)
    }

    func testDisabledSyncDoesNothing() async throws {
        let harness = TestHarness()
        harness.settings.settings.healthSyncEnabled = false
        harness.health.weightChanges = HealthAnchoredChange(
            added: [HealthQuantitySample(id: UUID(), value: 70, date: Date())],
            deletedIDs: []
        )
        try await harness.syncUseCase().execute()
        XCTAssertTrue(try harness.weight.fetchEntries().isEmpty)
    }

    func testPerTypeFlags() async throws {
        let harness = TestHarness()
        harness.settings.settings.healthSyncWeight = false
        harness.settings.settings.healthSyncWater = false
        harness.settings.settings.healthSyncWorkouts = true
        harness.settings.settings.healthSyncFood = false
        harness.settings.settings.healthSyncProfile = false
        harness.health.weightChanges = HealthAnchoredChange(
            added: [HealthQuantitySample(id: UUID(), value: 70, date: Date())],
            deletedIDs: []
        )
        harness.health.workoutChanges = HealthAnchoredChange(
            added: [
                HealthWorkoutSample(
                    id: UUID(),
                    name: "Walk",
                    durationMinutes: 10,
                    caloriesBurned: 40,
                    date: Date()
                )
            ],
            deletedIDs: []
        )
        try await harness.syncUseCase().execute()
        XCTAssertTrue(try harness.weight.fetchEntries().isEmpty)
        XCTAssertEqual(try harness.workout.fetchEntries().count, 1)
    }

    func testUserFoodWritesToHealthImportedFoodDoesNot() async throws {
        let harness = TestHarness()
        _ = try harness.logFood().execute(harness.foodEntry(source: "photo", isEaten: true))
        await waitUntil { !harness.health.savedFoods.isEmpty }
        XCTAssertEqual(harness.health.savedFoods.count, 1)

        _ = try harness.logFood().execute(
            harness.foodEntry(name: "Apple Health", source: HealthSyncSource.healthKit)
        )
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(harness.health.savedFoods.count, 1)
    }

    func testUneatenFoodDoesNotWriteToHealthUntilMarkedEaten() async throws {
        let harness = TestHarness()
        var entry = try harness.logFood().execute(harness.foodEntry(source: "photo", isEaten: false))
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertTrue(harness.health.savedFoods.isEmpty)

        entry.isEaten = true
        try UpdateFoodEntryUseCase(
            foodEntryRepository: harness.food,
            healthSync: harness.health,
            appSettingsStore: harness.settings
        ).execute(entry)
        await waitUntil { !harness.health.savedFoods.isEmpty }
        XCTAssertEqual(harness.health.savedFoods.count, 1)
    }

    func testUserWaterWeightWorkoutWriteToHealth() async throws {
        let harness = TestHarness()
        _ = try harness.logWater().execute(amountMilliliters: 200)
        _ = try harness.logWeight().execute(weightKilograms: 81.4)
        _ = try harness.logWorkout().execute(name: "Running", durationMinutes: 25, caloriesBurned: 220)
        await waitUntil {
            harness.health.savedWaters.count == 1
                && harness.health.savedWeights.count == 1
                && harness.health.savedWorkouts.count == 1
        }
        XCTAssertEqual(harness.health.savedWaters.first?.0, 200)
        XCTAssertEqual(harness.health.savedWeights.first?.0, 81.4)
        XCTAssertEqual(harness.health.savedWorkouts.first?.name, "Running")
    }

    func testDeleteFoodWaterWorkoutDeletesHealthSamples() async throws {
        let harness = TestHarness()
        let food = try harness.logFood().execute(harness.foodEntry())
        let water = try harness.logWater().execute(amountMilliliters: 180)
        let workout = try harness.logWorkout().execute(
            name: "Yoga",
            durationMinutes: 15,
            caloriesBurned: 60
        )
        try DeleteFoodEntryUseCase(foodEntryRepository: harness.food, healthSync: harness.health)
            .execute(id: food.id)
        try DeleteWaterEntryUseCase(waterEntryRepository: harness.water, healthSync: harness.health)
            .execute(id: water.id)
        try DeleteWorkoutEntryUseCase(workoutEntryRepository: harness.workout, healthSync: harness.health)
            .execute(id: workout.id)
        await waitUntil { Set(harness.health.deletedEntryIDs).isSuperset(of: [food.id, water.id, workout.id]) }
        XCTAssertEqual(Set(harness.health.deletedEntryIDs), [food.id, water.id, workout.id])
    }

    func testUpdateFoodReplacesHealthSamples() async throws {
        let harness = TestHarness()
        var entry = try harness.logFood().execute(harness.foodEntry(calories: 300, isEaten: true))
        await waitUntil { !harness.health.savedFoods.isEmpty }
        entry = FoodEntry(
            id: entry.id,
            name: entry.name,
            mealType: entry.mealType,
            calories: 450,
            protein: entry.protein,
            carbs: entry.carbs,
            fats: entry.fats,
            fiber: entry.fiber,
            sugar: entry.sugar,
            sodium: entry.sodium,
            date: entry.date,
            portionGrams: entry.portionGrams,
            source: entry.source,
            isEaten: true
        )
        try UpdateFoodEntryUseCase(
            foodEntryRepository: harness.food,
            healthSync: harness.health,
            appSettingsStore: harness.settings
        ).execute(entry)
        await waitUntil { harness.health.savedFoods.last?.calories == 450 }
        XCTAssertTrue(harness.health.deletedEntryIDs.contains(entry.id))
        XCTAssertEqual(try harness.food.fetchEntry(id: entry.id)?.calories, 450)
    }

    func testAuthorizationEnablesAllFlags() async throws {
        let store = FakeAppSettingsStore(.default)
        let health = FakeHealthSync()
        let useCase = RequestHealthSyncAuthorizationUseCase(healthSync: health, appSettingsStore: store)
        let granted = try await useCase.execute()
        XCTAssertTrue(granted)
        XCTAssertTrue(store.settings.healthSyncEnabled)
        XCTAssertTrue(store.settings.healthSyncFood)
        XCTAssertTrue(store.settings.healthSyncProfile)
        XCTAssertTrue(store.settings.healthAuthorizationRequested)
    }

    func testDeniedAuthorizationDoesNotEnableSync() async throws {
        let store = FakeAppSettingsStore(.default)
        let health = FakeHealthSync()
        health.authorizationResult = false
        let granted = try await RequestHealthSyncAuthorizationUseCase(
            healthSync: health,
            appSettingsStore: store
        ).execute()
        XCTAssertFalse(granted)
        XCTAssertFalse(store.settings.healthSyncEnabled)
    }

    func testWriteAuthorizationDoesNotDisableReadPreferences() async throws {
        let store = FakeAppSettingsStore(.default)
        let health = FakeHealthSync()
        health.snapshot = HealthAuthorizationSnapshot(
            isAvailable: true,
            types: [
                HealthTypeAuthorization(kind: .workouts, isAuthorized: true),
                HealthTypeAuthorization(kind: .activeEnergy, isAuthorized: true),
                HealthTypeAuthorization(kind: .steps, isAuthorized: false),
                HealthTypeAuthorization(kind: .weight, isAuthorized: false),
                HealthTypeAuthorization(kind: .water, isAuthorized: true),
                HealthTypeAuthorization(kind: .nutrition, isAuthorized: false),
                HealthTypeAuthorization(kind: .height, isAuthorized: false)
            ]
        )
        let snapshot = RequestHealthSyncAuthorizationUseCase(
            healthSync: health,
            appSettingsStore: store
        ).refreshFromStore()
        XCTAssertTrue(snapshot.isConnected)
        XCTAssertTrue(snapshot.isAuthorized(for: .workouts))
        XCTAssertFalse(snapshot.isAuthorized(for: .steps))
        XCTAssertTrue(store.settings.healthSyncEnabled)
        XCTAssertTrue(store.settings.healthSyncWorkouts)
        XCTAssertTrue(store.settings.healthSyncWater)
        XCTAssertTrue(store.settings.healthSyncWeight)
        XCTAssertTrue(store.settings.healthSyncFood)
    }

    func testControllerMarksAuthorizationRequestedEvenWhenRequestThrows() async throws {
        let store = FakeAppSettingsStore(.default)
        let health = FakeHealthSync()
        health.authorizationError = NSError(domain: "test", code: 1)
        let controller = HealthSyncController(
            healthSync: health,
            appSettingsStore: store,
            requestAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase(
                healthSync: health,
                appSettingsStore: store
            ),
            syncHealthDataUseCase: SyncHealthDataUseCase(
                healthSync: health,
                appSettingsStore: store,
                waterEntryRepository: WaterEntryRepository(coreDataStack: CoreDataStack(inMemory: true)),
                weightEntryRepository: WeightEntryRepository(coreDataStack: CoreDataStack(inMemory: true)),
                workoutEntryRepository: WorkoutEntryRepository(coreDataStack: CoreDataStack(inMemory: true)),
                foodEntryRepository: FoodEntryRepository(coreDataStack: CoreDataStack(inMemory: true)),
                userProfileRepository: UserProfileRepository(coreDataStack: CoreDataStack(inMemory: true))
            )
        )
        controller.bootstrap()
        await waitUntil { store.settings.healthAuthorizationRequested }
        XCTAssertTrue(store.settings.healthAuthorizationRequested)
        XCTAssertFalse(store.settings.healthSyncEnabled)
    }

    func testImportedWeightOverwritesOnboardingProfileWeight() async throws {
        let harness = TestHarness()
        var profile = try harness.profile.fetchProfile()
        profile.weightKg = 80
        try harness.profile.save(profile)
        harness.health.weightChanges = HealthAnchoredChange(
            added: [HealthQuantitySample(id: UUID(), value: 75, date: Date())],
            deletedIDs: []
        )
        try await harness.syncUseCase().execute()
        XCTAssertEqual(try harness.profile.fetchProfile().weightKg, 75)
    }

    func testHeightWriteRequiresEnabledSync() async throws {
        let harness = TestHarness()
        harness.settings.settings.healthSyncEnabled = false
        var profile = try harness.profile.fetchProfile()
        profile.heightCm = 178
        try SaveUserProfileUseCase(
            userProfileRepository: harness.profile,
            healthSync: harness.health,
            appSettingsStore: harness.settings
        ).execute(profile)
        try? await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertTrue(harness.health.savedHeights.isEmpty)

        harness.settings.settings.healthSyncEnabled = true
        try SaveUserProfileUseCase(
            userProfileRepository: harness.profile,
            healthSync: harness.health,
            appSettingsStore: harness.settings
        ).execute(profile)
        await waitUntil { !harness.health.savedHeights.isEmpty }
        XCTAssertEqual(harness.health.savedHeights.first?.0, 178)
    }
}
