import Foundation

struct ReminderHabitSnapshot: Equatable {
    var preferences: [ReminderPreference]
    var didApplyAdaptiveUpdates: Bool
}

protocol ReminderHabitAnalyzing {
    func analyze(
        configuration: ReminderScheduleConfiguration,
        now: Date,
        calendar: Calendar
    ) throws -> ReminderHabitSnapshot
}

final class ReminderHabitAnalyzer: ReminderHabitAnalyzing {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let weightEntryRepository: WeightEntryRepositoryProtocol

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        waterEntryRepository: WaterEntryRepositoryProtocol,
        weightEntryRepository: WeightEntryRepositoryProtocol
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.waterEntryRepository = waterEntryRepository
        self.weightEntryRepository = weightEntryRepository
    }

    func analyze(
        configuration: ReminderScheduleConfiguration,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ReminderHabitSnapshot {
        let lookback = max(configuration.lookbackDays, configuration.minimumRegularDays)
        let start = calendar.date(byAdding: .day, value: -lookback, to: calendar.startOfDay(for: now)) ?? now
        let end = now

        let foodEntries = try foodEntryRepository.fetchEntries(from: start, to: end)
        let waterEntries = try waterEntryRepository.fetchEntries(from: start, to: end)
        let weightEntries = try weightEntryRepository.fetchEntries(from: start, to: end)

        var updated = configuration.preferences
        var didApply = false
        let minDays = configuration.minimumRegularDays

        for index in updated.indices {
            let kind = updated[index].kind
            let learned: [ReminderTimeOfDay]?
            switch kind {
            case .breakfast:
                learned = learnedMealTimes(
                    mealType: .breakfast,
                    entries: foodEntries,
                    minDays: minDays,
                    calendar: calendar
                ).map { [$0] }
            case .lunch:
                learned = learnedMealTimes(
                    mealType: .lunch,
                    entries: foodEntries,
                    minDays: minDays,
                    calendar: calendar
                ).map { [$0] }
            case .dinner:
                learned = learnedMealTimes(
                    mealType: .dinner,
                    entries: foodEntries,
                    minDays: minDays,
                    calendar: calendar
                ).map { [$0] }
            case .water:
                learned = learnedWaterTimes(
                    entries: waterEntries,
                    minDays: minDays,
                    calendar: calendar
                )
            case .weight:
                learned = learnedWeightTimes(
                    entries: weightEntries,
                    minDays: minDays,
                    calendar: calendar
                ).map { [$0] }
            case .dailyStreak:
                learned = learnedStreakTime(
                    entries: foodEntries,
                    minDays: minDays,
                    calendar: calendar
                ).map { [$0] }
            }

            guard let times = learned, !times.isEmpty else { continue }
            if updated[index].times != times || updated[index].usesAdaptiveTime == false {
                updated[index].times = times
                updated[index].usesAdaptiveTime = true
                didApply = true
            }
        }

        return ReminderHabitSnapshot(preferences: updated, didApplyAdaptiveUpdates: didApply)
    }

    private func learnedMealTimes(
        mealType: MealType,
        entries: [FoodEntry],
        minDays: Int,
        calendar: Calendar
    ) -> ReminderTimeOfDay? {
        let filtered = entries.filter { $0.mealType == mealType }
        let firstPerDay = firstEntryTimePerDay(dates: filtered.map(\.date), calendar: calendar)
        guard firstPerDay.count >= minDays else { return nil }
        let median = medianTime(firstPerDay)
        return nudgeEarlier(median, minutes: 15)
    }

    private func learnedWaterTimes(
        entries: [WaterEntry],
        minDays: Int,
        calendar: Calendar
    ) -> [ReminderTimeOfDay]? {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        guard grouped.count >= minDays else { return nil }

        var firstTimes: [ReminderTimeOfDay] = []
        var midTimes: [ReminderTimeOfDay] = []
        var lastTimes: [ReminderTimeOfDay] = []

        for dayEntries in grouped.values {
            let sorted = dayEntries.map(\.date).sorted()
            guard let first = sorted.first else { continue }
            firstTimes.append(ReminderTimeOfDay.from(date: first, calendar: calendar))
            if sorted.count >= 2 {
                midTimes.append(ReminderTimeOfDay.from(date: sorted[sorted.count / 2], calendar: calendar))
            }
            if let last = sorted.last, sorted.count >= 3 {
                lastTimes.append(ReminderTimeOfDay.from(date: last, calendar: calendar))
            }
        }

        guard firstTimes.count >= minDays else { return nil }

        var times = [nudgeEarlier(medianTime(firstTimes), minutes: 20)]
        if midTimes.count >= minDays {
            times.append(medianTime(midTimes))
        } else {
            times.append(ReminderTimeOfDay(hour: 15, minute: 0))
        }
        if lastTimes.count >= minDays {
            times.append(medianTime(lastTimes))
        } else {
            times.append(ReminderTimeOfDay(hour: 18, minute: 30))
        }
        return uniqueSorted(times)
    }

    private func learnedWeightTimes(
        entries: [WeightEntry],
        minDays: Int,
        calendar: Calendar
    ) -> ReminderTimeOfDay? {
        let firstPerDay = firstEntryTimePerDay(dates: entries.map(\.date), calendar: calendar)
        guard firstPerDay.count >= minDays else { return nil }
        return nudgeEarlier(medianTime(firstPerDay), minutes: 10)
    }

    private func learnedStreakTime(
        entries: [FoodEntry],
        minDays: Int,
        calendar: Calendar
    ) -> ReminderTimeOfDay? {
        let lastPerDay = lastEntryTimePerDay(dates: entries.map(\.date), calendar: calendar)
        guard lastPerDay.count >= minDays else { return nil }
        let medianLast = medianTime(lastPerDay)
        let candidate = adding(minutes: 90, to: medianLast)
        if candidate.totalMinutes > ReminderTimeOfDay(hour: 22, minute: 30).totalMinutes {
            return ReminderTimeOfDay(hour: 22, minute: 0)
        }
        if candidate.totalMinutes < ReminderTimeOfDay(hour: 19, minute: 0).totalMinutes {
            return ReminderTimeOfDay(hour: 20, minute: 0)
        }
        return candidate
    }

    private func firstEntryTimePerDay(dates: [Date], calendar: Calendar) -> [ReminderTimeOfDay] {
        let grouped = Dictionary(grouping: dates) { calendar.startOfDay(for: $0) }
        return grouped.values.compactMap { dayDates in
            dayDates.min().map { ReminderTimeOfDay.from(date: $0, calendar: calendar) }
        }
    }

    private func lastEntryTimePerDay(dates: [Date], calendar: Calendar) -> [ReminderTimeOfDay] {
        let grouped = Dictionary(grouping: dates) { calendar.startOfDay(for: $0) }
        return grouped.values.compactMap { dayDates in
            dayDates.max().map { ReminderTimeOfDay.from(date: $0, calendar: calendar) }
        }
    }

    private func medianTime(_ values: [ReminderTimeOfDay]) -> ReminderTimeOfDay {
        let sorted = values.map(\.totalMinutes).sorted()
        let mid = sorted[sorted.count / 2]
        return ReminderTimeOfDay(hour: mid / 60, minute: mid % 60)
    }

    private func nudgeEarlier(_ time: ReminderTimeOfDay, minutes: Int) -> ReminderTimeOfDay {
        let total = max(0, time.totalMinutes - minutes)
        return ReminderTimeOfDay(hour: total / 60, minute: total % 60)
    }

    private func adding(minutes: Int, to time: ReminderTimeOfDay) -> ReminderTimeOfDay {
        let total = min(23 * 60 + 59, time.totalMinutes + minutes)
        return ReminderTimeOfDay(hour: total / 60, minute: total % 60)
    }

    private func uniqueSorted(_ times: [ReminderTimeOfDay]) -> [ReminderTimeOfDay] {
        var seen = Set<Int>()
        var result: [ReminderTimeOfDay] = []
        for time in times.sorted(by: { $0.totalMinutes < $1.totalMinutes }) {
            if seen.insert(time.totalMinutes).inserted {
                result.append(time)
            }
        }
        return result
    }
}
