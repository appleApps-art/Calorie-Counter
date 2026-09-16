import Foundation

struct WorkoutEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
    let durationMinutes: Double
    let caloriesBurned: Double
    let date: Date
    var source: String? = nil
    var healthSampleID: String? = nil
}
