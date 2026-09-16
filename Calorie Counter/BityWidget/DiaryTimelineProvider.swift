import Foundation
import WidgetKit

struct DiaryTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> DiaryWidgetEntry {
        DiaryWidgetEntry(date: Date(), snapshot: .placeholder, hasData: true)
    }

    func getSnapshot(in _: Context, completion: @escaping (DiaryWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<DiaryWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> DiaryWidgetEntry {
        if let snapshot = WidgetDiarySnapshotStore.load() {
            return DiaryWidgetEntry(date: Date(), snapshot: snapshot, hasData: true)
        }
        return DiaryWidgetEntry(date: Date(), snapshot: .empty, hasData: false)
    }
}
