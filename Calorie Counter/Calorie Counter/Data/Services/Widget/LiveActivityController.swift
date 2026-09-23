import ActivityKit
import Foundation

/// Keeps one Live Activity alive for the running day.
///
/// iOS retires a Live Activity on its own after a few hours, and it cannot be restarted from the
/// background, so the activity is (re)started opportunistically every time the diary changes or the
/// app comes forward. A day rollover ends yesterday's activity and starts a fresh one.
final class LiveActivityController {
    private let calendar: Calendar
    private let now: () -> Date

    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
    }

    private var activities: [Activity<DayActivityAttributes>] {
        Activity<DayActivityAttributes>.activities
    }

    func refresh(snapshot: WidgetDiarySnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Before onboarding there is no target to count against, so there is nothing worth showing.
        guard snapshot.calorieTarget > 0 else {
            endAll()
            return
        }

        let dayStart = calendar.startOfDay(for: now())
        let state = DayActivityAttributes.ContentState(snapshot: snapshot)
        let content = ActivityContent(state: state, staleDate: staleDate(after: dayStart))

        let live = activities.filter { $0.activityState == .active || $0.activityState == .stale }
        let today = live.first { $0.attributes.dayStart == dayStart }
        let outdated = live.filter { $0.attributes.dayStart != dayStart }

        for activity in outdated {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        if let today {
            Task { await today.update(content) }
            return
        }

        do {
            _ = try Activity.request(
                attributes: DayActivityAttributes(dayStart: dayStart),
                content: content,
                pushType: nil
            )
        } catch {
            // Starting can legitimately fail (backgrounded app, activity budget spent). The next
            // diary change or foreground tries again.
        }
    }

    func endAll() {
        for activity in activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// The day's activity is only meaningful until midnight; after that iOS dims it as stale.
    private func staleDate(after dayStart: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 60 * 60)
    }
}
