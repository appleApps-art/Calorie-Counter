import CoreData
import Foundation
import XCTest
@testable import Calorie_Counter

final class FakeAppSettingsStore: AppSettingsStoring {
    var settings: AppSettings

    init(_ settings: AppSettings = .default) {
        self.settings = settings
    }
}

final class FakeHealthSync: HealthSyncing {
    var isAvailable = true
    var authorizationResult = true
    var authorizationError: Error?
    var backgroundDeliveryCount = 0
    var observerHandler: (@Sendable () async throws -> Void)?

    var savedWeights: [(Double, Date, UUID)] = []
    var savedWaters: [(Double, Date, UUID)] = []
    var savedWorkouts: [WorkoutEntry] = []
    var savedFoods: [FoodEntry] = []
    var savedHeights: [(Double, Date, UUID)] = []
    var deletedEntryIDs: [UUID] = []

    var beforeSaveFood: (() async -> Void)?
    var beforeFetchWeight: (() async throws -> Void)?
    var weightFetchCount = 0
    var importRetryNeeded = false
    var committedCheckpoints: [HealthSyncCheckpoint] = []
    var dailyActivity: [HealthDailyActivity] = []
    var healthFoodStore: [UUID: FoodEntry] = [:]
    var latestWeight: Double?
    var weightChanges = HealthAnchoredChange<HealthQuantitySample>(added: [], deletedIDs: [])
    var waterChanges = HealthAnchoredChange<HealthQuantitySample>(added: [], deletedIDs: [])
    var workoutChanges = HealthAnchoredChange<HealthWorkoutSample>(added: [], deletedIDs: [])
    var nutritionChanges = HealthAnchoredChange<HealthNutritionSample>(added: [], deletedIDs: [])
    var profileSnapshot = HealthProfileSnapshot()
    var snapshot = HealthAuthorizationSnapshot.disconnected
    var needsPrompt = false
    var stopSyncingCount = 0

    func authorizationSnapshot() -> HealthAuthorizationSnapshot {
        snapshot
    }

    func needsAuthorizationPrompt() async -> Bool {
        needsPrompt
    }

    func requestAuthorization() async throws -> Bool {
        if let authorizationError { throw authorizationError }
        snapshot = authorizationResult ? .authorized : .disconnected
        return snapshot.isConnected
    }

    func enableBackgroundDelivery() async {
        backgroundDeliveryCount += 1
    }

    func stopSyncing() async {
        stopSyncingCount += 1
        observerHandler = nil
    }

    func startObservingChanges(_ handler: @escaping @Sendable () async throws -> Void) {
        observerHandler = handler
    }

    func saveWeight(_ kilograms: Double, date: Date, entryID: UUID) async throws {
        savedWeights.append((kilograms, date, entryID))
    }

    func saveWater(milliliters: Double, date: Date, entryID: UUID) async throws {
        savedWaters.append((milliliters, date, entryID))
    }

    func saveWorkout(_ entry: WorkoutEntry) async throws {
        savedWorkouts.append(entry)
    }

    func saveFood(_ entry: FoodEntry) async throws {
        await beforeSaveFood?()
        savedFoods.append(entry)
        healthFoodStore[entry.id] = entry
    }

    func saveHeight(_ centimeters: Double, date: Date, entryID: UUID) async throws {
        savedHeights.append((centimeters, date, entryID))
    }

    func deleteSamples(entryID: UUID) async throws {
        deletedEntryIDs.append(entryID)
        healthFoodStore[entryID] = nil
    }

    func fetchLatestWeight() async throws -> Double? {
        latestWeight
    }

    func fetchWeightChanges() async throws -> HealthAnchoredChange<HealthQuantitySample> {
        weightFetchCount += 1
        try await beforeFetchWeight?()
        return weightChanges
    }

    func markImportRetryNeeded(_ isNeeded: Bool) { importRetryNeeded = isNeeded }

    func commit(_ checkpoint: HealthSyncCheckpoint) {
        committedCheckpoints.append(checkpoint)
    }

    func fetchDailyActivity(from start: Date, to end: Date) async throws -> [HealthDailyActivity] {
        dailyActivity
    }

    func fetchWaterChanges() async throws -> HealthAnchoredChange<HealthQuantitySample> {
        waterChanges
    }

    func fetchWorkoutChanges() async throws -> HealthAnchoredChange<HealthWorkoutSample> {
        workoutChanges
    }

    func fetchNutritionChanges() async throws -> HealthAnchoredChange<HealthNutritionSample> {
        nutritionChanges
    }

    func fetchProfileSnapshot() async throws -> HealthProfileSnapshot {
        profileSnapshot
    }
}

struct TestHarness {
    let stack: CoreDataStack
    let settings: FakeAppSettingsStore
    let health: FakeHealthSync
    let food: FoodEntryRepository
    let water: WaterEntryRepository
    let weight: WeightEntryRepository
    let workout: WorkoutEntryRepository
    let profile: UserProfileRepository
    let goals: UserGoalsRepository
    let recipes: RecipeRepository
    let preferences: UserPreferenceRepository
    let photos: ProgressPhotoRepository
    let photoStore: LocalImageFileStore

    init() {
        stack = CoreDataStack(inMemory: true)
        settings = FakeAppSettingsStore(
            AppSettings(
                healthSyncEnabled: true,
                healthSyncWeight: true,
                healthSyncWater: true,
                healthSyncWorkouts: true,
                healthSyncFood: true,
                healthSyncProfile: true,
                healthAuthorizationRequested: true
            )
        )
        health = FakeHealthSync()
        food = FoodEntryRepository(coreDataStack: stack)
        water = WaterEntryRepository(coreDataStack: stack)
        weight = WeightEntryRepository(coreDataStack: stack)
        workout = WorkoutEntryRepository(coreDataStack: stack)
        profile = UserProfileRepository(coreDataStack: stack)
        goals = UserGoalsRepository(coreDataStack: stack)
        recipes = RecipeRepository(coreDataStack: stack)
        preferences = UserPreferenceRepository(coreDataStack: stack)
        photos = ProgressPhotoRepository(coreDataStack: stack)
        photoStore = LocalImageFileStore(
            folderName: "bity-tests-\(UUID().uuidString)",
            fileManager: .default
        )
    }

    func syncUseCase() -> SyncHealthDataUseCase {
        SyncHealthDataUseCase(
            healthSync: health,
            appSettingsStore: settings,
            waterEntryRepository: water,
            weightEntryRepository: weight,
            workoutEntryRepository: workout,
            foodEntryRepository: food,
            userProfileRepository: profile
        )
    }

    func logFood() -> LogFoodUseCase {
        LogFoodUseCase(
            foodEntryRepository: food,
            healthSync: health,
            appSettingsStore: settings
        )
    }

    func logWater() -> LogWaterUseCase {
        LogWaterUseCase(
            waterEntryRepository: water,
            healthSync: health,
            appSettingsStore: settings
        )
    }

    func logWeight() -> LogWeightUseCase {
        LogWeightUseCase(
            weightEntryRepository: weight,
            healthSync: health,
            appSettingsStore: settings
        )
    }

    func logWorkout() -> LogWorkoutUseCase {
        LogWorkoutUseCase(
            workoutEntryRepository: workout,
            healthSync: health,
            appSettingsStore: settings
        )
    }

    func homeViewModel() -> HomeViewModel {
        HomeViewModel(
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                foodEntryRepository: food,
                waterEntryRepository: water,
                userGoalsRepository: goals,
                workoutEntryRepository: workout
            ),
            logWaterUseCase: logWater(),
            deleteFoodEntryUseCase: DeleteFoodEntryUseCase(foodEntryRepository: food, healthSync: health),
            updateFoodEntryUseCase: UpdateFoodEntryUseCase(
                foodEntryRepository: food,
                healthSync: health,
                appSettingsStore: settings
            ),
            scaleFoodPortionUseCase: ScaleFoodPortionUseCase(),
            logWorkoutUseCase: logWorkout(),
            logWeightUseCase: logWeight(),
            deleteWaterEntryUseCase: DeleteWaterEntryUseCase(waterEntryRepository: water, healthSync: health),
            deleteWorkoutEntryUseCase: DeleteWorkoutEntryUseCase(
                workoutEntryRepository: workout,
                healthSync: health
            ),
            appSettingsStore: settings,
            fetchOnboardingStateUseCase: FetchOnboardingStateUseCase(
                userProfileRepository: profile,
                avatarFileStore: photoStore
            ),
            calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase(),
            evaluateStreakUseCase: EvaluateStreakUseCase(
                foodEntryRepository: food,
                rewardsRepository: RewardsRepository(coreDataStack: stack)
            )
        )
    }

    func foodEntry(
        name: String = "Oats",
        mealType: MealType = .breakfast,
        calories: Double = 300,
        protein: Double = 12,
        carbs: Double = 40,
        fats: Double = 8,
        fiber: Double = 4,
        sugar: Double = 2,
        sodium: Double = 80,
        date: Date = Date(),
        grams: Double? = 100,
        source: String? = nil,
        healthSampleID: String? = nil,
        isEaten: Bool = false
    ) -> FoodEntry {
        FoodEntry(
            id: UUID(),
            name: name,
            mealType: mealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            date: date,
            portionGrams: grams,
            source: source,
            healthSampleID: healthSampleID,
            isEaten: isEaten
        )
    }
}

func testDate(hour: Int, minute: Int = 0, daysFromNow: Int = 0) -> Date {
    let calendar = Calendar.current
    let day = calendar.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
}

func waitUntil(timeout: TimeInterval = 1, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}
