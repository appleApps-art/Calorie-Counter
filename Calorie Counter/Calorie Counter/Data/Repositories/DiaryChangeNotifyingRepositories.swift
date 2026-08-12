import Foundation

final class DiaryChangeNotifyingFoodEntryRepository: FoodEntryRepositoryProtocol {
    private let base: FoodEntryRepositoryProtocol
    private let onChange: () -> Void

    init(base: FoodEntryRepositoryProtocol, onChange: @escaping () -> Void) {
        self.base = base
        self.onChange = onChange
    }

    func fetchEntries(for date: Date) throws -> [FoodEntry] {
        try base.fetchEntries(for: date)
    }

    func fetchEntries(from start: Date, to end: Date) throws -> [FoodEntry] {
        try base.fetchEntries(from: start, to: end)
    }

    func fetchEntry(id: UUID) throws -> FoodEntry? {
        try base.fetchEntry(id: id)
    }

    func save(_ entry: FoodEntry) throws {
        try base.save(entry)
        onChange()
    }

    func delete(id: UUID) throws {
        try base.delete(id: id)
        onChange()
    }
}

final class DiaryChangeNotifyingWaterEntryRepository: WaterEntryRepositoryProtocol {
    private let base: WaterEntryRepositoryProtocol
    private let onChange: () -> Void

    init(base: WaterEntryRepositoryProtocol, onChange: @escaping () -> Void) {
        self.base = base
        self.onChange = onChange
    }

    func fetchEntries(for date: Date) throws -> [WaterEntry] {
        try base.fetchEntries(for: date)
    }

    func fetchEntries(from start: Date, to end: Date) throws -> [WaterEntry] {
        try base.fetchEntries(from: start, to: end)
    }

    func save(_ entry: WaterEntry) throws {
        try base.save(entry)
        onChange()
    }

    func delete(id: UUID) throws {
        try base.delete(id: id)
        onChange()
    }
}

final class DiaryChangeNotifyingWeightEntryRepository: WeightEntryRepositoryProtocol {
    private let base: WeightEntryRepositoryProtocol
    private let onChange: () -> Void

    init(base: WeightEntryRepositoryProtocol, onChange: @escaping () -> Void) {
        self.base = base
        self.onChange = onChange
    }

    func fetchEntries() throws -> [WeightEntry] {
        try base.fetchEntries()
    }

    func fetchEntries(for date: Date) throws -> [WeightEntry] {
        try base.fetchEntries(for: date)
    }

    func fetchEntries(from start: Date, to end: Date) throws -> [WeightEntry] {
        try base.fetchEntries(from: start, to: end)
    }

    func save(_ entry: WeightEntry) throws {
        try base.save(entry)
        onChange()
    }
}
