import Foundation

enum WeightEntryMapper {
    static func map(_ object: CDWeightEntry) -> WeightEntry? {
        guard let id = object.id, let date = object.date else { return nil }
        return WeightEntry(
            id: id,
            weightKilograms: object.weightKilograms,
            date: date
        )
    }

    static func apply(_ entry: WeightEntry, to object: CDWeightEntry) {
        object.id = entry.id
        object.weightKilograms = entry.weightKilograms
        object.date = entry.date
    }
}
