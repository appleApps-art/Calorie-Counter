import Foundation

final class LogWaterUseCase {
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let awardXPUseCase: AwardXPUseCase?
    private let healthSync: HealthSyncing?
    private let appSettingsStore: AppSettingsStoring?
    private let analytics: AnalyticsTracking?

    init(
        waterEntryRepository: WaterEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil,
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil,
        analytics: AnalyticsTracking? = nil
    ) {
        self.waterEntryRepository = waterEntryRepository
        self.awardXPUseCase = awardXPUseCase
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
        self.analytics = analytics
    }

    func execute(
        amountMilliliters: Double,
        date: Date = Date(),
        source: String? = nil,
        healthSampleID: String? = nil,
        syncToHealth: Bool = true,
        awardXP: Bool = true
    ) throws -> WaterEntry {
        let entry = WaterEntry(
            id: UUID(),
            amountMilliliters: amountMilliliters,
            date: date,
            source: source,
            healthSampleID: healthSampleID
        )
        try waterEntryRepository.save(entry)
        if awardXP {
            try awardXPUseCase?.execute(kind: .water, relatedID: entry.id)
        }
        if entry.source != HealthSyncSource.healthKit {
            analytics?.track(.waterLogged(amountMilliliters: Int(amountMilliliters.rounded())))
        }
        let settings = appSettingsStore?.settings
        if syncToHealth,
           settings?.healthSyncEnabled == true,
           settings?.healthSyncWater == true,
           entry.source != HealthSyncSource.healthKit
        {
            HealthExportQueue.shared.enqueue(entryID: entry.id) { [healthSync] in
                try await healthSync?.saveWater(
                    milliliters: amountMilliliters,
                    date: date,
                    entryID: entry.id
                )
            }
        }
        return entry
    }
}
