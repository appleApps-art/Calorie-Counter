import Foundation

enum AppDeepLink: Equatable {
    static let scheme = "bity"

    case home
    case logFood

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host {
        case "log":
            self = .logFood
        default:
            self = .home
        }
    }

    var url: URL {
        switch self {
        case .home:
            return URL(string: "bity://home")!
        case .logFood:
            return URL(string: "bity://log")!
        }
    }
}
