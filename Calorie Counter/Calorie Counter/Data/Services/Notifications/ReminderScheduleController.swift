import Foundation

final class ReminderScheduleController {
    private let bootstrapRemindersUseCase: BootstrapRemindersUseCase
    private let refreshReminderScheduleUseCase: RefreshReminderScheduleUseCase
    private let evaluateStreakUseCase: EvaluateStreakUseCase?
    private let lock = NSLock()
    private var isRefreshing = false

    init(
        bootstrapRemindersUseCase: BootstrapRemindersUseCase,
        refreshReminderScheduleUseCase: RefreshReminderScheduleUseCase,
        evaluateStreakUseCase: EvaluateStreakUseCase? = nil
    ) {
        self.bootstrapRemindersUseCase = bootstrapRemindersUseCase
        self.refreshReminderScheduleUseCase = refreshReminderScheduleUseCase
        self.evaluateStreakUseCase = evaluateStreakUseCase
    }

    func bootstrap() {
        Task {
            await bootstrapRemindersUseCase.execute(requestPermissionIfNeeded: true)
        }
    }

    func refreshAfterDiaryChange() {
        Task {
            await refreshIfNeeded()
        }
    }

    func refreshOnForeground() {
        Task {
            await refreshIfNeeded()
        }
    }

    private func refreshIfNeeded() async {
        lock.lock()
        if isRefreshing {
            lock.unlock()
            return
        }
        isRefreshing = true
        lock.unlock()

        defer {
            lock.lock()
            isRefreshing = false
            lock.unlock()
        }

        _ = try? await refreshReminderScheduleUseCase.execute()
        _ = try? evaluateStreakUseCase?.execute()
    }
}
