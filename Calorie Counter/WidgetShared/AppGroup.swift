import Foundation

enum AppGroup {
    static let identifier = "group.test.builder.paywall.Calorie-Counter"
    static let diarySnapshotKey = "bity.widget.diary.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
