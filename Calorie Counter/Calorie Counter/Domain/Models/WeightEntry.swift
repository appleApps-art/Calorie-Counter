import Foundation

struct WeightEntry: Identifiable, Equatable {
    let id: UUID
    let weightKilograms: Double
    let date: Date
    var source: String? = nil
    var healthSampleID: String? = nil
}
