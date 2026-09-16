import Foundation

protocol AnalyticsTracking: AnyObject {
    var deviceID: String? { get }
    var userID: String? { get }

    func track(_ event: AnalyticsEvent)
    func setUserID(_ userID: String?)
    func setUserProperties(_ properties: [String: Any])
}

enum Analytics {
    static let hub = AnalyticsHub()
    static var tracker: AnalyticsTracking { hub }
}

final class AnalyticsHub: AnalyticsTracking {
    var base: AnalyticsTracking = NoOpAnalyticsService()
    weak var appRatingPrompt: AppRatingPrompting?

    var deviceID: String? { base.deviceID }
    var userID: String? { base.userID }

    func track(_ event: AnalyticsEvent) {
        base.track(event)
        guard let source = event.appRatingTriggerSource else { return }
        appRatingPrompt?.promptAfterCompletedAction(source: source)
    }

    func setUserID(_ userID: String?) {
        base.setUserID(userID)
    }

    func setUserProperties(_ properties: [String: Any]) {
        base.setUserProperties(properties)
    }
}

final class NoOpAnalyticsService: AnalyticsTracking {
    var deviceID: String? { nil }
    var userID: String? { nil }

    func track(_ event: AnalyticsEvent) {}
    func setUserID(_ userID: String?) {}
    func setUserProperties(_ properties: [String: Any]) {}
}
