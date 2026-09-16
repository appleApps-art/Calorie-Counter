import UIKit

enum Tab: Int, CaseIterable {
    case home
    case progress
    case aiAssistant
    case recipes
    case rewards

    static var tabBarItems: [Tab] {
        [.home, .progress, .aiAssistant, .recipes, .rewards]
    }

    var title: String {
        switch self {
        case .home:
            return L10n.tr("tab.home")
        case .progress:
            return L10n.tr("tab.progress")
        case .aiAssistant:
            return L10n.tr("tab.ai")
        case .recipes:
            return L10n.tr("tab.recipes")
        case .rewards:
            return L10n.tr("tab.rewards")
        }
    }

    var systemImageName: String {
        switch self {
        case .home:
            return "house.fill"
        case .progress:
            return "chart.line.uptrend.xyaxis"
        case .aiAssistant:
            return "sparkles"
        case .recipes:
            return "book"
        case .rewards:
            return "trophy"
        }
    }

    var analyticsName: String {
        switch self {
        case .home: return "home"
        case .progress: return "progress"
        case .aiAssistant: return "ai_assistant"
        case .recipes: return "recipes"
        case .rewards: return "rewards"
        }
    }
}
