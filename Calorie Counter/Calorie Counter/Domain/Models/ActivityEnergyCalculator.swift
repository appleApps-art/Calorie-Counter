import Foundation

enum ActivityEnergyCalculator {
    static func total(workouts: [WorkoutEntry], healthActivity: HealthDailyActivity?) -> Double {
        let externalWorkouts = workouts.filter { $0.source == HealthSyncSource.healthKit }
            .reduce(0.0) { $0 + validEnergy($1.caloriesBurned) }
        let localWorkouts = workouts.filter { $0.source != HealthSyncSource.healthKit }
            .reduce(0.0) { $0 + validEnergy($1.caloriesBurned) }
        // Health's external active energy already includes external workouts.
        // Bity exports are excluded at query time and counted from the local diary.
        // Prefer the measured daily total even when it is lower than workout
        // energy (for example a workout spanning midnight). Fall back only when
        // no daily measurement was readable; zero is a valid measurement.
        let external = healthActivity?.activeEnergyKilocalories.flatMap { value in
            value.isFinite ? validEnergy(value) : nil
        } ?? externalWorkouts
        return localWorkouts + external
    }

    private static func validEnergy(_ value: Double) -> Double {
        value.isFinite ? max(0, value) : 0
    }
}
