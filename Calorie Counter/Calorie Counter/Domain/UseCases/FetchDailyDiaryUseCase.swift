import Foundation

final class FetchDailyDiaryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let userGoalsRepository: UserGoalsRepositoryProtocol
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol?
    private let healthActivityStore: HealthDailyActivityStoring?
    private let refreshGoals: (() throws -> Void)?

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        waterEntryRepository: WaterEntryRepositoryProtocol,
        userGoalsRepository: UserGoalsRepositoryProtocol,
        workoutEntryRepository: WorkoutEntryRepositoryProtocol? = nil,
        healthActivityStore: HealthDailyActivityStoring? = nil,
        refreshGoals: (() throws -> Void)? = nil
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.waterEntryRepository = waterEntryRepository
        self.userGoalsRepository = userGoalsRepository
        self.workoutEntryRepository = workoutEntryRepository
        self.healthActivityStore = healthActivityStore
        self.refreshGoals = refreshGoals
    }

    func execute(for date: Date = Date()) throws -> DailyDiarySummary {
        try refreshGoals?()
        let foodEntries = try foodEntryRepository.fetchEntries(for: date)
        let waterEntries = try waterEntryRepository.fetchEntries(for: date)
        let goals = try userGoalsRepository.fetchGoals()
        let waterMilliliters = waterEntries.reduce(0) { $0 + $1.amountMilliliters }
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let workouts = try workoutEntryRepository?.fetchEntries(from: start, to: end) ?? []

        return DailyDiarySummary(
            date: date,
            foodEntries: foodEntries,
            waterEntries: waterEntries,
            workouts: workouts,
            waterMilliliters: waterMilliliters,
            goals: goals,
            healthActivity: try healthActivityStore?.fetch(from: start, to: end).first
        )
    }
}
