import Foundation

actor SpoonacularRequestScheduler {
    static let shared = SpoonacularRequestScheduler()

    private let maxPerSecond: Int
    private let maxConcurrent: Int
    private var window: [ContinuousClock.Instant] = []
    private var inFlight = 0

    init(maxPerSecond: Int = 5, maxConcurrent: Int = 5) {
        self.maxPerSecond = maxPerSecond
        self.maxConcurrent = maxConcurrent
    }

    func run<T>(_ operation: () async throws -> T) async throws -> T {
        await acquire()
        do {
            let value = try await operation()
            release()
            return value
        } catch {
            release()
            throw error
        }
    }

    private func acquire() async {
        while true {
            let now = ContinuousClock.now
            window.removeAll { now - $0 >= .seconds(1) }
            if inFlight < maxConcurrent, window.count < maxPerSecond {
                inFlight += 1
                window.append(now)
                return
            }
            try? await Task.sleep(for: .milliseconds(80))
        }
    }

    private func release() {
        inFlight = max(0, inFlight - 1)
    }
}
