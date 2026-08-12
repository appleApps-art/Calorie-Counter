import Foundation
import UserNotifications

protocol LocalNotificationScheduling {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func replaceSchedule(with drafts: [ScheduledReminderDraft]) async
    func removePending(withPrefix prefix: String) async
}

final class LocalNotificationScheduler: LocalNotificationScheduling {
    static let identifierPrefix = "avo.reminder."

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func replaceSchedule(with drafts: [ScheduledReminderDraft]) async {
        await removePending(withPrefix: Self.identifierPrefix)
        for draft in drafts {
            let content = UNMutableNotificationContent()
            content.title = draft.title
            content.body = draft.body
            content.sound = .default
            content.userInfo = [
                "kind": draft.kind.rawValue,
                "fireDate": draft.fireDate.timeIntervalSince1970,
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: draft.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: draft.identifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func removePending(withPrefix prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
