import UIKit

enum Tab: Int, CaseIterable {
    case home
    case recipes
    case aiAssistant
    case progress
    case settings

    var title: String {
        switch self {
        case .home:
            return L10n.tr("tab.home")
        case .recipes:
            return L10n.tr("tab.recipes")
        case .aiAssistant:
            return L10n.tr("tab.ai")
        case .progress:
            return L10n.tr("tab.progress")
        case .settings:
            return L10n.tr("tab.settings")
        }
    }

    var systemImageName: String {
        switch self {
        case .home:
            return "house.fill"
        case .recipes:
            return "fork.knife"
        case .aiAssistant:
            return "sparkles"
        case .progress:
            return "chart.line.uptrend.xyaxis"
        case .settings:
            return "gearshape.fill"
        }
    }
}
