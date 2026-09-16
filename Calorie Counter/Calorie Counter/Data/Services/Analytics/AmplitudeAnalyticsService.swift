import AmplitudeSwift
import Foundation

enum AmplitudeSDKConfiguration {
    static let apiKey = "4d3f4cf5decb1ff3c64d0feb45f2cfdd"
}

final class AmplitudeAnalyticsService: AnalyticsTracking {
    let client: Amplitude

    var deviceID: String? { client.getDeviceId() }
    var userID: String? { client.getUserId() }

    init(apiKey: String = AmplitudeSDKConfiguration.apiKey) {
        client = Amplitude(
            configuration: Configuration(
                apiKey: apiKey,
                autocapture: [.sessions, .appLifecycles, .frustrationInteractions]
            )
        )
        setUserProperties([
            "locale": Locale.current.identifier
        ])
    }

    func track(_ event: AnalyticsEvent) {
        client.track(
            eventType: event.name,
            eventProperties: event.properties
        )
    }

    func setUserID(_ userID: String?) {
        client.setUserId(userId: userID)
    }

    func setUserProperties(_ properties: [String: Any]) {
        let identify = Identify()
        properties.forEach { key, value in
            switch value {
            case let bool as Bool:
                identify.set(property: key, value: bool)
            case let int as Int:
                identify.set(property: key, value: int)
            case let string as String:
                identify.set(property: key, value: string)
            default:
                identify.set(property: key, value: value as Any?)
            }
        }
        client.identify(identify: identify)
    }
}
