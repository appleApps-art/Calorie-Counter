import Foundation
import WidgetKit

struct DiaryWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDiarySnapshot
    let hasData: Bool
}
