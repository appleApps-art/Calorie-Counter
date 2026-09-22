import Foundation
import Network

/// Whether the device can reach the internet right now. Everything that talks to the backend asks
/// it first, so without a connection a screen answers at once (from what it kept, or with the
/// offline state) instead of waiting out timeouts and retries.
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    /// Posted on the main queue whenever the device goes online or offline.
    static let didChange = Notification.Name("bity.network.didChange")

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "bity.network.monitor")
    private let lock = NSLock()
    // Until the first path arrives the app assumes it is online, so nothing flashes "offline".
    private var online = true
    private var started = false

    var isOnline: Bool {
        #if DEBUG
        if Self.simulatesOffline { return false }
        #endif
        lock.lock()
        defer { lock.unlock() }
        return online
    }

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(isOnline: path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    /// Throws the offline error when there is no connection; for actions that only the backend can do.
    func requireOnline() throws {
        guard isOnline else { throw NoConnectionError() }
    }

    func update(isOnline value: Bool) {
        lock.lock()
        let changed = online != value
        online = value
        lock.unlock()
        guard changed else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChange, object: self)
        }
    }

    #if DEBUG
    /// `-simulateOffline` runs the real app as if the device had no connection.
    static let simulatesOffline = ProcessInfo.processInfo.arguments.contains("-simulateOffline")
    #endif
}

/// The request needs the internet and the device has none.
struct NoConnectionError: LocalizedError, Equatable {
    var errorDescription: String? { L10n.tr("offline.message") }
}

extension Error {
    /// True when the failure comes from having no connection rather than from the server.
    var isNoConnection: Bool {
        if self is NoConnectionError { return true }
        if let urlError = self as? URLError {
            return [
                .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed
            ].contains(urlError.code)
        }
        return !NetworkMonitor.shared.isOnline
    }
}
