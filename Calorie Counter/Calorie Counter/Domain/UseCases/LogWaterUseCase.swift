import Foundation

final class LogWaterUseCase {
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let awardXPUseCase: AwardXPUseCase?
    private let healthSync: HealthSyncing?
    private let appSettingsStore: AppSettingsStoring?

    init(
        waterEntryRepository: WaterEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil,
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil
    ) {
        self.waterEntryRepository = waterEntryRepository
        self.awardXPUseCase = awardXPUseCase
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
    }

    func execute(amountMilliliters: Double, date: Date = Date()) throws -> WaterEntry {
        let entry = WaterEntry(
            id: UUID(),
            amountMilliliters: amountMilliliters,
            date: date
        )
        try waterEntryRepository.save(entry)
        try awardXPUseCase?.execute(kind: .water, relatedID: entry.id)
        let settings = appSettingsStore?.settings
        if settings?.healthSyncEnabled == true, settings?.healthSyncWater == true {
            Task {
                try? await healthSync?.saveWater(milliliters: amountMilliliters, date: date)
            }
        }
        return entry
    }
}
