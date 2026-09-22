import Foundation
import UserNotifications

protocol TrialReminderScheduling: AnyObject {
    func scheduleTrialEndReminder(trialDays: Int, startedAt date: Date)
}

/// The paywall's timeline promises a reminder the day before a free trial turns into a paid
/// subscription; this keeps that promise. Its identifier sits outside the meal reminders' prefix,
/// so rescheduling those never removes it.
final class TrialReminderScheduler: TrialReminderScheduling {
    static let identifier = "bity.trial.ends"
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    func scheduleTrialEndReminder(trialDays: Int, startedAt date: Date) {
        guard let request = Self.request(trialDays: trialDays, startedAt: date, calendar: calendar) else { return }
        let center = center
        Task {
            // Starting a trial is when the reminder matters, so that is when Bity asks to notify.
            if await center.notificationSettings().authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
            center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
            try? await center.add(request)
        }
    }

    static func request(trialDays: Int, startedAt date: Date, calendar: Calendar) -> UNNotificationRequest? {
        guard trialDays >= 2,
              let fireDate = calendar.date(byAdding: .day, value: trialDays - 1, to: date)
        else { return nil }
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("trial.reminder.title")
        content.body = L10n.tr("trial.reminder.body")
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
