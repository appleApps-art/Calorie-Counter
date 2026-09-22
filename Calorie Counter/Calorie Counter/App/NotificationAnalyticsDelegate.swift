import UserNotifications

/// Reports which reminder brought the user back and takes them where the reminder points.
/// How notifications are presented stays the system default.
final class NotificationAnalyticsDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationAnalyticsDelegate()

    /// Set once the main screen exists. A tap that launched the app waits here until then.
    var onOpenReminder: ((ReminderKind) -> Void)? {
        didSet { deliverPendingIfPossible() }
    }

    private var pendingKind: ReminderKind?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let raw = response.notification.request.content.userInfo["kind"] as? String
        Analytics.tracker.track(.notificationOpened(kind: raw ?? "unknown"))
        if let kind = raw.flatMap(ReminderKind.init(rawValue:)) {
            DispatchQueue.main.async { [weak self] in
                self?.pendingKind = kind
                self?.deliverPendingIfPossible()
            }
        }
        completionHandler()
    }

    private func deliverPendingIfPossible() {
        guard let kind = pendingKind, let onOpenReminder else { return }
        pendingKind = nil
        onOpenReminder(kind)
    }
}
