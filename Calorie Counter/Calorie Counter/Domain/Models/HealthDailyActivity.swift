import Foundation

nonisolated struct HealthDailyActivity: Equatable, Sendable {
    let date: Date
    let activeEnergyKilocalories: Double?
    let steps: Double?
}

protocol HealthDailyActivityStoring {
    func fetch(from start: Date, to end: Date) throws -> [HealthDailyActivity]
    func replace(_ days: [HealthDailyActivity], from start: Date, to end: Date) throws
}
