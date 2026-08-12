import Foundation

final class AwardXPUseCase {
    private let rewardsRepository: RewardsRepositoryProtocol
    private let evaluateBadgesUseCase: EvaluateBadgesUseCase

    init(
        rewardsRepository: RewardsRepositoryProtocol,
        evaluateBadgesUseCase: EvaluateBadgesUseCase
    ) {
        self.rewardsRepository = rewardsRepository
        self.evaluateBadgesUseCase = evaluateBadgesUseCase
    }

    func execute(kind: XPEventKind, relatedID: UUID? = nil, date: Date = Date()) throws {
        let event = XPEvent(
            id: UUID(),
            kind: kind,
            amount: kind.xpAmount,
            date: date,
            relatedID: relatedID
        )
        try rewardsRepository.append(event)
        var state = try rewardsRepository.fetchState()
        state.totalXP += event.amount
        state.updatedAt = date
        try rewardsRepository.save(state)
        try evaluateBadgesUseCase.execute()
    }
}

final class EvaluateStreakUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let rewardsRepository: RewardsRepositoryProtocol

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        rewardsRepository: RewardsRepositoryProtocol
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.rewardsRepository = rewardsRepository
    }

    func execute(now: Date = Date(), calendar: Calendar = .current) throws -> StreakSnapshot {
        let start = calendar.date(byAdding: .day, value: -400, to: calendar.startOfDay(for: now)) ?? now
        let entries = try foodEntryRepository.fetchEntries(from: start, to: now)
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) })
        var current = 0
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while days.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        var longest = 0
        var run = 0
        let sorted = days.sorted()
        var previousDay: Date?
        for day in sorted {
            if let previousDay, calendar.dateComponents([.day], from: previousDay, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previousDay = day
        }

        var state = try rewardsRepository.fetchState()
        state.currentStreak = current
        state.longestStreak = max(state.longestStreak, longest)
        state.lastFoodLogDay = days.max()
        state.updatedAt = now
        try rewardsRepository.save(state)
        return StreakSnapshot(current: current, longest: state.longestStreak, lastFoodLogDay: state.lastFoodLogDay)
    }
}

final class EvaluateBadgesUseCase {
    private let rewardsRepository: RewardsRepositoryProtocol
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let weightEntryRepository: WeightEntryRepositoryProtocol
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol
    private let progressPhotoRepository: ProgressPhotoRepositoryProtocol

    init(
        rewardsRepository: RewardsRepositoryProtocol,
        foodEntryRepository: FoodEntryRepositoryProtocol,
        waterEntryRepository: WaterEntryRepositoryProtocol,
        weightEntryRepository: WeightEntryRepositoryProtocol,
        workoutEntryRepository: WorkoutEntryRepositoryProtocol,
        progressPhotoRepository: ProgressPhotoRepositoryProtocol
    ) {
        self.rewardsRepository = rewardsRepository
        self.foodEntryRepository = foodEntryRepository
        self.waterEntryRepository = waterEntryRepository
        self.weightEntryRepository = weightEntryRepository
        self.workoutEntryRepository = workoutEntryRepository
        self.progressPhotoRepository = progressPhotoRepository
    }

    func execute(now: Date = Date()) throws {
        var state = try rewardsRepository.fetchState()
        var unlocked = Set(state.unlockedBadgeIDs)
        let events = try rewardsRepository.fetchEvents()
        let start = Calendar.current.date(byAdding: .year, value: -2, to: now) ?? now
        let foods = try foodEntryRepository.fetchEntries(from: start, to: now)
        let waters = try waterEntryRepository.fetchEntries(from: start, to: now)
        let weights = try weightEntryRepository.fetchEntries()
        let workouts = try workoutEntryRepository.fetchEntries()
        let photos = try progressPhotoRepository.fetchAll()

        if !foods.isEmpty { unlocked.insert(RewardBadge.firstMeal.rawValue) }
        if foods.count >= 30 { unlocked.insert(RewardBadge.mealTrackerMaster.rawValue) }
        if waters.count >= 14 { unlocked.insert(RewardBadge.hydrationHero.rawValue) }
        if !weights.isEmpty { unlocked.insert(RewardBadge.weightLogger.rawValue) }
        if state.currentStreak >= 7 { unlocked.insert(RewardBadge.sevenDayStreak.rawValue) }
        if state.currentStreak >= 14 { unlocked.insert(RewardBadge.fourteenDayStreak.rawValue) }
        if events.contains(where: { $0.kind == .foodSwap }) { unlocked.insert(RewardBadge.swapStarter.rawValue) }
        if !photos.isEmpty { unlocked.insert(RewardBadge.photoProgress.rawValue) }
        if !workouts.isEmpty { unlocked.insert(RewardBadge.workoutSpark.rawValue) }
        if foods.contains(where: { $0.protein >= 30 }) { unlocked.insert(RewardBadge.proteinPro.rawValue) }
        if foods.contains(where: { Calendar.current.component(.hour, from: $0.date) < 9 }) {
            unlocked.insert(RewardBadge.earlyBird.rawValue)
        }
        let todayFoods = foods.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
        if !todayFoods.isEmpty {
            let facts = NutritionFactsCalculator.facts(
                calories: todayFoods.reduce(0) { $0 + $1.calories },
                protein: todayFoods.reduce(0) { $0 + $1.protein },
                carbs: todayFoods.reduce(0) { $0 + $1.carbs },
                fats: todayFoods.reduce(0) { $0 + $1.fats },
                fiber: todayFoods.reduce(0) { $0 + $1.fiber },
                sugar: todayFoods.reduce(0) { $0 + $1.sugar },
                sodium: todayFoods.reduce(0) { $0 + $1.sodium }
            )
            if facts.badges.contains(.balanced) {
                unlocked.insert(RewardBadge.balancedDay.rawValue)
            }
        }

        state.unlockedBadgeIDs = RewardBadge.allCases.map(\.rawValue).filter { unlocked.contains($0) }
        state.updatedAt = now
        try rewardsRepository.save(state)
    }
}

final class FetchRewardStateUseCase {
    private let rewardsRepository: RewardsRepositoryProtocol

    init(rewardsRepository: RewardsRepositoryProtocol) {
        self.rewardsRepository = rewardsRepository
    }

    func execute() throws -> RewardState {
        try rewardsRepository.fetchState()
    }
}
