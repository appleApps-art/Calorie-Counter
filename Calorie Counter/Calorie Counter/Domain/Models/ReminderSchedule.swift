import Foundation

enum ReminderKind: String, Codable, CaseIterable, Equatable {
    case breakfast
    case lunch
    case dinner
    /// Kept so saved settings still decode; water reminders are no longer sent.
    case water
    /// Once a week, on Monday morning.
    case weight
    case dailyStreak
    /// Sent only when the user has not opened the app for a few days.
    case comeback
}

struct ReminderTimeOfDay: Codable, Equatable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(23, max(0, hour))
        self.minute = min(59, max(0, minute))
    }

    var totalMinutes: Int {
        hour * 60 + minute
    }

    static func from(date: Date, calendar: Calendar = .current) -> ReminderTimeOfDay {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return ReminderTimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    func date(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: calendar.startOfDay(for: day)
        )
    }
}

struct ReminderPreference: Codable, Equatable {
    var kind: ReminderKind
    var isEnabled: Bool
    var times: [ReminderTimeOfDay]
    var usesAdaptiveTime: Bool
}

struct ReminderScheduleConfiguration: Codable, Equatable {
    var preferences: [ReminderPreference]
    var minimumRegularDays: Int
    var lookbackDays: Int
    var scheduleHorizonDays: Int
    var lastAdaptiveEvaluationAt: Date?

    static let `default` = ReminderScheduleConfiguration(
        preferences: ReminderScheduleConfiguration.defaultPreferences,
        minimumRegularDays: 7,
        lookbackDays: 14,
        scheduleHorizonDays: 14,
        lastAdaptiveEvaluationAt: nil
    )

    static var defaultPreferences: [ReminderPreference] {
        [
            ReminderPreference(
                kind: .breakfast,
                isEnabled: true,
                times: [ReminderTimeOfDay(hour: 9, minute: 0)],
                usesAdaptiveTime: false
            ),
            ReminderPreference(
                kind: .lunch,
                isEnabled: true,
                times: [ReminderTimeOfDay(hour: 13, minute: 0)],
                usesAdaptiveTime: false
            ),
            ReminderPreference(
                kind: .dinner,
                isEnabled: true,
                times: [ReminderTimeOfDay(hour: 19, minute: 0)],
                usesAdaptiveTime: false
            ),
            ReminderPreference(
                kind: .weight,
                isEnabled: true,
                // 7:30 was too early; 10:00 also stays clear of Monday's 9:00 breakfast reminder.
                times: [ReminderTimeOfDay(hour: 10, minute: 0)],
                usesAdaptiveTime: false
            ),
            ReminderPreference(
                kind: .dailyStreak,
                isEnabled: true,
                times: [ReminderTimeOfDay(hour: 21, minute: 0)],
                usesAdaptiveTime: false
            ),
            ReminderPreference(
                kind: .comeback,
                isEnabled: true,
                times: [ReminderTimeOfDay(hour: 19, minute: 0)],
                usesAdaptiveTime: false
            ),
        ]
    }

    /// A configuration saved before a reminder kind existed gets that kind with its default,
    /// so an update reaches people who installed the app earlier.
    func fillingMissingDefaults() -> ReminderScheduleConfiguration {
        var copy = self
        for preference in Self.defaultPreferences where !copy.preferences.contains(where: { $0.kind == preference.kind }) {
            copy.preferences.append(preference)
        }
        // Times that were only ever the old defaults follow the new ones; a learned time stays.
        for (index, preference) in copy.preferences.enumerated() where !preference.usesAdaptiveTime {
            guard let retired = Self.retiredDefaultTimes[preference.kind], preference.times == [retired],
                  let current = Self.defaultPreferences.first(where: { $0.kind == preference.kind }) else { continue }
            copy.preferences[index].times = current.times
        }
        return copy
    }

    private static let retiredDefaultTimes: [ReminderKind: ReminderTimeOfDay] = [
        .breakfast: ReminderTimeOfDay(hour: 8, minute: 0),
        .weight: ReminderTimeOfDay(hour: 7, minute: 30)
    ]
}

struct ScheduledReminderDraft: Equatable {
    let identifier: String
    let kind: ReminderKind
    let fireDate: Date
    let title: String
    let body: String
}
