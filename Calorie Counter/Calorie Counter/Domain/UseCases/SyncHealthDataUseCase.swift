import Foundation

final class SyncHealthDataUseCase {
    private let healthSync: HealthSyncing
    private let appSettingsStore: AppSettingsStoring
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let weightEntryRepository: WeightEntryRepositoryProtocol
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let userProfileRepository: UserProfileRepositoryProtocol
    private let activityStore: HealthDailyActivityStoring?
    private let onProfileUpdated: ((UserProfile) throws -> Void)?
    private let onProfileSaved: (() -> Void)?

    init(
        healthSync: HealthSyncing,
        appSettingsStore: AppSettingsStoring,
        waterEntryRepository: WaterEntryRepositoryProtocol,
        weightEntryRepository: WeightEntryRepositoryProtocol,
        workoutEntryRepository: WorkoutEntryRepositoryProtocol,
        foodEntryRepository: FoodEntryRepositoryProtocol,
        userProfileRepository: UserProfileRepositoryProtocol,
        activityStore: HealthDailyActivityStoring? = nil,
        onProfileUpdated: ((UserProfile) throws -> Void)? = nil,
        onProfileSaved: (() -> Void)? = nil
    ) {
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
        self.waterEntryRepository = waterEntryRepository
        self.weightEntryRepository = weightEntryRepository
        self.workoutEntryRepository = workoutEntryRepository
        self.foodEntryRepository = foodEntryRepository
        self.userProfileRepository = userProfileRepository
        self.activityStore = activityStore
        self.onProfileUpdated = onProfileUpdated
        self.onProfileSaved = onProfileSaved
    }

    func execute() async throws {
        let settings = appSettingsStore.settings
        guard settings.healthSyncEnabled, !settings.healthSyncUserDisabled else { return }
        let rangeStart = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let rangeEnd = Date().addingTimeInterval(60)

        if settings.healthSyncWeight {
            try await importWeight(from: rangeStart, to: rangeEnd)
        }
        if settings.healthSyncWater {
            try await importWater(from: rangeStart, to: rangeEnd)
        }
        if settings.healthSyncWorkouts {
            try await importWorkouts(from: rangeStart, to: rangeEnd)
        }
        if settings.healthSyncFood {
            try await importNutrition(from: rangeStart, to: rangeEnd)
        }
        if settings.healthSyncProfile {
            try await importProfile()
        }
        if let activityStore {
            let activityStart = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? rangeStart)
            let days = try await healthSync.fetchDailyActivity(from: activityStart, to: rangeEnd)
            try activityStore.replace(days, from: activityStart, to: rangeEnd)
        }
    }

    private func importWeight(from start: Date, to end: Date) async throws {
        let change = try await healthSync.fetchWeightChanges()
        let existing = try weightEntryRepository.fetchEntries()
        let known = Set(existing.compactMap(\.healthSampleID))
        for sample in change.added where !known.contains(sample.id.uuidString) {
            try weightEntryRepository.save(
                WeightEntry(
                    id: UUID(),
                    weightKilograms: sample.value,
                    date: sample.date,
                    source: HealthSyncSource.healthKit,
                    healthSampleID: sample.id.uuidString
                )
            )
        }
        try deleteMatching(change.deletedIDs, in: existing, delete: weightEntryRepository.delete)
        if let latest = try weightEntryRepository.fetchEntries().last {
            var profile = try userProfileRepository.fetchProfile()
            if profile.weightKg != latest.weightKilograms {
                profile.weightKg = latest.weightKilograms
                try onProfileUpdated?(profile)
                try userProfileRepository.save(profile)
                onProfileSaved?()
            }
        }
        if let checkpoint = change.checkpoint { healthSync.commit(checkpoint) }
    }

    private func importWater(from start: Date, to end: Date) async throws {
        let change = try await healthSync.fetchWaterChanges()
        let existing = try waterEntryRepository.fetchEntries(from: .distantPast, to: .distantFuture)
        let known = Set(existing.compactMap(\.healthSampleID))
        for sample in change.added where sample.value > 0 && !known.contains(sample.id.uuidString) {
            try waterEntryRepository.save(
                WaterEntry(
                    id: UUID(),
                    amountMilliliters: sample.value,
                    date: sample.date,
                    source: HealthSyncSource.healthKit,
                    healthSampleID: sample.id.uuidString
                )
            )
        }
        try deleteMatching(change.deletedIDs, in: existing, delete: waterEntryRepository.delete)
        if let checkpoint = change.checkpoint { healthSync.commit(checkpoint) }
    }

    private func importWorkouts(from start: Date, to end: Date) async throws {
        let change = try await healthSync.fetchWorkoutChanges()
        let existing = try workoutEntryRepository.fetchEntries()
        let known = Set(existing.compactMap(\.healthSampleID))
        for sample in change.added where !known.contains(sample.id.uuidString) {
            try workoutEntryRepository.save(
                WorkoutEntry(
                    id: UUID(),
                    name: sample.name,
                    durationMinutes: sample.durationMinutes,
                    caloriesBurned: sample.caloriesBurned,
                    date: sample.date,
                    source: HealthSyncSource.healthKit,
                    healthSampleID: sample.id.uuidString
                )
            )
        }
        try deleteMatching(change.deletedIDs, in: existing, delete: workoutEntryRepository.delete)
        if let checkpoint = change.checkpoint { healthSync.commit(checkpoint) }
    }

    private func importNutrition(from start: Date, to end: Date) async throws {
        let existing = try foodEntryRepository.fetchAll()
        let imported = existing.filter { $0.source == HealthSyncSource.healthKit && $0.healthSampleID != nil }
        let earliest = min(start, imported.map(\.date).min() ?? start)
        let change = try await healthSync.fetchNutritionChanges(from: earliest)
        let bySample = Dictionary(imported.compactMap { entry in entry.healthSampleID.map { ($0, entry) } }, uniquingKeysWith: { first, _ in first })
        // Repair entries written by older versions as planned meals. Health's
        // dietary quantities describe consumption, never a future meal plan.
        let refreshedIDs = Set(change.added.map { $0.id.uuidString })
        for var entry in imported where !entry.isEaten && !refreshedIDs.contains(entry.healthSampleID ?? "") {
            entry.isEaten = true
            try foodEntryRepository.save(entry)
        }
        for sample in change.added where sample.calories > 0 {
            let previous = bySample[sample.id.uuidString]
            let entry = FoodEntry(
                id: previous?.id ?? UUID(),
                name: previous?.name ?? L10n.tr("health.importedFood"),
                mealType: previous?.mealType ?? mealType(for: sample.date),
                calories: sample.calories,
                protein: sample.protein,
                carbs: sample.carbs,
                fats: sample.fats,
                fiber: sample.fiber,
                sugar: sample.sugar,
                sodium: sample.sodium,
                date: sample.date,
                portionGrams: previous?.portionGrams,
                portionMilliliters: previous?.portionMilliliters,
                notes: previous?.notes ?? "",
                source: HealthSyncSource.healthKit,
                imageURL: previous?.imageURL,
                imageData: previous?.imageData,
                healthSampleID: sample.id.uuidString,
                isEaten: true,
                ingredientLines: previous?.ingredientLines ?? [],
                recipeSteps: previous?.recipeSteps ?? [],
                catalogExternalId: previous?.catalogExternalId,
                catalogKind: previous?.catalogKind,
                foodType: previous?.resolvedFoodType,
            hasCompleteNutrition: previous?.hasCompleteNutrition
            )
            if entry != previous { try foodEntryRepository.save(entry) }
        }
        try deleteMatching(change.deletedIDs, in: imported, delete: foodEntryRepository.delete)
        if let checkpoint = change.checkpoint { healthSync.commit(checkpoint) }
    }

    private func importProfile() async throws {
        let snapshot = try await healthSync.fetchProfileSnapshot()
        var profile = try userProfileRepository.fetchProfile()
        var changed = false
        if profile.sex == nil, let sex = snapshot.sex {
            profile.sex = sex
            changed = true
        }
        if profile.age == nil, let age = snapshot.age {
            profile.age = age
            changed = true
        }
        if profile.heightCm == nil, let height = snapshot.heightCm {
            profile.heightCm = height
            changed = true
        }
        // The profile snapshot has no timestamp. Prefer the dated diary history
        // already reconciled above, including a newer local-only measurement.
        if try weightEntryRepository.fetchEntries().isEmpty,
           let weight = snapshot.weightKg, profile.weightKg != weight {
            profile.weightKg = weight
            changed = true
        }
        if changed {
            try onProfileUpdated?(profile)
            try userProfileRepository.save(profile)
            onProfileSaved?()
        }
    }

    private func deleteMatching<Entry>(
        _ deletedIDs: [UUID],
        in existing: [Entry],
        delete: (UUID) throws -> Void
    ) throws where Entry: HealthSampleLinked {
        guard !deletedIDs.isEmpty else { return }
        let deleted = Set(deletedIDs.map(\.uuidString))
        for entry in existing {
            if let sampleID = entry.healthSampleID, deleted.contains(sampleID) {
                try delete(entry.id)
            }
        }
    }

    private func mealType(for date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5...10:
            return .breakfast
        case 11...15:
            return .lunch
        case 16...21:
            return .dinner
        default:
            return .snacks
        }
    }
}

private protocol HealthSampleLinked {
    var id: UUID { get }
    var healthSampleID: String? { get }
}

extension WaterEntry: HealthSampleLinked {}
extension WeightEntry: HealthSampleLinked {}
extension WorkoutEntry: HealthSampleLinked {}
extension FoodEntry: HealthSampleLinked {}
