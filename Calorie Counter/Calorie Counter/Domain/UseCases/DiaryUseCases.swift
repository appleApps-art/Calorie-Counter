import Foundation

final class LogFoodUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let awardXPUseCase: AwardXPUseCase?

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.awardXPUseCase = awardXPUseCase
    }

    func execute(_ entry: FoodEntry) throws -> FoodEntry {
        try foodEntryRepository.save(entry)
        try awardXPUseCase?.execute(kind: .food, relatedID: entry.id)
        return entry
    }

    func execute(from product: FoodProduct, mealType: MealType, date: Date = Date()) throws -> FoodEntry {
        let entry = FoodEntry(
            id: UUID(),
            name: product.brand.map { "\($0) · \(product.name)" } ?? product.name,
            mealType: mealType,
            calories: product.calories ?? 0,
            protein: product.protein ?? 0,
            carbs: product.carbs ?? 0,
            fats: product.fats ?? 0,
            fiber: 0,
            sugar: 0,
            sodium: 0,
            date: date,
            portionGrams: product.unit == "g" ? product.amount : nil,
            source: "search"
        )
        return try execute(entry)
    }
}

final class UpdateFoodEntryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol

    init(foodEntryRepository: FoodEntryRepositoryProtocol) {
        self.foodEntryRepository = foodEntryRepository
    }

    func execute(_ entry: FoodEntry) throws {
        try foodEntryRepository.save(entry)
    }
}

final class DeleteFoodEntryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol

    init(foodEntryRepository: FoodEntryRepositoryProtocol) {
        self.foodEntryRepository = foodEntryRepository
    }

    func execute(id: UUID) throws {
        try foodEntryRepository.delete(id: id)
    }
}

final class ScaleFoodPortionUseCase {
    func execute(entry: FoodEntry, grams: Double) -> FoodEntry {
        entry.scaled(toGrams: grams)
    }
}

final class ReplaceFoodEntryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let awardXPUseCase: AwardXPUseCase?

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.awardXPUseCase = awardXPUseCase
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
            source: replacement.source
        )
        try foodEntryRepository.save(replacement)
        try awardXPUseCase?.execute(kind: .foodSwap, relatedID: targetId)
        return replacement
    }
}

final class DeleteWaterEntryUseCase {
    private let waterEntryRepository: WaterEntryRepositoryProtocol

    init(waterEntryRepository: WaterEntryRepositoryProtocol) {
        self.waterEntryRepository = waterEntryRepository
    }

    func execute(id: UUID) throws {
        try waterEntryRepository.delete(id: id)
    }
}

final class DeleteWorkoutEntryUseCase {
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol

    init(workoutEntryRepository: WorkoutEntryRepositoryProtocol) {
        self.workoutEntryRepository = workoutEntryRepository
    }

    func execute(id: UUID) throws {
        try workoutEntryRepository.delete(id: id)
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

    init(
        weightEntryRepository: WeightEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil,
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil
    ) {
        self.weightEntryRepository = weightEntryRepository
        self.awardXPUseCase = awardXPUseCase
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
    }

    func execute(weightKilograms: Double, date: Date = Date()) throws -> WeightEntry {
        let entry = WeightEntry(id: UUID(), weightKilograms: weightKilograms, date: date)
        try weightEntryRepository.save(entry)
        try awardXPUseCase?.execute(kind: .weight, relatedID: entry.id)
        let settings = appSettingsStore?.settings
        if settings?.healthSyncEnabled == true, settings?.healthSyncWeight == true {
            Task {
                try? await healthSync?.saveWeight(weightKilograms, date: date)
            }
        }
        return entry
    }
}

final class SaveUserGoalsUseCase {
    private let userGoalsRepository: UserGoalsRepositoryProtocol

    init(userGoalsRepository: UserGoalsRepositoryProtocol) {
        self.userGoalsRepository = userGoalsRepository
    }

    func execute(_ goals: UserGoals) throws {
        try userGoalsRepository.save(goals)
    }
}
