import Foundation
import HealthKit

protocol HealthSyncing {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws -> Bool
    func saveWeight(_ kilograms: Double, date: Date) async throws
    func saveWater(milliliters: Double, date: Date) async throws
    func saveWorkout(_ entry: WorkoutEntry) async throws
    func fetchLatestWeight() async throws -> Double?
}

final class HealthKitSyncService: HealthSyncing, @unchecked Sendable {
    private let store: HKHealthStore?

    init() {
        store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    var isAvailable: Bool {
        store != nil
    }

    func requestAuthorization() async throws -> Bool {
        guard let store else { return false }
        let types: Set<HKSampleType> = Set([
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .dietaryWater),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.workoutType(),
        ].compactMap { $0 })
        try await store.requestAuthorization(toShare: types, read: types)
        return true
    }

    func saveWeight(_ kilograms: Double, date: Date) async throws {
        guard let store, let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await store.save(sample)
    }

    func saveWater(milliliters: Double, date: Date) async throws {
        guard let store, let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await store.save(sample)
    }

    func saveWorkout(_ entry: WorkoutEntry) async throws {
        guard let store else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        let start = entry.date
        let end = entry.date.addingTimeInterval(max(60, entry.durationMinutes * 60))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: start) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energy = HKQuantity(unit: .kilocalorie(), doubleValue: entry.caloriesBurned)
            let sample = HKQuantitySample(type: energyType, quantity: energy, start: start, end: end)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add([sample]) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: end) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: workout)
                }
            }
        }
    }

    func fetchLatestWeight() async throws -> Double? {
        guard let store, let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: .gramUnit(with: .kilo)))
            }
            store.execute(query)
        }
    }
}
