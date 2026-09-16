import Foundation

final class LogFoodUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let awardXPUseCase: AwardXPUseCase?
    private let healthSync: HealthSyncing?
    private let appSettingsStore: AppSettingsStoring?
    private let analytics: AnalyticsTracking?

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil,
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil,
        analytics: AnalyticsTracking? = nil
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.awardXPUseCase = awardXPUseCase
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
        self.analytics = analytics
    }

    func execute(_ entry: FoodEntry) throws -> FoodEntry {
        try foodEntryRepository.save(entry)
        if entry.source != HealthSyncSource.healthKit {
            try awardXPUseCase?.execute(kind: .food, relatedID: entry.id)
            analytics?.track(.foodLogged(
                method: entry.source ?? "unknown",
                mealType: entry.mealType.rawValue,
                calories: Int(entry.calories.rounded())
            ))
        }
        syncLoggedFoodToHealth(entry, healthSync: healthSync, appSettingsStore: appSettingsStore)
        return entry
    }

    func execute(from product: FoodProduct, mealType: MealType, date: Date = Date(), imageData: Data? = nil) throws -> FoodEntry {
        var draft = ProductDetailsMath.fillingDefaultPortion(ProductDetailsMath.draft(
            from: product, imageData: imageData, mealType: mealType, date: date
        ))
        draft.source = "search"
        draft.catalogExternalId = product.externalId.isEmpty ? nil : product.externalId
        return try execute(draft.toFoodEntry())
    }
}

final class UpdateFoodEntryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let healthSync: HealthSyncing?
    private let appSettingsStore: AppSettingsStoring?

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
    }

    func execute(_ entry: FoodEntry) throws {
        try foodEntryRepository.save(entry)
        syncLoggedFoodToHealth(entry, healthSync: healthSync, appSettingsStore: appSettingsStore)
    }
}

final class DeleteFoodEntryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let healthSync: HealthSyncing?
    private let analytics: AnalyticsTracking?

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        healthSync: HealthSyncing? = nil,
        analytics: AnalyticsTracking? = nil
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.healthSync = healthSync
        self.analytics = analytics
    }

    func execute(id: UUID) throws {
        let mealType = (try? foodEntryRepository.fetchEntry(id: id))?.mealType.rawValue
        try foodEntryRepository.delete(id: id)
        analytics?.track(.foodDeleted(mealType: mealType ?? "unknown"))
        HealthExportQueue.shared.enqueue(entryID: id) { [healthSync] in
            try await healthSync?.deleteSamples(entryID: id)
        }
    }
}

final class FetchSavedFoodsUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol

    init(foodEntryRepository: FoodEntryRepositoryProtocol) {
        self.foodEntryRepository = foodEntryRepository
    }

    func executeRecent() throws -> [FoodEntry] {
        var seen = Set<String>()
        return try foodEntryRepository.fetchAll().sorted { $0.date > $1.date }.filter { entry in
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let kind = entry.catalogKind ?? (entry.opensAsRecipe ? .recipe : .product)
            return !name.isEmpty && seen.insert("\(kind.rawValue):\(name)").inserted
        }
    }

    func execute() throws -> [FoodEntry] {
        var seen = Set<String>()
        var unique: [FoodEntry] = []
        for entry in try foodEntryRepository.fetchAll() {
            let key = entry.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            unique.append(entry)
        }
        return unique.sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

final class ScaleFoodPortionUseCase {
    func execute(entry: FoodEntry, grams: Double) -> FoodEntry {
        entry.scaled(toGrams: grams)
    }

    func execute(entry: FoodEntry, milliliters: Double) -> FoodEntry {
        entry.scaled(toMilliliters: milliliters)
    }
}

final class ReplaceFoodEntryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let awardXPUseCase: AwardXPUseCase?
    private let healthSync: HealthSyncing?
    private let appSettingsStore: AppSettingsStoring?

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil,
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.awardXPUseCase = awardXPUseCase
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
    }

    func execute(targetId: UUID, with proposal: FoodLogProposal, date: Date? = nil) throws -> FoodEntry {
        let existing = try foodEntryRepository.fetchEntry(id: targetId)
        var replacement = proposal.toFoodEntry(date: date ?? existing?.date ?? Date())
        replacement = FoodEntry(
            id: targetId,
            name: replacement.name,
            mealType: replacement.mealType,
            calories: replacement.calories,
            protein: replacement.protein,
            carbs: replacement.carbs,
            fats: replacement.fats,
            fiber: replacement.fiber,
            sugar: replacement.sugar,
            sodium: replacement.sodium,
            date: replacement.date,
            portionGrams: replacement.portionGrams,
            portionMilliliters: replacement.portionMilliliters,
            notes: replacement.notes,
            source: replacement.source,
            imageURL: replacement.imageURL,
            imageData: replacement.imageData,
            isEaten: false,
            ingredientLines: replacement.ingredientLines,
            recipeSteps: replacement.recipeSteps,
            catalogExternalId: replacement.catalogExternalId,
            catalogKind: replacement.catalogKind,
            foodType: replacement.resolvedFoodType,
            hasCompleteNutrition: replacement.hasCompleteNutrition
        )
        try foodEntryRepository.save(replacement)
        try awardXPUseCase?.execute(kind: .foodSwap, relatedID: targetId)
        syncLoggedFoodToHealth(replacement, healthSync: healthSync, appSettingsStore: appSettingsStore)
        return replacement
    }
}

final class DeleteWaterEntryUseCase {
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let healthSync: HealthSyncing?

    init(
        waterEntryRepository: WaterEntryRepositoryProtocol,
        healthSync: HealthSyncing? = nil
    ) {
        self.waterEntryRepository = waterEntryRepository
        self.healthSync = healthSync
    }

    func execute(id: UUID) throws {
        try waterEntryRepository.delete(id: id)
        HealthExportQueue.shared.enqueue(entryID: id) { [healthSync] in
            try await healthSync?.deleteSamples(entryID: id)
        }
    }
}

final class DeleteWorkoutEntryUseCase {
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol
    private let healthSync: HealthSyncing?

    init(
        workoutEntryRepository: WorkoutEntryRepositoryProtocol,
        healthSync: HealthSyncing? = nil
    ) {
        self.workoutEntryRepository = workoutEntryRepository
        self.healthSync = healthSync
    }

    func execute(id: UUID) throws {
        try workoutEntryRepository.delete(id: id)
        HealthExportQueue.shared.enqueue(entryID: id) { [healthSync] in
            try await healthSync?.deleteSamples(entryID: id)
        }
    }
}

final class FetchWeightHistoryUseCase {
    private let weightEntryRepository: WeightEntryRepositoryProtocol

    init(weightEntryRepository: WeightEntryRepositoryProtocol) {
        self.weightEntryRepository = weightEntryRepository
    }

    func execute() throws -> [WeightEntry] {
        try weightEntryRepository.fetchEntries()
    }
}

final class LogWeightUseCase {
    private let weightEntryRepository: WeightEntryRepositoryProtocol
    private let awardXPUseCase: AwardXPUseCase?
    private let healthSync: HealthSyncing?
    private let appSettingsStore: AppSettingsStoring?
    private let analytics: AnalyticsTracking?
    private let onWeightLogged: ((WeightEntry) throws -> Void)?

    init(
        weightEntryRepository: WeightEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil,
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil,
        analytics: AnalyticsTracking? = nil,
        onWeightLogged: ((WeightEntry) throws -> Void)? = nil
    ) {
        self.weightEntryRepository = weightEntryRepository
        self.awardXPUseCase = awardXPUseCase
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
        self.analytics = analytics
        self.onWeightLogged = onWeightLogged
    }

    func execute(
        weightKilograms: Double,
        date: Date = Date(),
        source: String? = nil,
        healthSampleID: String? = nil,
        syncToHealth: Bool = true,
        awardXP: Bool = true
    ) throws -> WeightEntry {
        let entry = WeightEntry(
            id: UUID(),
            weightKilograms: weightKilograms,
            date: date,
            source: source,
            healthSampleID: healthSampleID
        )
        try weightEntryRepository.save(entry)
        try onWeightLogged?(entry)
        if awardXP {
            try awardXPUseCase?.execute(kind: .weight, relatedID: entry.id)
        }
        if entry.source != HealthSyncSource.healthKit {
            analytics?.track(.weightLogged)
        }
        let settings = appSettingsStore?.settings
        if syncToHealth,
           settings?.healthSyncEnabled == true,
           settings?.healthSyncWeight == true,
           entry.source != HealthSyncSource.healthKit
        {
            HealthExportQueue.shared.enqueue(entryID: entry.id) { [healthSync] in
                try await healthSync?.saveWeight(weightKilograms, date: date, entryID: entry.id)
            }
        }
        return entry
    }
}

final class SaveUserGoalsUseCase {
    private let userGoalsRepository: UserGoalsRepositoryProtocol
    private let appSettingsStore: AppSettingsStoring?

    init(userGoalsRepository: UserGoalsRepositoryProtocol, appSettingsStore: AppSettingsStoring? = nil) {
        self.userGoalsRepository = userGoalsRepository
        self.appSettingsStore = appSettingsStore
    }

    func execute(_ goals: UserGoals) throws {
        try userGoalsRepository.save(goals)
        if let appSettingsStore {
            var settings = appSettingsStore.settings
            settings.automaticallyAdjustNutritionGoals = false
            settings.nutritionGoalModeResolved = true
            appSettingsStore.settings = settings
        }
    }
}

private func syncLoggedFoodToHealth(
    _ entry: FoodEntry,
    healthSync: HealthSyncing?,
    appSettingsStore: AppSettingsStoring?
) {
    let settings = appSettingsStore?.settings
    guard settings?.healthSyncEnabled == true,
          settings?.healthSyncFood == true,
          entry.source != HealthSyncSource.healthKit
    else { return }
    HealthExportQueue.shared.enqueue(entryID: entry.id) {
        try await healthSync?.deleteSamples(entryID: entry.id)
        if entry.isEaten {
            try await healthSync?.saveFood(entry)
        }
    }
}
