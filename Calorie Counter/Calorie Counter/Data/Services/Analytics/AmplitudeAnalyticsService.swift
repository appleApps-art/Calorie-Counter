import AmplitudeSwift
import Foundation

enum AmplitudeSDKConfiguration {
    static let apiKey = "4d3f4cf5decb1ff3c64d0feb45f2cfdd"
}

final class AmplitudeAnalyticsService: AnalyticsDestination {
    let client: Amplitude

    var deviceID: String? { client.getDeviceId() }
    var userID: String? { client.getUserId() }

    init(apiKey: String = AmplitudeSDKConfiguration.apiKey) {
        client = Amplitude(
            configuration: Configuration(
                apiKey: apiKey,
                // Element interactions record every tap (button title, screen, view path) but never
                // what the user types, so the full path through the app can be replayed.
                autocapture: [.sessions, .appLifecycles, .elementInteractions, .frustrationInteractions]
            )
        )
        setUserProperties([
            "locale": Locale.current.identifier
        ])
    }

    func send(eventType: String, properties: [String: Any]) {
        client.track(eventType: eventType, eventProperties: properties)
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

    func setUserPropertiesOnce(_ properties: [String: Any]) {
        let identify = Identify()
        properties.forEach { key, value in
            switch value {
            case let bool as Bool:
                identify.setOnce(property: key, value: bool)
            case let int as Int:
                identify.setOnce(property: key, value: int)
            case let string as String:
                identify.setOnce(property: key, value: string)
            default:
                identify.setOnce(property: key, value: value as Any?)
            }
        }
        client.identify(identify: identify)
    }

    func incrementUserProperty(_ name: String, by value: Int) {
        client.identify(identify: Identify().add(property: name, value: value))
    }
}
