import Foundation

struct WeightEntry: Identifiable, Equatable {
    let id: UUID
    let weightKilograms: Double
    let date: Date
}
