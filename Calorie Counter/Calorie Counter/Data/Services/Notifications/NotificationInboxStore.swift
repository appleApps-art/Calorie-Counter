import Foundation

struct InboxNotification: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var body: String
    var date: Date
    var symbolName: String?
    var imageName: String?
}

protocol NotificationInboxStoring: AnyObject {
    func records() -> [InboxNotification]
    func upsert(_ record: InboxNotification)
    func remove(id: String)
}

final class NotificationInboxStore: NotificationInboxStoring {
    private let defaults: UserDefaults
    private let key = "bity.notificationInbox.records"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func records() -> [InboxNotification] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([InboxNotification].self, from: data)) ?? []
    }

    func upsert(_ record: InboxNotification) {
        var items = records().filter { $0.id != record.id }
        items.append(record)
        save(items)
    }

    func remove(id: String) {
        save(records().filter { $0.id != id })
    }

    private func save(_ items: [InboxNotification]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}
