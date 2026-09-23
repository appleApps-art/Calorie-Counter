import Foundation

enum AppDeepLink: Equatable {
    static let scheme = "bity"

    case home
    case logFood
    /// Opens the quick log sheet already pointed at one meal.
    case logMeal(WidgetMealKind)

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host {
        case "log":
            let meal = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "meal" }?
                .value
                .flatMap(WidgetMealKind.init(rawValue:))
            self = meal.map(AppDeepLink.logMeal) ?? .logFood
        default:
            self = .home
        }
    }

    var url: URL {
        switch self {
        case .home:
            return URL(string: "\(Self.scheme)://home")!
        case .logFood:
            return URL(string: "\(Self.scheme)://log")!
        case let .logMeal(meal):
            return URL(string: "\(Self.scheme)://log?meal=\(meal.rawValue)")!
        }
    }
}
