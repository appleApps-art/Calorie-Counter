import Foundation

struct WaterEntry: Identifiable, Equatable {
    let id: UUID
    let amountMilliliters: Double
    let date: Date
    var source: String? = nil
    var healthSampleID: String? = nil
}
