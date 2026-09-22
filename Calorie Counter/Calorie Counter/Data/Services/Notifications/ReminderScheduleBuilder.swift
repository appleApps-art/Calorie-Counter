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
    /// Meal, water, weight and streak reminders cover today and tomorrow only. The schedule is
    /// rebuilt every time the app opens, so someone who uses it daily never runs out; someone who
    /// stopped opening it stops getting three meal pings a day and hears the comeback note instead.
    static let dailyHorizonDays = 2
    /// Days after the last visit on which a comeback note goes out, if the app is still unopened.
    static let comebackDayOffsets = [2, 4, 7]
    /// The weekly weigh-in: Monday (Gregorian weekday 2).
    static let weighInWeekday = 2
    /// Kinds that are not daily and are planned on their own below.
    private static let separatelyPlanned: Set<ReminderKind> = [.water, .weight, .comeback]

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
        let days = min(max(1, horizonDays), Self.dailyHorizonDays)

        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else {
                continue
            }
            let isToday = calendar.isDate(day, inSameDayAs: now)

            for preference in preferences
            where preference.isEnabled && !Self.separatelyPlanned.contains(preference.kind) {
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

        drafts += try weeklyWeighInDrafts(preferences: preferences, now: now, calendar: calendar)
        drafts += comebackDrafts(preferences: preferences, now: now, calendar: calendar)
        return drafts
    }

    /// One reminder on the coming Monday, unless the user weighed in over the last few days.
    private func weeklyWeighInDrafts(
        preferences: [ReminderPreference],
        now: Date,
        calendar: Calendar
    ) throws -> [ScheduledReminderDraft] {
        guard let preference = preferences.first(where: { $0.kind == .weight && $0.isEnabled }),
              let time = preference.times.first else { return [] }
        let today = calendar.startOfDay(for: now)
        let fireDate = (0..<8).lazy
            .compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .filter { calendar.component(.weekday, from: $0) == Self.weighInWeekday }
            .compactMap { time.date(on: $0, calendar: calendar) }
            .first { $0 > now }
        guard let fireDate else { return [] }
        let fireDay = calendar.startOfDay(for: fireDate)
        for offset in 1...3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: fireDay),
                  day <= now else { continue }
            if try !weightEntryRepository.fetchEntries(for: day).isEmpty { return [] }
        }
        if calendar.isDate(fireDay, inSameDayAs: now), try !weightEntryRepository.fetchEntries(for: now).isEmpty {
            return []
        }
        let copy = copy(for: .weight, slotIndex: 0)
        return [ScheduledReminderDraft(
            identifier: [LocalNotificationScheduler.identifierPrefix, ReminderKind.weight.rawValue, "weekly"]
                .joined(separator: "."),
            kind: .weight,
            fireDate: fireDate,
            title: copy.title,
            body: copy.body
        )]
    }

    /// Opening the app reschedules everything, so these only ever fire after days of absence.
    private func comebackDrafts(
        preferences: [ReminderPreference],
        now: Date,
        calendar: Calendar
    ) -> [ScheduledReminderDraft] {
        guard let preference = preferences.first(where: { $0.kind == .comeback && $0.isEnabled }),
              let time = preference.times.first else { return [] }
        let today = calendar.startOfDay(for: now)
        return Self.comebackDayOffsets.enumerated().compactMap { index, offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fireDate = time.date(on: day, calendar: calendar),
                  fireDate > now else { return nil }
            let copy = copy(for: .comeback, slotIndex: index)
            return ScheduledReminderDraft(
                identifier: [
                    LocalNotificationScheduler.identifierPrefix,
                    ReminderKind.comeback.rawValue,
                    "\(offset)"
                ].joined(separator: "."),
                kind: .comeback,
                fireDate: fireDate,
                title: copy.title,
                body: copy.body
            )
        }
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
        case .comeback:
            return false
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
        case .comeback:
            // A different note each time, so the second and third do not read like a repeat.
            let notes = [
                (L10n.tr("reminder.comeback.title1"), L10n.tr("reminder.comeback.body1")),
                (L10n.tr("reminder.comeback.title2"), L10n.tr("reminder.comeback.body2")),
                (L10n.tr("reminder.comeback.title3"), L10n.tr("reminder.comeback.body3"))
            ]
            return notes[min(slotIndex, notes.count - 1)]
        }
    }
}
