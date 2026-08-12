import Foundation
import UserNotifications

final class RequestNotificationPermissionUseCase {
    private let scheduler: LocalNotificationScheduling

    init(scheduler: LocalNotificationScheduling) {
        self.scheduler = scheduler
    }

    func execute() async throws -> Bool {
        try await scheduler.requestAuthorization()
    }

    func status() async -> UNAuthorizationStatus {
        await scheduler.authorizationStatus()
    }
}

final class RefreshReminderScheduleUseCase {
    private let preferencesStore: ReminderPreferencesStoring
    private let habitAnalyzer: ReminderHabitAnalyzing
    private let scheduleBuilder: ReminderScheduleBuilding
    private let scheduler: LocalNotificationScheduling

    init(
        preferencesStore: ReminderPreferencesStoring,
        habitAnalyzer: ReminderHabitAnalyzing,
        scheduleBuilder: ReminderScheduleBuilding,
        scheduler: LocalNotificationScheduling
    ) {
        self.preferencesStore = preferencesStore
        self.habitAnalyzer = habitAnalyzer
        self.scheduleBuilder = scheduleBuilder
        self.scheduler = scheduler
    }

    @discardableResult
    func execute(now: Date = Date()) async throws -> [ScheduledReminderDraft] {
        let status = await scheduler.authorizationStatus()
        guard status == .authorized || status == .provisional else {
            return []
        }

        var configuration = preferencesStore.configuration
        let snapshot = try habitAnalyzer.analyze(configuration: configuration, now: now, calendar: .current)
        if snapshot.didApplyAdaptiveUpdates {
            configuration.preferences = snapshot.preferences
            configuration.lastAdaptiveEvaluationAt = now
            preferencesStore.configuration = configuration
        }

        let drafts = try scheduleBuilder.buildDrafts(
            preferences: configuration.preferences,
            horizonDays: configuration.scheduleHorizonDays,
            now: now,
            calendar: .current
        )
        await scheduler.replaceSchedule(with: drafts)
        return drafts
    }
}

final class BootstrapRemindersUseCase {
    private let requestPermissionUseCase: RequestNotificationPermissionUseCase
    private let refreshReminderScheduleUseCase: RefreshReminderScheduleUseCase

    init(
        requestPermissionUseCase: RequestNotificationPermissionUseCase,
        refreshReminderScheduleUseCase: RefreshReminderScheduleUseCase
    ) {
        self.requestPermissionUseCase = requestPermissionUseCase
        self.refreshReminderScheduleUseCase = refreshReminderScheduleUseCase
    }

    func execute(requestPermissionIfNeeded: Bool = true) async {
        do {
            if requestPermissionIfNeeded {
                let status = await requestPermissionUseCase.status()
                if status == .notDetermined {
                    _ = try await requestPermissionUseCase.execute()
                }
            }
            _ = try await refreshReminderScheduleUseCase.execute()
        } catch {
            return
        }
    }
}
