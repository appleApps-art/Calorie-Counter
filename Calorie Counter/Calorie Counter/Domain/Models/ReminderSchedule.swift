import Foundation

enum ReminderKind: String, Codable, CaseIterable, Equatable {
    case breakfast
    case lunch
    case dinner
    case water
    case weight
    case dailyStreak
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
                times: [ReminderTimeOfDay(hour: 8, minute: 0)],
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
                kind: .water,
                isEnabled: true,
                times: [
                    ReminderTimeOfDay(hour: 10, minute: 30),
                    ReminderTimeOfDay(hour: 15, minute: 0),
                    ReminderTimeOfDay(hour: 18, minute: 30),
                ],
                usesAdaptiveTime: false
            ),
            ReminderPreference(
                kind: .weight,
                isEnabled: true,
                times: [ReminderTimeOfDay(hour: 7, minute: 30)],
                usesAdaptiveTime: false
            ),
            ReminderPreference(
                kind: .dailyStreak,
                isEnabled: true,
                times: [ReminderTimeOfDay(hour: 21, minute: 0)],
                usesAdaptiveTime: false
            ),
        ]
    }
}

struct ScheduledReminderDraft: Equatable {
    let identifier: String
    let kind: ReminderKind
    let fireDate: Date
    let title: String
    let body: String
}
