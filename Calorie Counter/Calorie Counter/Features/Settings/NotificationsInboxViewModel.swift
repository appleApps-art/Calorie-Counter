import Foundation
import UserNotifications

struct NotificationInboxRow: Equatable, Identifiable {
    let id: String
    let title: String
    let body: String
    let timeText: String
    let date: Date
    let symbolName: String?
    let imageName: String?
}

struct NotificationInboxSection: Equatable {
    let title: String
    let rows: [NotificationInboxRow]
}

final class NotificationsInboxViewModel {
    let titleText = Observable(L10n.tr("notifications.title"))
    let sections = Observable<[NotificationInboxSection]>([])
    let allowsNotifications = Observable(false)
    var onOpenSystemSettings: (() -> Void)?

    private let inboxStore: NotificationInboxStoring
    private let permissionUseCase: RequestNotificationPermissionUseCase?
    private let timeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .numeric
        return formatter
    }()
    private let olderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private func timestamp(for date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? timeFormatter.localizedString(for: date, relativeTo: Date())
            : clockFormatter.string(from: date)
    }

    init(
        inboxStore: NotificationInboxStoring,
        permissionUseCase: RequestNotificationPermissionUseCase? = nil
    ) {
        self.inboxStore = inboxStore
        self.permissionUseCase = permissionUseCase
    }

    func setAllowsNotifications(_ enabled: Bool) {
        Task { @MainActor in
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            if enabled {
                if status == .denied {
                    onOpenSystemSettings?()
                } else {
                    _ = try? await permissionUseCase?.execute()
                }
            } else {
                onOpenSystemSettings?()
            }
            await refreshAuthorization()
        }
    }

    func reload() {
        Task { @MainActor [weak self] in
            await self?.load()
        }
    }

    func dismiss(id: String) {
        inboxStore.remove(id: id)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        reload()
    }

    private func load() async {
        await refreshAuthorization()
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        let deliveredRows = delivered.map { request -> NotificationInboxRow in
            let content = request.request.content
            let kind = content.userInfo["kind"] as? String
            return NotificationInboxRow(
                id: request.request.identifier,
                title: content.title,
                body: content.body,
                timeText: timestamp(for: request.date),
                date: request.date,
                symbolName: Self.symbolName(forKind: kind),
                imageName: nil
            )
        }
        let storedRows = inboxStore.records().map { record in
            NotificationInboxRow(
                id: record.id,
                title: record.title,
                body: record.body,
                timeText: timestamp(for: record.date),
                date: record.date,
                symbolName: record.symbolName,
                imageName: record.imageName
            )
        }
        var seen = Set<String>()
        let merged = (deliveredRows + storedRows).filter { row in
            seen.insert(row.id).inserted
        }
        sections.value = group(merged)
    }

    private func refreshAuthorization() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        allowsNotifications.value = status == .authorized || status == .provisional
    }

    private func group(_ rows: [NotificationInboxRow]) -> [NotificationInboxSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: rows) { row in
            calendar.startOfDay(for: row.date)
        }
        return grouped.keys.sorted(by: >).compactMap { day in
            let dayRows = (grouped[day] ?? []).sorted { $0.date > $1.date }
            guard dayRows.isEmpty == false else { return nil }
            return NotificationInboxSection(title: dayTitle(for: day), rows: dayRows)
        }
    }

    private func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.tr("ai.history.today")
        }
        if calendar.isDateInYesterday(date) {
            return L10n.tr("ai.history.yesterday")
        }
        return olderDateFormatter.string(from: date)
    }

    private static func symbolName(forKind kind: String?) -> String {
        switch kind {
        case ReminderKind.breakfast.rawValue, ReminderKind.lunch.rawValue, ReminderKind.dinner.rawValue:
            return "fork.knife"
        case ReminderKind.water.rawValue:
            return "drop.fill"
        case ReminderKind.weight.rawValue:
            return "scalemass"
        case ReminderKind.dailyStreak.rawValue:
            return "flame.fill"
        case ReminderKind.comeback.rawValue:
            return "hand.wave.fill"
        default:
            return "bell.fill"
        }
    }
}
