import CryptoKit
import Foundation

/// Keeps the last good answer of every read-only backend request on disk, so a screen that was
/// opened once still shows its content without a connection.
final class OfflineResponseStore {
    static let shared: OfflineResponseStore = {
        // Unit tests get a fresh folder, so one test's kept answers never stand in for another's.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            return OfflineResponseStore()
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("OfflineResponses-tests")
        try? FileManager.default.removeItem(at: folder)
        return OfflineResponseStore(directory: folder)
    }()

    private let directory: URL
    private let maxBytes: Int
    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var writesSincePrune = 0

    init(directory: URL? = nil, maxBytes: Int = 40 * 1024 * 1024) {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = directory ?? caches.appendingPathComponent("OfflineResponses", isDirectory: true)
        self.maxBytes = maxBytes
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func data(for request: URLRequest) -> Data? {
        let url = fileURL(for: request)
        guard let data = try? Data(contentsOf: url) else { return nil }
        // Touch it, so pruning drops what has not been needed for longest.
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    func store(_ data: Data, for request: URLRequest) {
        guard !data.isEmpty else { return }
        try? data.write(to: fileURL(for: request), options: .atomic)
        lock.lock()
        writesSincePrune += 1
        let shouldPrune = writesSincePrune >= 40
        if shouldPrune { writesSincePrune = 0 }
        lock.unlock()
        if shouldPrune { prune() }
    }

    func removeAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Drops the least recently used answers once the folder grows past its budget.
    func prune() {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return }
        var entries = files.compactMap { url -> (url: URL, date: Date, size: Int)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > maxBytes else { return }
        entries.sort { $0.date < $1.date }
        for entry in entries where total > maxBytes {
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    /// Method, address and body identify an answer; headers such as the API key do not.
    private func fileURL(for request: URLRequest) -> URL {
        var key = Data((request.httpMethod ?? "GET").utf8)
        key.append(Data((request.url?.absoluteString ?? "").utf8))
        if let body = request.httpBody { key.append(body) }
        let name = SHA256.hash(data: key).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }
}

enum OfflineFallback {
    /// Runs a read-only request and keeps its answer. Without a connection, or when the request
    /// fails, the kept answer comes back instead; with nothing kept, the offline error does.
    static func data(
        for request: URLRequest,
        store: OfflineResponseStore = .shared,
        monitor: NetworkMonitor = .shared,
        load: () async throws -> Data
    ) async throws -> Data {
        guard monitor.isOnline else {
            if let kept = store.data(for: request) { return kept }
            throw NoConnectionError()
        }
        do {
            let data = try await load()
            store.store(data, for: request)
            return data
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            if let kept = store.data(for: request) { return kept }
            throw monitor.isOnline ? error : NoConnectionError()
        }
    }
}
