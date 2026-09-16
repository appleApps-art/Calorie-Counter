import HealthKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class HealthSyncReliabilityTests: XCTestCase {
    func testReadOnlyAccessEnablesImportsWithoutClaimingWritePermission() {
        let settings = FakeAppSettingsStore()
        let health = FakeHealthSync()
        health.snapshot = HealthAuthorizationSnapshot(
            isAvailable: true,
            types: HealthPermissionKind.allCases.map { HealthTypeAuthorization(kind: $0, isAuthorized: false) },
            canAttemptRead: true
        )
        let snapshot = RequestHealthSyncAuthorizationUseCase(healthSync: health, appSettingsStore: settings).refreshFromStore()
        XCTAssertTrue(snapshot.isConnected)
        XCTAssertFalse(snapshot.isAuthorized(for: .nutrition))
        XCTAssertTrue(settings.settings.healthSyncEnabled)
        XCTAssertTrue(settings.settings.healthSyncFood)
    }

    func testDisconnectSurvivesRefreshUntilExplicitReconnect() async throws {
        let settings = FakeAppSettingsStore()
        settings.settings.healthSyncUserDisabled = true
        let health = FakeHealthSync()
        health.snapshot = .authorized
        let authorization = RequestHealthSyncAuthorizationUseCase(healthSync: health, appSettingsStore: settings)
        XCTAssertFalse(authorization.refreshFromStore().isConnected)
        XCTAssertFalse(settings.settings.healthSyncEnabled)
        _ = try await authorization.execute()
        XCTAssertFalse(settings.settings.healthSyncUserDisabled)
        XCTAssertTrue(settings.settings.healthSyncEnabled)
    }

    func testLegacyImportedMealsAreRepairedEvenOutsideRefreshWindow() async throws {
        let harness = TestHarness()
        let date = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        var entry = harness.foodEntry(calories: 520, source: HealthSyncSource.healthKit)
        entry = FoodEntry(id: entry.id, name: entry.name, mealType: .lunch, calories: 520, protein: 25, carbs: 60, fats: 20, fiber: 0, sugar: 0, sodium: 0, date: date, source: HealthSyncSource.healthKit, healthSampleID: UUID().uuidString)
        try harness.food.save(entry)
        try await harness.syncUseCase().execute()
        XCTAssertTrue(try XCTUnwrap(harness.food.fetchEntry(id: entry.id)).isEaten)
    }

    func testHistoricalHealthDeletionRemovesImportedWater() async throws {
        let harness = TestHarness()
        let sampleID = UUID()
        let date = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        try harness.water.save(WaterEntry(id: UUID(), amountMilliliters: 250, date: date, source: HealthSyncSource.healthKit, healthSampleID: sampleID.uuidString))
        harness.health.waterChanges = HealthAnchoredChange(added: [], deletedIDs: [sampleID])
        try await harness.syncUseCase().execute()
        XCTAssertTrue(try harness.water.fetchEntries(for: date).isEmpty)
    }

    func testLaterMacrosUpdateExistingMealWithoutDuplicatingOrChangingLocalID() async throws {
        let harness = TestHarness()
        let sampleID = UUID()
        harness.health.nutritionChanges = HealthAnchoredChange(added: [nutrition(id: sampleID, protein: 0)], deletedIDs: [])
        let useCase = harness.syncUseCase()
        try await useCase.execute()
        var original = try XCTUnwrap(harness.food.fetchAll().first)
        original.notes = "Keep my meal note"
        try harness.food.save(original)
        harness.health.nutritionChanges = HealthAnchoredChange(added: [nutrition(id: sampleID, protein: 32)], deletedIDs: [])
        try await useCase.execute()
        let entries = try harness.food.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, original.id)
        XCTAssertEqual(entries.first?.protein, 32)
        XCTAssertEqual(entries.first?.isEaten, true)
        XCTAssertEqual(entries.first?.notes, "Keep my meal note")
    }

    func testFailedLocalWriteDoesNotCommitAnchorAndRetryImportsOnce() async throws {
        let harness = TestHarness()
        let repository = FailingFoodRepository(base: harness.food)
        let checkpoint = HealthSyncCheckpoint(key: "nutrition", data: Data([1, 2, 3]))
        harness.health.nutritionChanges = HealthAnchoredChange(added: [nutrition()], deletedIDs: [], checkpoint: checkpoint)
        let useCase = SyncHealthDataUseCase(healthSync: harness.health, appSettingsStore: harness.settings, waterEntryRepository: harness.water, weightEntryRepository: harness.weight, workoutEntryRepository: harness.workout, foodEntryRepository: repository, userProfileRepository: harness.profile)
        do { try await useCase.execute(); XCTFail("Expected storage failure") } catch {}
        XCTAssertTrue(harness.health.committedCheckpoints.isEmpty)
        repository.shouldFail = false
        try await useCase.execute()
        XCTAssertEqual(harness.health.committedCheckpoints, [checkpoint])
        XCTAssertEqual(try harness.food.fetchAll().count, 1)
    }

    func testFoodCorrelationsKeepTwoMealsAtSameTimestampSeparate() {
        let date = Date()
        let energy1 = quantity(.dietaryEnergyConsumed, value: 100, date: date)
        let energy2 = quantity(.dietaryEnergyConsumed, value: 300, date: date)
        let protein1 = quantity(.dietaryProtein, value: 10, date: date)
        let protein2 = quantity(.dietaryProtein, value: 25, date: date)
        let type = HKCorrelationType.correlationType(forIdentifier: .food)!
        let correlations = [
            HKCorrelation(type: type, start: date, end: date, objects: [energy1, protein1]),
            HKCorrelation(type: type, start: date, end: date, objects: [energy2, protein2]),
        ]
        let result = HealthKitSyncService.associateNutrition(quantities: [energy1, energy2, protein1, protein2], correlations: correlations)
        XCTAssertEqual(result.samples.count, 2)
        XCTAssertEqual(result.samples.first { $0.id == energy1.uuid }?.protein, 10)
        XCTAssertEqual(result.samples.first { $0.id == energy2.uuid }?.protein, 25)
        XCTAssertTrue(result.supersededIDs.isEmpty)
    }

    func testUncorrelatedSamplesPreserveTotalsInsteadOfDuplicatingMacros() {
        let date = Date()
        let quantities = [
            quantity(.dietaryEnergyConsumed, value: 100, date: date),
            quantity(.dietaryEnergyConsumed, value: 300, date: date),
            quantity(.dietaryProtein, value: 10, date: date),
            quantity(.dietaryProtein, value: 25, date: date),
            quantity(.dietarySodium, value: 0.65, date: date),
        ]
        let result = HealthKitSyncService.associateNutrition(quantities: quantities, correlations: [])
        XCTAssertEqual(result.samples.count, 1)
        XCTAssertEqual(result.samples.first?.calories, 400)
        XCTAssertEqual(result.samples.first?.protein, 35)
        XCTAssertEqual(result.samples.first?.sodium, 650)
        XCTAssertEqual(result.supersededIDs.count, 1)
    }

    func testDeleteWaitsForSuspendedFoodSaveAndLeavesHealthEmpty() async throws {
        let harness = TestHarness()
        var release: CheckedContinuation<Void, Never>?
        harness.health.beforeSaveFood = { await withCheckedContinuation { release = $0 } }
        let entry = try harness.logFood().execute(harness.foodEntry(calories: 300, isEaten: true))
        await waitUntil { release != nil }
        try DeleteFoodEntryUseCase(foodEntryRepository: harness.food, healthSync: harness.health).execute(id: entry.id)
        release?.resume()
        await HealthExportQueue.shared.waitForPendingOperations()
        XCTAssertNil(harness.health.healthFoodStore[entry.id])
        XCTAssertNil(try harness.food.fetchEntry(id: entry.id))
    }

    func testConcurrentChangeQueuesAnotherSyncAndAllCallersAwaitIt() async throws {
        let harness = TestHarness()
        var release: CheckedContinuation<Void, Never>?
        harness.health.beforeFetchWeight = {
            if harness.health.weightFetchCount == 1 { await withCheckedContinuation { release = $0 } }
        }
        let controller = controller(harness)
        let first = Task { try await controller.syncIfNeeded() }
        await waitUntil { release != nil }
        var secondFinished = false
        let second = Task { try await controller.syncIfNeeded(); secondFinished = true }
        await Task.yield()
        XCTAssertFalse(secondFinished)
        release?.resume()
        try await first.value
        try await second.value
        XCTAssertEqual(harness.health.weightFetchCount, 2)
        XCTAssertNotNil(harness.settings.settings.healthLastSyncedAt)
    }

    func testFailedSyncPreservesLastSuccessfulTimestampAndCanRetry() async throws {
        let harness = TestHarness()
        let lastSuccess = Date(timeIntervalSince1970: 100)
        harness.settings.settings.healthLastSyncedAt = lastSuccess
        harness.health.beforeFetchWeight = { throw NSError(domain: "Locked Health database", code: 1) }
        let controller = controller(harness)
        do { try await controller.syncIfNeeded(); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(harness.settings.settings.healthLastSyncedAt, lastSuccess)
        XCTAssertTrue(harness.health.importRetryNeeded)
        harness.health.beforeFetchWeight = nil
        try await controller.syncIfNeeded()
        XCTAssertGreaterThan(harness.settings.settings.healthLastSyncedAt!, lastSuccess)
        XCTAssertFalse(harness.health.importRetryNeeded)
    }

    func testOlderHealthProfileWeightDoesNotOverwriteNewerDatedLocalWeight() async throws {
        let harness = TestHarness()
        try harness.weight.save(WeightEntry(id: UUID(), weightKilograms: 80, date: Date(), source: "manual"))
        harness.health.profileSnapshot = HealthProfileSnapshot(weightKg: 100)
        try await harness.syncUseCase().execute()
        XCTAssertEqual(try harness.profile.fetchProfile().weightKg, 80)
    }

    func testProfileSavedCallbackSeesNewPersistedWeight() async throws {
        let harness = TestHarness()
        harness.health.weightChanges = HealthAnchoredChange(added: [HealthQuantitySample(id: UUID(), value: 75, date: Date())], deletedIDs: [])
        var notifiedWeights: [Double?] = []
        let useCase = SyncHealthDataUseCase(healthSync: harness.health, appSettingsStore: harness.settings, waterEntryRepository: harness.water, weightEntryRepository: harness.weight, workoutEntryRepository: harness.workout, foodEntryRepository: harness.food, userProfileRepository: harness.profile, onProfileSaved: {
            notifiedWeights.append(try? harness.profile.fetchProfile().weightKg)
        })
        try await useCase.execute()
        XCTAssertEqual(notifiedWeights, [75])
    }

    func testObserverAcknowledgesOnlyAfterAwaitedProcessing() async {
        var release: CheckedContinuation<Void, Never>?
        var completed = false
        var needsRetry = true
        let delivery = Task {
            await HealthKitSyncService.processObserverDelivery(error: nil, synchronize: {
                await withCheckedContinuation { release = $0 }
            }, markRetry: { needsRetry = $0 }, completion: { completed = true })
        }
        await waitUntil { release != nil }
        XCTAssertFalse(completed)
        release?.resume()
        await delivery.value
        XCTAssertTrue(completed)
        XCTAssertFalse(needsRetry)
    }

    func testObserverFailureAcknowledgesAndRetainsRetryWithoutFakeSuccessfulSync() async {
        let error = NSError(domain: "Locked Health database", code: 1)
        var completed = false
        var needsRetry = false
        var syncCalled = false
        await HealthKitSyncService.processObserverDelivery(error: error, synchronize: {
            syncCalled = true
        }, markRetry: { needsRetry = $0 }, completion: { completed = true })
        XCTAssertTrue(completed)
        XCTAssertTrue(needsRetry)
        XCTAssertFalse(syncCalled)
        completed = false
        needsRetry = false
        await HealthKitSyncService.processObserverDelivery(error: nil, synchronize: {
            throw error
        }, markRetry: { needsRetry = $0 }, completion: { completed = true })
        XCTAssertTrue(completed)
        XCTAssertTrue(needsRetry)
    }

    func testDailyActivityReplacesPriorTotalsIncludingRemovedData() async throws {
        let harness = TestHarness()
        let store = MemoryActivityStore()
        let day = Calendar.current.startOfDay(for: Date())
        let useCase = SyncHealthDataUseCase(healthSync: harness.health, appSettingsStore: harness.settings, waterEntryRepository: harness.water, weightEntryRepository: harness.weight, workoutEntryRepository: harness.workout, foodEntryRepository: harness.food, userProfileRepository: harness.profile, activityStore: store)
        harness.health.dailyActivity = [HealthDailyActivity(date: day, activeEnergyKilocalories: 600, steps: 8500)]
        try await useCase.execute()
        XCTAssertEqual(store.days.first?.activeEnergyKilocalories, 600)
        harness.health.dailyActivity = [HealthDailyActivity(date: day, activeEnergyKilocalories: nil, steps: nil)]
        try await useCase.execute()
        XCTAssertNil(store.days.first?.activeEnergyKilocalories)
        XCTAssertNil(store.days.first?.steps)
        XCTAssertEqual(store.replacements, 2)
    }

    private func controller(_ harness: TestHarness) -> HealthSyncController {
        HealthSyncController(healthSync: harness.health, appSettingsStore: harness.settings, requestAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase(healthSync: harness.health, appSettingsStore: harness.settings), syncHealthDataUseCase: harness.syncUseCase())
    }

    private func nutrition(id: UUID = UUID(), protein: Double = 20) -> HealthNutritionSample {
        HealthNutritionSample(id: id, date: testDate(hour: 12), calories: 520, protein: protein, carbs: 60, fats: 20, fiber: 4, sugar: 8, sodium: 650)
    }

    func testEnergyWithExternalIDKeepsUnlabelledNutrientsAtSameTimestamp() {
        let date = testDate(hour: 12)
        let energy = HKQuantitySample(type: HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 520), start: date, end: date, metadata: [HKMetadataKeyExternalUUID: "meal-1"])
        let protein = quantity(.dietaryProtein, value: 30, date: date)
        let result = HealthKitSyncService.associateNutrition(quantities: [energy, protein], correlations: [])
        XCTAssertEqual(result.samples.count, 1)
        XCTAssertEqual(result.samples.first?.calories, 520)
        XCTAssertEqual(result.samples.first?.protein, 30)
    }

    private func quantity(_ identifier: HKQuantityTypeIdentifier, value: Double, date: Date) -> HKQuantitySample {
        HKQuantitySample(type: HKQuantityType.quantityType(forIdentifier: identifier)!, quantity: HKQuantity(unit: identifier == .dietaryEnergyConsumed ? .kilocalorie() : .gram(), doubleValue: value), start: date, end: date)
    }
}

@MainActor
private final class FailingFoodRepository: FoodEntryRepositoryProtocol {
    let base: FoodEntryRepositoryProtocol
    var shouldFail = true
    init(base: FoodEntryRepositoryProtocol) { self.base = base }
    func fetchAll() throws -> [FoodEntry] { try base.fetchAll() }
    func fetchEntries(for date: Date) throws -> [FoodEntry] { try base.fetchEntries(for: date) }
    func fetchEntries(from start: Date, to end: Date) throws -> [FoodEntry] { try base.fetchEntries(from: start, to: end) }
    func fetchEntry(id: UUID) throws -> FoodEntry? { try base.fetchEntry(id: id) }
    func save(_ entry: FoodEntry) throws {
        if shouldFail { throw NSError(domain: "Storage", code: 1) }
        try base.save(entry)
    }
    func delete(id: UUID) throws { try base.delete(id: id) }
}

@MainActor
private final class MemoryActivityStore: HealthDailyActivityStoring {
    var days: [HealthDailyActivity] = []
    var replacements = 0
    func fetch(from start: Date, to end: Date) throws -> [HealthDailyActivity] { days }
    func replace(_ days: [HealthDailyActivity], from start: Date, to end: Date) throws { self.days = days; replacements += 1 }
}
