import Foundation

protocol ReminderScheduleBuilding {
    func buildDrafts(
        preferences: [ReminderPreference],
        horizonDays: Int,
        now: Date,
        calendar: Calendar
    ) throws -> [ScheduledReminderDraft]
}

final class ReminderScheduleBuilder: ReminderScheduleBuilding {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let weightEntryRepository: WeightEntryRepositoryProtocol

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        weightEntryRepository: WeightEntryRepositoryProtocol
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.weightEntryRepository = weightEntryRepository
    }

    func buildDrafts(
        preferences: [ReminderPreference],
        horizonDays: Int = 14,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> [ScheduledReminderDraft] {
        let todayFood = try foodEntryRepository.fetchEntries(for: now)
        let todayWeight = try weightEntryRepository.fetchEntries(for: now)

        var drafts: [ScheduledReminderDraft] = []
        let days = max(1, horizonDays)

        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else {
                continue
            }
            let isToday = calendar.isDate(day, inSameDayAs: now)

            for preference in preferences where preference.isEnabled {
                for (slotIndex, time) in preference.times.enumerated() {
                    guard let fireDate = time.date(on: day, calendar: calendar), fireDate > now else {
                        continue
                    }

                    if isToday, shouldSkipToday(
                        kind: preference.kind,
                        food: todayFood,
                        weight: todayWeight
                    ) {
                        continue
                    }

                    let copy = copy(for: preference.kind, slotIndex: slotIndex)
                    let identifier = [
                        LocalNotificationScheduler.identifierPrefix,
                        preference.kind.rawValue,
                        "\(dayOffset)",
                        "\(slotIndex)",
                    ].joined(separator: ".")

                    drafts.append(
                        ScheduledReminderDraft(
                            identifier: identifier,
                            kind: preference.kind,
                            fireDate: fireDate,
                            title: copy.title,
                            body: copy.body
                        )
                    )
                }
            }
        }

        return drafts
    }

    private func shouldSkipToday(
        kind: ReminderKind,
        food: [FoodEntry],
        weight: [WeightEntry]
    ) -> Bool {
        switch kind {
        case .breakfast:
            return food.contains { $0.mealType == .breakfast }
        case .lunch:
            return food.contains { $0.mealType == .lunch }
        case .dinner:
            return food.contains { $0.mealType == .dinner }
        case .water:
            return false
        case .weight:
            return !weight.isEmpty
        case .dailyStreak:
            return !food.isEmpty
        }
    }

    private func copy(for kind: ReminderKind, slotIndex: Int) -> (title: String, body: String) {
        switch kind {
        case .breakfast:
            return (L10n.tr("reminder.breakfast.title"), L10n.tr("reminder.breakfast.body"))
        case .lunch:
            return (L10n.tr("reminder.lunch.title"), L10n.tr("reminder.lunch.body"))
        case .dinner:
            return (L10n.tr("reminder.dinner.title"), L10n.tr("reminder.dinner.body"))
        case .water:
            let bodies = [
                L10n.tr("reminder.water.body1"),
                L10n.tr("reminder.water.body2"),
                L10n.tr("reminder.water.body3"),
            ]
            return (L10n.tr("reminder.water.title"), bodies[min(slotIndex, bodies.count - 1)])
        case .weight:
            return (L10n.tr("reminder.weight.title"), L10n.tr("reminder.weight.body"))
        case .dailyStreak:
            return (L10n.tr("reminder.streak.title"), L10n.tr("reminder.streak.body"))
        }
    }
}
