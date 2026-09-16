#if DEBUG
import Foundation

/// Isolated preview data; opening a QA inbox never replaces persisted notifications.
final class QANotificationInboxStore: NotificationInboxStoring {
    private var items: [InboxNotification] = []

    init(filled: Bool) {
        guard filled else { return }
        let examples = [
            ("Hydration Reminder", "It's time to log your afternoon water. Reaching your daily target keeps your focus steady!", "drop.fill", 2),
            ("Protein Intake Alert", "Your protein is slightly lower than usual today. Adding almonds or Greek yogurt to your next snack is recommended.", "sparkles", 4),
            ("Log Your Dinner", "Keep your meal logging streak alive. What delicious healthy foods did you make tonight?", "moon.fill", 6),
            ("7-Day Streak Complete!", "Incredible dedication! You reached your hydration target 7 days in a row.", "flame.fill", 26),
            ("Daily Target Met", "You consumed 2.1 L of water yesterday. Outstanding effort in supporting your recovery!", "drop.fill", 28)
        ]
        items = examples.enumerated().map { index, item in
            InboxNotification(id: "qa-notification-\(index)", title: item.0, body: item.1,
                              date: Date().addingTimeInterval(-Double(item.3) * 3600),
                              symbolName: item.2, imageName: nil)
        }
    }

    func records() -> [InboxNotification] { items }
    func upsert(_ record: InboxNotification) {
        remove(id: record.id)
        items.append(record)
    }
    func remove(id: String) { items.removeAll { $0.id == id } }
}
#endif
