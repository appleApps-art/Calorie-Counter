import Foundation

@MainActor
final class HealthSyncController {
    private let healthSync: HealthSyncing
    private let appSettingsStore: AppSettingsStoring
    private let requestAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase
    private let syncHealthDataUseCase: SyncHealthDataUseCase
    private var currentSync: Task<Void, Error>?
    private var needsAnotherSync = false

    init(
        healthSync: HealthSyncing,
        appSettingsStore: AppSettingsStoring,
        requestAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase,
        syncHealthDataUseCase: SyncHealthDataUseCase
    ) {
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
        self.requestAuthorizationUseCase = requestAuthorizationUseCase
        self.syncHealthDataUseCase = syncHealthDataUseCase
    }

    func bootstrap() { refreshOnForeground() }

    func refreshOnForeground() {
        Task {
            await prepareAuthorizationIfNeeded()
            _ = requestAuthorizationUseCase.refreshFromStore()
            try? await startIfEnabled()
        }
    }

    private func prepareAuthorizationIfNeeded() async {
        guard healthSync.isAvailable, !appSettingsStore.settings.healthSyncUserDisabled else { return }
        let shouldPrompt = await healthSync.needsAuthorizationPrompt()
        var settings = appSettingsStore.settings
        guard shouldPrompt || !settings.healthAuthorizationRequested else { return }
        settings.healthAuthorizationRequested = true
        appSettingsStore.settings = settings
        _ = try? await requestAuthorizationUseCase.execute()
    }

    private func startIfEnabled() async throws {
        guard appSettingsStore.settings.healthSyncEnabled,
              !appSettingsStore.settings.healthSyncUserDisabled, healthSync.isAvailable else {
            await healthSync.stopSyncing()
            return
        }
        // Reinstall after foreground as Settings can independently stop delivery.
        await healthSync.enableBackgroundDelivery()
        healthSync.startObservingChanges { [weak self] in
            try await self?.syncIfNeeded()
        }
        try await syncIfNeeded()
    }

    func syncIfNeeded() async throws {
        guard appSettingsStore.settings.healthSyncEnabled, !appSettingsStore.settings.healthSyncUserDisabled else { return }
        if let currentSync {
            needsAnotherSync = true
            try await currentSync.value
            return
        }
        let task = Task { @MainActor [self] in
            repeat {
                needsAnotherSync = false
                guard appSettingsStore.settings.healthSyncEnabled, !appSettingsStore.settings.healthSyncUserDisabled else { return }
                do {
                    try await syncHealthDataUseCase.execute()
                    healthSync.markImportRetryNeeded(false)
                } catch {
                    healthSync.markImportRetryNeeded(true)
                    throw error
                }
                var settings = appSettingsStore.settings
                guard settings.healthSyncEnabled, !settings.healthSyncUserDisabled else { return }
                settings.healthLastSyncedAt = Date()
                appSettingsStore.settings = settings
            } while needsAnotherSync
        }
        currentSync = task
        defer { currentSync = nil }
        try await task.value
    }
}
