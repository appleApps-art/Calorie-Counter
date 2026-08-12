import Foundation

struct WaterEntry: Identifiable, Equatable {
    let id: UUID
    let amountMilliliters: Double
    let date: Date
}
