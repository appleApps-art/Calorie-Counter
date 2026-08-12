import Foundation

enum MealType: String, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snacks

    var localizedTitle: String {
        L10n.tr("meal.\(rawValue)")
    }
}
