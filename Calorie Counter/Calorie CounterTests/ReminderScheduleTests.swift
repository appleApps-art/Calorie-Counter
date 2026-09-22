import XCTest
@testable import Calorie_Counter

final class ReminderScheduleTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Kyiv")!
        return calendar
    }()

    /// Monday morning, before breakfast.
    private lazy var morning = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 7, minute: 0))!

    func testEveryMealHasItsReminderAndAComebackNoteByDefault() {
        let kinds = ReminderScheduleConfiguration.default.preferences.filter(\.isEnabled).map(\.kind)
        for kind in [ReminderKind.breakfast, .lunch, .dinner, .comeback] {
            XCTAssertTrue(kinds.contains(kind), "\(kind) is on out of the box")
        }
    }

    func testPeopleWhoInstalledEarlierGetTheComebackNoteToo() throws {
        let suite = "reminders-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        var old = ReminderScheduleConfiguration.default
        old.preferences.removeAll { $0.kind == .comeback }
        old.preferences[0].isEnabled = false
        defaults.set(try JSONEncoder().encode(old), forKey: "bity.reminders.configuration")

        let loaded = ReminderPreferencesStore(defaults: defaults).configuration
        XCTAssertEqual(loaded.preferences.first { $0.kind == .comeback }?.isEnabled, true)
        XCTAssertEqual(loaded.preferences[0].isEnabled, false, "What the user already chose is kept")
    }

    func testSettingsSavedWithTheOldTimesMoveToTheNewOnes() throws {
        let suite = "reminders-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        var old = ReminderScheduleConfiguration.default
        old.preferences = old.preferences.map { preference in
            var copy = preference
            if preference.kind == .breakfast { copy.times = [ReminderTimeOfDay(hour: 8, minute: 0)] }
            if preference.kind == .weight { copy.times = [ReminderTimeOfDay(hour: 7, minute: 30)] }
            if preference.kind == .lunch {
                copy.times = [ReminderTimeOfDay(hour: 12, minute: 40)]
                copy.usesAdaptiveTime = true
            }
            return copy
        }
        defaults.set(try JSONEncoder().encode(old), forKey: "bity.reminders.configuration")

        let loaded = ReminderPreferencesStore(defaults: defaults).configuration
        XCTAssertEqual(loaded.preferences.first { $0.kind == .breakfast }?.times, [ReminderTimeOfDay(hour: 9, minute: 0)])
        XCTAssertEqual(loaded.preferences.first { $0.kind == .weight }?.times, [ReminderTimeOfDay(hour: 10, minute: 0)])
        XCTAssertEqual(
            loaded.preferences.first { $0.kind == .lunch }?.times, [ReminderTimeOfDay(hour: 12, minute: 40)],
            "A time learned from the user's habits is kept"
        )
    }

    func testNoNotificationUsesALongDash() {
        let keys = [
            "reminder.breakfast.title", "reminder.breakfast.body", "reminder.lunch.title", "reminder.lunch.body",
            "reminder.dinner.title", "reminder.dinner.body", "reminder.weight.title", "reminder.weight.body",
            "reminder.streak.title", "reminder.streak.body",
            "reminder.comeback.title1", "reminder.comeback.body1", "reminder.comeback.title2", "reminder.comeback.body2",
            "reminder.comeback.title3", "reminder.comeback.body3"
        ]
        for key in keys {
            let text = L10n.tr(key)
            XCTAssertNotEqual(text, key, "\(key) is translated")
            XCTAssertFalse(text.contains("—") || text.contains("–"), "\(key): \(text)")
        }
    }

    func testMealRemindersCoverTodayAndTomorrowAndSkipAMealAlreadyLogged() throws {
        let harness = TestHarness()
        try harness.food.save(harness.foodEntry(mealType: .breakfast, date: morning))

        let drafts = try builder(harness).buildDrafts(
            preferences: ReminderScheduleConfiguration.defaultPreferences,
            horizonDays: 14,
            now: morning,
            calendar: calendar
        )

        let meals = drafts.filter { [.breakfast, .lunch, .dinner].contains($0.kind) }
        XCTAssertEqual(meals.filter { $0.kind == .breakfast }.count, 1, "Today's breakfast is logged, so only tomorrow's")
        XCTAssertEqual(meals.filter { $0.kind == .lunch }.count, 2)
        XCTAssertEqual(meals.filter { $0.kind == .dinner }.count, 2)
        let lastDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: morning)))
        XCTAssertTrue(meals.allSatisfy { $0.fireDate < lastDay }, "Nothing daily beyond tomorrow")
        let tomorrowBreakfast = try XCTUnwrap(meals.first { $0.kind == .breakfast })
        XCTAssertEqual(calendar.component(.hour, from: tomorrowBreakfast.fireDate), 9, "Nine in the morning, the user's own time")
        XCTAssertEqual(tomorrowBreakfast.title, L10n.tr("reminder.breakfast.title"))
    }

    func testTheComebackNoteOnlyComesAfterDaysAway() throws {
        let drafts = try builder(TestHarness()).buildDrafts(
            preferences: ReminderScheduleConfiguration.defaultPreferences,
            horizonDays: 14,
            now: morning,
            calendar: calendar
        )

        let comeback = drafts.filter { $0.kind == .comeback }
        let today = calendar.startOfDay(for: morning)
        let days = comeback.map { calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: $0.fireDate)).day }
        XCTAssertEqual(days, [2, 4, 7], "Two, four and seven days after the last visit")
        XCTAssertTrue(comeback.allSatisfy { calendar.component(.hour, from: $0.fireDate) == 19 })
        XCTAssertEqual(Set(comeback.map(\.title)).count, 3, "Each note reads differently")
        XCTAssertEqual(Set(drafts.map(\.identifier)).count, drafts.count, "No request replaces another")
        XCTAssertLessThan(drafts.count, 64, "iOS keeps only 64 pending notifications")
    }

    func testTurningTheComebackNoteOffRemovesIt() throws {
        var preferences = ReminderScheduleConfiguration.defaultPreferences
        if let index = preferences.firstIndex(where: { $0.kind == .comeback }) {
            preferences[index].isEnabled = false
        }
        let drafts = try builder(TestHarness()).buildDrafts(
            preferences: preferences,
            horizonDays: 14,
            now: morning,
            calendar: calendar
        )
        XCTAssertFalse(drafts.contains { $0.kind == .comeback })
    }

    func testNoWaterRemindersEvenForSettingsSavedEarlier() throws {
        var old = ReminderScheduleConfiguration.default.preferences
        old.append(ReminderPreference(
            kind: .water, isEnabled: true,
            times: [ReminderTimeOfDay(hour: 10, minute: 30)], usesAdaptiveTime: false
        ))
        XCTAssertFalse(ReminderScheduleConfiguration.defaultPreferences.contains { $0.kind == .water })
        let drafts = try builder(TestHarness()).buildDrafts(preferences: old, horizonDays: 14, now: morning, calendar: calendar)
        XCTAssertFalse(drafts.contains { $0.kind == .water }, "A saved water setting no longer sends anything")
    }

    func testWeightIsAskedForOnceAWeekOnMonday() throws {
        let tuesday = try XCTUnwrap(nextDate(weekday: 3, hour: 9))
        let drafts = try builder(TestHarness()).buildDrafts(
            preferences: ReminderScheduleConfiguration.defaultPreferences,
            horizonDays: 14,
            now: tuesday,
            calendar: calendar
        )
        let weight = drafts.filter { $0.kind == .weight }
        XCTAssertEqual(weight.count, 1, "One weigh-in, not one a day")
        let fire = try XCTUnwrap(weight.first?.fireDate)
        XCTAssertEqual(calendar.component(.weekday, from: fire), 2, "On Monday")
        XCTAssertEqual(calendar.component(.hour, from: fire), 10, "Not at 7:30 any more")
        XCTAssertEqual(calendar.component(.minute, from: fire), 0)
        XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: tuesday), to: calendar.startOfDay(for: fire)).day, 6)
    }

    func testARecentWeighInSkipsThatWeeksReminder() throws {
        let harness = TestHarness()
        let monday = try XCTUnwrap(nextDate(weekday: 2, hour: 6))
        let saturday = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: monday))
        try harness.weight.save(WeightEntry(id: UUID(), weightKilograms: 80, date: saturday))

        let drafts = try builder(harness).buildDrafts(
            preferences: ReminderScheduleConfiguration.defaultPreferences,
            horizonDays: 14,
            now: monday,
            calendar: calendar
        )
        XCTAssertFalse(drafts.contains { $0.kind == .weight }, "Weighed on Saturday, so Monday stays quiet")
    }

    private func nextDate(weekday: Int, hour: Int) -> Date? {
        calendar.nextDate(
            after: morning,
            matching: DateComponents(hour: hour, minute: 0, weekday: weekday),
            matchingPolicy: .nextTime
        )
    }

    private func builder(_ harness: TestHarness) -> ReminderScheduleBuilder {
        ReminderScheduleBuilder(foodEntryRepository: harness.food, weightEntryRepository: harness.weight)
    }
}
