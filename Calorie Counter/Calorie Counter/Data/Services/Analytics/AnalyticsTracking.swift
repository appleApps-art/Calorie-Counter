import Foundation

protocol AnalyticsTracking: AnyObject {
    var deviceID: String? { get }
    var userID: String? { get }

    func track(_ event: AnalyticsEvent)
    func setUserID(_ userID: String?)
    func setUserProperties(_ properties: [String: Any])
}

/// Where events end up: Amplitude in the app, nothing in tests and previews.
protocol AnalyticsDestination: AnyObject {
    var deviceID: String? { get }
    var userID: String? { get }

    func send(eventType: String, properties: [String: Any])
    func setUserID(_ userID: String?)
    func setUserProperties(_ properties: [String: Any])
    /// Written only the first time, e.g. the date of the very first launch.
    func setUserPropertiesOnce(_ properties: [String: Any])
    func incrementUserProperty(_ name: String, by value: Int)
}

enum Analytics {
    static let hub = AnalyticsHub()
    static var tracker: AnalyticsTracking { hub }
}

final class AnalyticsHub: AnalyticsTracking {
    var base: AnalyticsDestination = NoOpAnalyticsService()
    weak var appRatingPrompt: AppRatingPrompting?
    let journey = AnalyticsJourney()
    #if DEBUG
    /// `-logAnalytics` prints every event to the console, to check tracking while developing.
    static let logsEvents = ProcessInfo.processInfo.arguments.contains("-logAnalytics")
    #endif

    var deviceID: String? { base.deviceID }
    var userID: String? { base.userID }

    func track(_ event: AnalyticsEvent) {
        let properties = properties(for: event)
        #if DEBUG
        if Self.logsEvents {
            let details = properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            print("[analytics] \(event.name) \(details)")
        }
        #endif
        base.send(eventType: event.name, properties: properties)
        guard let source = event.appRatingTriggerSource else { return }
        appRatingPrompt?.promptAfterCompletedAction(source: source)
    }

    /// Every event says which screen it happened on and whether the phone was offline, so any
    /// action can be put back into the user's path through the app.
    func properties(for event: AnalyticsEvent, now: Date = Date()) -> [String: Any] {
        var properties = event.properties
        if case .screenViewed(let screen) = event {
            properties.merge(journey.enter(screen.rawValue, at: now)) { current, _ in current }
        } else if properties["screen"] == nil, let screen = journey.currentScreen {
            properties["screen"] = screen
        }
        properties["is_offline"] = !NetworkMonitor.shared.isOnline
        return properties
    }

    func setUserID(_ userID: String?) {
        base.setUserID(userID)
    }

    func setUserProperties(_ properties: [String: Any]) {
        base.setUserProperties(properties)
    }

    func setUserPropertiesOnce(_ properties: [String: Any]) {
        base.setUserPropertiesOnce(properties)
    }

    func incrementUserProperty(_ name: String, by value: Int = 1) {
        base.incrementUserProperty(name, by: value)
    }
}

/// The user's path through the screens of one session: where they are, where they came from and
/// how long they stayed there. Screens form a stack, so closing a sheet or going back makes the
/// screen underneath current again even though iOS does not show it anew.
final class AnalyticsJourney {
    private let lock = NSLock()
    private var stack: [String] = []
    private var enteredAt: Date?
    private var index = 0
    /// A dismissed screen reports its end before the screen underneath shows again; that next view
    /// still names it as where the user came from.
    private var justLeft: (screen: String, seconds: Int)?

    var currentScreen: String? {
        lock.lock()
        defer { lock.unlock() }
        return stack.last
    }

    func enter(_ next: String, at date: Date = Date()) -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        index += 1
        var properties: [String: Any] = ["screen_index": index]
        if let justLeft, next == stack.last {
            properties["previous_screen"] = justLeft.screen
            properties["seconds_on_previous_screen"] = justLeft.seconds
        } else {
            if let screen = stack.last {
                properties["previous_screen"] = screen
            }
            if let enteredAt {
                properties["seconds_on_previous_screen"] = max(0, Int(date.timeIntervalSince(enteredAt).rounded()))
            }
        }
        justLeft = nil
        if let existing = stack.lastIndex(of: next) {
            // Coming back to a screen further down: everything above it was left.
            stack.removeSubrange(stack.index(after: existing)...)
        } else {
            stack.append(next)
        }
        enteredAt = date
        return properties
    }

    /// A screen was dismissed or popped. If it was the current one, the screen below becomes current.
    func leave(_ screen: String, at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        guard let position = stack.lastIndex(of: screen) else { return }
        let wasCurrent = position == stack.count - 1
        stack.remove(at: position)
        if wasCurrent {
            justLeft = (screen, enteredAt.map { max(0, Int(date.timeIntervalSince($0).rounded())) } ?? 0)
            enteredAt = date
        }
    }

    /// How long the current screen has been open; the app going to the background reports it.
    func secondsOnCurrentScreen(at date: Date = Date()) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return enteredAt.map { max(0, Int(date.timeIntervalSince($0).rounded())) }
    }

    /// A new session starts its own path; the screen the user comes back to is its first step.
    func startSession() {
        lock.lock()
        defer { lock.unlock() }
        index = 0
        enteredAt = Date()
    }
}

final class NoOpAnalyticsService: AnalyticsDestination {
    var deviceID: String? { nil }
    var userID: String? { nil }

    func send(eventType: String, properties: [String: Any]) {}
    func setUserID(_ userID: String?) {}
    func setUserProperties(_ properties: [String: Any]) {}
    func setUserPropertiesOnce(_ properties: [String: Any]) {}
    func incrementUserProperty(_ name: String, by value: Int) {}
}
