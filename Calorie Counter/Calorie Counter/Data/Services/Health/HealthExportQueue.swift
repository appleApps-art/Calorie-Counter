import Foundation

/// Enqueue synchronously with the local mutation, so an edit or deletion cannot
/// overtake a suspended HealthKit save for the same entry.
@MainActor
final class HealthExportQueue {
    static let shared = HealthExportQueue()
    private var pending: [UUID: Task<Void, Never>] = [:]
    private var generations: [UUID: UUID] = [:]

    func enqueue(entryID: UUID, operation: @escaping @MainActor () async throws -> Void) {
        let previous = pending[entryID]
        let generation = UUID()
        generations[entryID] = generation
        pending[entryID] = Task { @MainActor in
            await previous?.value
            do {
                try await operation()
            } catch {
                // The operation uses stable HealthKit sync identifiers, so a
                // transient failure can be retried without creating duplicates.
                try? await operation()
            }
            if generations[entryID] == generation {
                pending[entryID] = nil
                generations[entryID] = nil
            }
        }
    }

    func waitForPendingOperations() async {
        for task in pending.values { await task.value }
    }
}
