import SwiftUI
import WidgetKit

@main
struct BityWidgetBundle: WidgetBundle {
    var body: some Widget {
        BityDiaryWidget()
        DayLiveActivity()
    }
}

struct BityDiaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.diary, provider: DiaryTimelineProvider()) { entry in
            DiaryWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.tr("widget.displayName"))
        .description(WidgetL10n.tr("widget.description"))
        .supportedFamilies([.systemMedium])
    }
}
