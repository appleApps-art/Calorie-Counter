import Foundation

enum WidgetDiarySnapshotStore {
    static func save(_ snapshot: WidgetDiarySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: AppGroup.diarySnapshotKey)
    }

    static func load() -> WidgetDiarySnapshot? {
        guard let data = AppGroup.defaults.data(forKey: AppGroup.diarySnapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetDiarySnapshot.self, from: data)
    }
}
