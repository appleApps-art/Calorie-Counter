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
        let previousLevel = state.level
        state.totalXP += event.amount
        if state.level != previousLevel {
            Analytics.tracker.track(.levelReached(level: state.level.number))
            Analytics.tracker.setUserProperties(["level": state.level.number, "xp": state.totalXP])
        }
        state.updatedAt = date
        try rewardsRepository.save(state)
        _ = try evaluateBadgesUseCase.execute()
    }

    /// Takes back the XP a diary entry earned when the user deletes it. Otherwise adding and
    /// removing the same glass of water or meal could be repeated for levels.
    func revoke(relatedID: UUID, date: Date = Date()) throws {
        let removed = try rewardsRepository.removeEvents(relatedID: relatedID)
        guard !removed.isEmpty else { return }
        var state = try rewardsRepository.fetchState()
        state.totalXP = max(0, state.totalXP - removed.reduce(0) { $0 + $1.amount })
        state.updatedAt = date
        try rewardsRepository.save(state)
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
        let current = BadgeStreakMath.consecutiveDays(in: days, now: now, calendar: calendar)

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
    var onNewlyUnlocked: (([BadgeProgress]) -> Void)?

    private let rewardsRepository: RewardsRepositoryProtocol
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let weightEntryRepository: WeightEntryRepositoryProtocol
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol
    private let progressPhotoRepository: ProgressPhotoRepositoryProtocol
    private let userGoalsRepository: UserGoalsRepositoryProtocol

    init(
        rewardsRepository: RewardsRepositoryProtocol,
        foodEntryRepository: FoodEntryRepositoryProtocol,
        waterEntryRepository: WaterEntryRepositoryProtocol,
        weightEntryRepository: WeightEntryRepositoryProtocol,
        workoutEntryRepository: WorkoutEntryRepositoryProtocol,
        progressPhotoRepository: ProgressPhotoRepositoryProtocol,
        userGoalsRepository: UserGoalsRepositoryProtocol
    ) {
        self.rewardsRepository = rewardsRepository
        self.foodEntryRepository = foodEntryRepository
        self.waterEntryRepository = waterEntryRepository
        self.weightEntryRepository = weightEntryRepository
        self.workoutEntryRepository = workoutEntryRepository
        self.progressPhotoRepository = progressPhotoRepository
        self.userGoalsRepository = userGoalsRepository
    }

    @discardableResult
    func execute(now: Date = Date(), calendar: Calendar = .current) throws -> [BadgeProgress] {
        let start = calendar.date(byAdding: .year, value: -2, to: now) ?? now
        let foods = try foodEntryRepository.fetchEntries(from: start, to: now)
        let waters = try waterEntryRepository.fetchEntries(from: start, to: now)
        let weights = try weightEntryRepository.fetchEntries()
        let workouts = try workoutEntryRepository.fetchEntries()
        let photos = try progressPhotoRepository.fetchAll()
        let events = try rewardsRepository.fetchEvents()
        let goals = try userGoalsRepository.fetchGoals()
        let progress = BadgeProgressCalculator.progress(
            foods: foods,
            waters: waters,
            weights: weights,
            workouts: workouts,
            photos: photos,
            events: events,
            goals: goals,
            now: now,
            calendar: calendar
        )

        var latest = try rewardsRepository.fetchState()
        // A badge, once earned, stays earned: a missed day starts a new run, it does not take the
        // badge away. A celebrated (seen) badge was complete when it was shown.
        let earned = Set(latest.unlockedBadgeIDs)
            .union(latest.seenBadgeIDs)
            .union(progress.filter(\.isComplete).map(\.badge.rawValue))
        let shown = progress.map { item in
            earned.contains(item.badge.rawValue)
                ? BadgeProgress(badge: item.badge, current: item.goal, goal: item.goal)
                : item
        }
        let previouslyEarned = Set(latest.unlockedBadgeIDs).union(latest.seenBadgeIDs)
        for badge in RewardBadge.allCases where earned.contains(badge.rawValue) && !previouslyEarned.contains(badge.rawValue) {
            Analytics.tracker.track(.badgeUnlocked(badge: badge.rawValue))
        }
        latest.unlockedBadgeIDs = RewardBadge.allCases.map(\.rawValue).filter(earned.contains)
        latest.updatedAt = now
        try rewardsRepository.save(latest)
        let unseen = BadgeProgress.awaitingCelebration(in: shown, seenIDs: latest.seenBadgeIDs)
        if !unseen.isEmpty {
            onNewlyUnlocked?(unseen)
        }
        return shown
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

final class MarkBadgeSeenUseCase {
    private let rewardsRepository: RewardsRepositoryProtocol

    init(rewardsRepository: RewardsRepositoryProtocol) {
        self.rewardsRepository = rewardsRepository
    }

    func execute(_ badge: RewardBadge) throws {
        var state = try rewardsRepository.fetchState()
        let id = badge.rawValue
        guard !state.seenBadgeIDs.contains(id) else { return }
        state.seenBadgeIDs.append(id)
        state.updatedAt = Date()
        try rewardsRepository.save(state)
    }

    func isSeen(_ badge: RewardBadge) -> Bool {
        let ids = (try? rewardsRepository.fetchState().seenBadgeIDs) ?? []
        return ids.contains(badge.rawValue)
    }
}

final class FetchRewardsScreenUseCase {
    private let evaluateStreakUseCase: EvaluateStreakUseCase
    private let evaluateBadgesUseCase: EvaluateBadgesUseCase
    private let rewardsRepository: RewardsRepositoryProtocol

    init(
        evaluateStreakUseCase: EvaluateStreakUseCase,
        evaluateBadgesUseCase: EvaluateBadgesUseCase,
        rewardsRepository: RewardsRepositoryProtocol
    ) {
        self.evaluateStreakUseCase = evaluateStreakUseCase
        self.evaluateBadgesUseCase = evaluateBadgesUseCase
        self.rewardsRepository = rewardsRepository
    }

    func execute(now: Date = Date()) throws -> RewardsScreenState {
        _ = try evaluateStreakUseCase.execute(now: now)
        let badges = try evaluateBadgesUseCase.execute(now: now)
        let state = try rewardsRepository.fetchState()
        return RewardsScreenState(xp: state.totalXP, level: state.level, badges: badges)
    }
}

enum BadgeStreakMath {
    static func consecutiveDays(in days: Set<Date>, now: Date, calendar: Calendar) -> Int {
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
        return current
    }

    static func consecutiveWeeks(in weeks: Set<Date>, now: Date, calendar: Calendar) -> Int {
        var current = 0
        var cursor = weekStart(now, calendar: calendar)
        if !weeks.contains(cursor) {
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }
        while weeks.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return current
    }

    static func consecutiveWeekendDays(in days: Set<Date>, now: Date, calendar: Calendar) -> Int {
        var cursor = calendar.startOfDay(for: now)
        cursor = previousWeekendDay(from: cursor, calendar: calendar)
        if !days.contains(cursor) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = previousWeekendDay(from: previous, calendar: calendar)
        }
        var current = 0
        while days.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousWeekendDay(from: previous, calendar: calendar)
        }
        return current
    }

    private static func previousWeekendDay(from date: Date, calendar: Calendar) -> Date {
        var cursor = calendar.startOfDay(for: date)
        for _ in 0..<8 {
            let weekday = calendar.component(.weekday, from: cursor)
            if weekday == 1 || weekday == 7 { return cursor }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { return cursor }
            cursor = previous
        }
        return cursor
    }

    static func weekStart(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}

enum BadgeProgressCalculator {
    static func progress(
        foods: [FoodEntry],
        waters: [WaterEntry],
        weights: [WeightEntry],
        workouts: [WorkoutEntry],
        photos: [ProgressPhoto],
        events: [XPEvent],
        goals: UserGoals,
        now: Date,
        calendar: Calendar
    ) -> [BadgeProgress] {
        let foodByDay = Dictionary(grouping: foods, by: { calendar.startOfDay(for: $0.date) })
        // Diary entries carry their day, not the moment they were logged (added meals sit at
        // midnight), so the time-of-day badges read when the food was actually logged.
        let loggedAt = Dictionary(
            events.filter { $0.kind == .food }.compactMap { event in event.relatedID.map { ($0, event.date) } },
            uniquingKeysWith: { min($0, $1) }
        )
        func loggedOnItsDay(_ entry: FoodEntry, _ day: Date) -> Date? {
            // Without an XP event, a timestamp of exactly midnight is only the entry's day, not a time.
            let time = loggedAt[entry.id] ?? (entry.date == calendar.startOfDay(for: entry.date) ? nil : entry.date)
            guard let time, calendar.isDate(time, inSameDayAs: day) else { return nil }
            return time
        }
        let waterByDay = Dictionary(grouping: waters, by: { calendar.startOfDay(for: $0.date) })
        let foodDays = Set(foodByDay.keys)
        let hydrationDays = Set(waterByDay.compactMap { day, entries -> Date? in
            let total = entries.reduce(0) { $0 + $1.amountMilliliters }
            return total >= goals.waterTargetMilliliters ? day : nil
        })
        let proteinDays = Set(foodByDay.compactMap { day, entries -> Date? in
            entries.filter(\.isEaten).reduce(0) { $0 + $1.protein } >= goals.proteinTarget ? day : nil
        })
        let fiberDays = Set(foodByDay.compactMap { day, entries -> Date? in
            entries.filter(\.isEaten).reduce(0) { $0 + $1.fiber } >= goals.fiberTarget ? day : nil
        })
        let macroDays = Set(foodByDay.compactMap { day, entries -> Date? in
            isBalanced(entries) ? day : nil
        })
        let earlyBirdDays = Set(foodByDay.compactMap { day, entries -> Date? in
            entries.contains(where: { entry in
                loggedOnItsDay(entry, day).map { calendar.component(.hour, from: $0) < 9 } ?? false
            }) ? day : nil
        })
        let lateHour = 21
        let eveningIsOver = calendar.component(.hour, from: now) >= lateHour
        let noLateSnackDays = Set(foodByDay.compactMap { day, entries -> Date? in
            guard !entries.isEmpty else { return nil }
            // Today can still end with a late snack until the evening is over.
            if calendar.isDate(day, inSameDayAs: now), !eveningIsOver { return nil }
            let lateSnack = entries.contains { entry in
                guard entry.mealType == .snacks, let time = loggedOnItsDay(entry, day) else { return false }
                return calendar.component(.hour, from: time) >= lateHour
            }
            return lateSnack ? nil : day
        })
        let explorerDays = Set(foodByDay.compactMap { day, entries -> Date? in
            Set(entries.map(\.name)).count >= 3 ? day : nil
        })
        let weekendDays: Set<Date> = {
            let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.date) })
            return foodDays.union(workoutDays).filter { day in
                let weekday = calendar.component(.weekday, from: day)
                return weekday == 1 || weekday == 7
            }
        }()
        let swapCount = events.filter { $0.kind == .foodSwap }.count
        let photoWeeks = Set(photos.map { BadgeStreakMath.weekStart($0.date, calendar: calendar) })
        let weightWeeks = Set(weights.map { BadgeStreakMath.weekStart($0.date, calendar: calendar) })

        return RewardBadge.allCases.map { badge in
            let raw: Int
            switch badge {
            case .mealTrackerMaster:
                raw = BadgeStreakMath.consecutiveDays(in: foodDays, now: now, calendar: calendar)
            case .hydrationHero:
                raw = BadgeStreakMath.consecutiveDays(in: hydrationDays, now: now, calendar: calendar)
            case .consistentWeigher:
                raw = BadgeStreakMath.consecutiveWeeks(in: weightWeeks, now: now, calendar: calendar)
            case .macroBalancer:
                raw = BadgeStreakMath.consecutiveDays(in: macroDays, now: now, calendar: calendar)
            case .fiberChampion:
                raw = BadgeStreakMath.consecutiveDays(in: fiberDays, now: now, calendar: calendar)
            case .weekendWarrior:
                raw = BadgeStreakMath.consecutiveWeekendDays(in: weekendDays, now: now, calendar: calendar)
            case .proteinMaster:
                raw = BadgeStreakMath.consecutiveDays(in: proteinDays, now: now, calendar: calendar)
            case .earlyBirdLogger:
                raw = BadgeStreakMath.consecutiveDays(in: earlyBirdDays, now: now, calendar: calendar)
            case .smartChoice:
                raw = swapCount
            case .visualJourney:
                raw = BadgeStreakMath.consecutiveWeeks(in: photoWeeks, now: now, calendar: calendar)
            case .noLateSnacks:
                raw = BadgeStreakMath.consecutiveDays(in: noLateSnackDays, now: now, calendar: calendar)
            case .nutrientExplorer:
                raw = BadgeStreakMath.consecutiveDays(in: explorerDays, now: now, calendar: calendar)
            }
            return BadgeProgress(badge: badge, current: min(raw, badge.goal), goal: badge.goal)
        }
    }

    private static func isBalanced(_ entries: [FoodEntry]) -> Bool {
        let eaten = entries.filter(\.isEaten)
        guard !eaten.isEmpty else { return false }
        let facts = NutritionFactsCalculator.facts(
            calories: eaten.reduce(0) { $0 + $1.calories },
            protein: eaten.reduce(0) { $0 + $1.protein },
            carbs: eaten.reduce(0) { $0 + $1.carbs },
            fats: eaten.reduce(0) { $0 + $1.fats },
            fiber: eaten.reduce(0) { $0 + $1.fiber },
            sugar: eaten.reduce(0) { $0 + $1.sugar },
            sodium: eaten.reduce(0) { $0 + $1.sodium }
        )
        return facts.badges.contains(.balanced)
    }
}
