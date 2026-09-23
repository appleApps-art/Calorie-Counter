import Foundation

/// The four meals, mirrored from the app's `MealType` so the widget and the Live Activity can talk
/// about meals without depending on the app target.
enum WidgetMealKind: String, Codable, Hashable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snacks

    /// Matches the icons the home screen meal rows use.
    var systemImageName: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snacks: return "carrot.fill"
        }
    }

    /// The `meal.*` key both the app and the widget bundle localize.
    var localizationKey: String {
        "meal.\(rawValue)"
    }
}
