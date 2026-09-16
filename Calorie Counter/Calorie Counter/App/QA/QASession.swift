#if DEBUG
import Foundation

enum QASession {
    static func prepare(container: DIContainer) {
        guard QALaunchConfiguration.isActive else { return }
        do {
            if QALaunchConfiguration.cleanupOnly {
                try QADataSeeder.cleanup(container: container)
                return
            }
            try QADataSeeder.apply(container: container, kind: QALaunchConfiguration.seed)
        } catch {
            assertionFailure("QA seed failed: \(error)")
        }
    }
}
#endif
