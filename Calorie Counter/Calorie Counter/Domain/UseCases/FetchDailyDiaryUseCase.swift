import Foundation

final class FetchDailyDiaryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let userGoalsRepository: UserGoalsRepositoryProtocol
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol?

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        waterEntryRepository: WaterEntryRepositoryProtocol,
        userGoalsRepository: UserGoalsRepositoryProtocol,
        workoutEntryRepository: WorkoutEntryRepositoryProtocol? = nil
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.waterEntryRepository = waterEntryRepository
        self.userGoalsRepository = userGoalsRepository
        self.workoutEntryRepository = workoutEntryRepository
    }

    func execute(for date: Date = Date()) throws -> DailyDiarySummary {
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
            goals: goals
        )
    }
}
