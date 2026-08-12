import Foundation

enum WaterEntryMapper {
    static func map(_ object: CDWaterEntry) -> WaterEntry? {
        guard let id = object.id, let date = object.date else { return nil }
        return WaterEntry(
            id: id,
            amountMilliliters: object.amountMilliliters,
            date: date
        )
    }

    static func apply(_ entry: WaterEntry, to object: CDWaterEntry) {
        object.id = entry.id
        object.amountMilliliters = entry.amountMilliliters
        object.date = entry.date
    }
}
