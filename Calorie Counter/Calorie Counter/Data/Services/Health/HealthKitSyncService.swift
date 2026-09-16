import Foundation
import HealthKit

nonisolated protocol HealthSyncing: AnyObject {
    var isAvailable: Bool { get }
    func authorizationSnapshot() -> HealthAuthorizationSnapshot
    func needsAuthorizationPrompt() async -> Bool
    func requestAuthorization() async throws -> Bool
    func enableBackgroundDelivery() async
    func stopSyncing() async
    func startObservingChanges(_ handler: @escaping @Sendable () async throws -> Void)
    func saveWeight(_ kilograms: Double, date: Date, entryID: UUID) async throws
    func saveWater(milliliters: Double, date: Date, entryID: UUID) async throws
    func saveWorkout(_ entry: WorkoutEntry) async throws
    func saveFood(_ entry: FoodEntry) async throws
    func saveHeight(_ centimeters: Double, date: Date, entryID: UUID) async throws
    func deleteSamples(entryID: UUID) async throws
    func fetchLatestWeight() async throws -> Double?
    func fetchWeightChanges() async throws -> HealthAnchoredChange<HealthQuantitySample>
    func fetchWaterChanges() async throws -> HealthAnchoredChange<HealthQuantitySample>
    func fetchWorkoutChanges() async throws -> HealthAnchoredChange<HealthWorkoutSample>
    func fetchNutritionChanges() async throws -> HealthAnchoredChange<HealthNutritionSample>
    func fetchProfileSnapshot() async throws -> HealthProfileSnapshot
    func fetchNutritionChanges(from start: Date) async throws -> HealthAnchoredChange<HealthNutritionSample>
    func fetchDailyActivity(from start: Date, to end: Date) async throws -> [HealthDailyActivity]
    func commit(_ checkpoint: HealthSyncCheckpoint)
    func markImportRetryNeeded(_ isNeeded: Bool)
}

extension HealthSyncing {
    func fetchNutritionChanges(from start: Date) async throws -> HealthAnchoredChange<HealthNutritionSample> {
        try await fetchNutritionChanges()
    }
    func fetchDailyActivity(from start: Date, to end: Date) async throws -> [HealthDailyActivity] { [] }
    func commit(_ checkpoint: HealthSyncCheckpoint) {}
    func markImportRetryNeeded(_ isNeeded: Bool) {}
}

nonisolated final class HealthKitSyncService: HealthSyncing, @unchecked Sendable {
    private enum Metadata {
        static let sourceKey = "bity.source"
        static let entryIDKey = "bity.entry_id"
        static let sourceValue = "bity"
    }

    private let store: HKHealthStore?
    private let defaults: UserDefaults
    private let metadataLock = NSLock()
    private var observerQueries: [HKObserverQuery] = []
    private var onChange: (@Sendable () async throws -> Void)?
    private let lookbackDays = 14

    init(defaults: UserDefaults = .standard) {
        store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
        self.defaults = defaults
    }

    var isAvailable: Bool {
        store != nil
    }

    func authorizationSnapshot() -> HealthAuthorizationSnapshot {
        guard let store else { return .unavailable }
        let types = HealthPermissionKind.allCases.compactMap { kind -> HealthTypeAuthorization? in
            guard let objectType = objectType(for: kind) else { return nil }
            return HealthTypeAuthorization(
                kind: kind,
                isAuthorized: store.authorizationStatus(for: objectType) == .sharingAuthorized
            )
        }
        return HealthAuthorizationSnapshot(
            isAvailable: true, types: types,
            canAttemptRead: defaults.bool(forKey: "bity.health.authorizationCompleted")
        )
    }

    func needsAuthorizationPrompt() async -> Bool {
        guard let store else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: shareTypes, read: readTypes)
        // Complete one authorization request after upgrading from the old
        // write-based gate, even if HealthKit needs no new permission sheet.
        return !defaults.bool(forKey: "bity.health.authorizationCompleted") || status == .shouldRequest
    }

    func requestAuthorization() async throws -> Bool {
        guard let store else { return false }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        defaults.set(true, forKey: "bity.health.authorizationCompleted")
        return true
    }

    func enableBackgroundDelivery() async {
        guard let store else { return }
        for type in observedTypes {
            try? await store.enableBackgroundDelivery(for: type, frequency: .immediate)
        }
    }

    func stopSyncing() async {
        guard let store else { return }
        observerQueries.forEach(store.stop)
        observerQueries = []
        onChange = nil
        for type in observedTypes {
            try? await store.disableBackgroundDelivery(for: type)
        }
    }

    func startObservingChanges(_ handler: @escaping @Sendable () async throws -> Void) {
        guard let store else { return }
        onChange = handler
        observerQueries.forEach(store.stop)
        observerQueries = observedTypes.map { type in
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                Task {
                    await Self.processObserverDelivery(
                        error: error,
                        synchronize: { try await self?.onChange?() },
                        markRetry: { self?.markImportRetryNeeded($0) },
                        completion: completion
                    )
                }
            }
            store.execute(query)
            return query
        }
    }

    static func processObserverDelivery(
        error: Error?,
        synchronize: () async throws -> Void,
        markRetry: (Bool) -> Void,
        completion: () -> Void
    ) async {
        // Always acknowledge after processing, including failure: withholding
        // three acknowledgments can disable future HealthKit background delivery.
        defer { completion() }
        guard error == nil else { markRetry(true); return }
        do { try await synchronize(); markRetry(false) }
        catch { markRetry(true) }
    }

    func markImportRetryNeeded(_ isNeeded: Bool) {
        // Foreground performs a fresh sync even after an interrupted background
        // delivery. Checkpoints remain unchanged for any unpersisted batch.
        defaults.set(isNeeded, forKey: "bity.health.pendingImportRetry")
    }

    func saveWeight(_ kilograms: Double, date: Date, entryID: UUID) async throws {
        guard let store, let type = HKQuantityType.quantityType(forIdentifier: .bodyMass), store.authorizationStatus(for: type) == .sharingAuthorized else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata(entryID: entryID)
        )
        try await store.save(sample)
    }

    func saveWater(milliliters: Double, date: Date, entryID: UUID) async throws {
        guard let store, let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater), store.authorizationStatus(for: type) == .sharingAuthorized else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters)
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata(entryID: entryID)
        )
        try await store.save(sample)
    }

    func saveHeight(_ centimeters: Double, date: Date, entryID: UUID) async throws {
        guard let store, let type = HKQuantityType.quantityType(forIdentifier: .height), store.authorizationStatus(for: type) == .sharingAuthorized else { return }
        let quantity = HKQuantity(unit: .meterUnit(with: .centi), doubleValue: centimeters)
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: date,
            end: date,
            metadata: metadata(entryID: entryID)
        )
        try await store.save(sample)
    }

    func saveFood(_ entry: FoodEntry) async throws {
        guard let store else { return }
        let samples = nutritionSamples(for: entry).filter { store.authorizationStatus(for: $0.quantityType) == .sharingAuthorized }
        guard !samples.isEmpty else { return }
        try await store.save(samples)
    }

    func saveWorkout(_ entry: WorkoutEntry) async throws {
        guard let store, store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutActivityType(for: entry.name)
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
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned), store.authorizationStatus(for: energyType) == .sharingAuthorized {
            let energy = HKQuantity(unit: .kilocalorie(), doubleValue: entry.caloriesBurned)
            let sample = HKQuantitySample(
                type: energyType,
                quantity: energy,
                start: start,
                end: end,
                metadata: metadata(entryID: entry.id, kind: "workoutEnergy")
            )
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
            builder.addMetadata(metadata(entryID: entry.id, kind: "workout")) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
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

    func deleteSamples(entryID: UUID) async throws {
        guard let store else { return }
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: Metadata.entryIDKey,
            allowedValues: [entryID.uuidString]
        )
        for type in deletableTypes {
            let samples = try await querySamples(type: type, predicate: predicate, limit: HKObjectQueryNoLimit)
            if !samples.isEmpty {
                try await store.delete(samples)
            }
        }
    }

    func fetchLatestWeight() async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let samples = try await querySamples(type: type, predicate: nil, limit: 1, ascending: false)
        let sample = samples.first as? HKQuantitySample
        return sample?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    func fetchWeightChanges() async throws -> HealthAnchoredChange<HealthQuantitySample> {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return HealthAnchoredChange(added: [], deletedIDs: [])
        }
        let change = try await fetchAnchored(type: type, anchorKey: "weight")
        let added = change.added.compactMap { sample -> HealthQuantitySample? in
            guard let quantity = sample as? HKQuantitySample, !isFromBity(sample) else { return nil }
            return HealthQuantitySample(
                id: quantity.uuid,
                value: quantity.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                date: quantity.startDate
            )
        }
        return HealthAnchoredChange(added: added, deletedIDs: change.deletedIDs, checkpoint: change.checkpoint)
    }

    func fetchWaterChanges() async throws -> HealthAnchoredChange<HealthQuantitySample> {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return HealthAnchoredChange(added: [], deletedIDs: [])
        }
        let change = try await fetchAnchored(type: type, anchorKey: "water")
        let added = change.added.compactMap { sample -> HealthQuantitySample? in
            guard let quantity = sample as? HKQuantitySample, !isFromBity(sample) else { return nil }
            return HealthQuantitySample(
                id: quantity.uuid,
                value: quantity.quantity.doubleValue(for: .literUnit(with: .milli)),
                date: quantity.startDate
            )
        }
        return HealthAnchoredChange(added: added, deletedIDs: change.deletedIDs, checkpoint: change.checkpoint)
    }

    func fetchWorkoutChanges() async throws -> HealthAnchoredChange<HealthWorkoutSample> {
        let change = try await fetchAnchored(type: HKObjectType.workoutType(), anchorKey: "workout")
        let added = change.added.compactMap { sample -> HealthWorkoutSample? in
            guard let workout = sample as? HKWorkout, !isFromBity(workout) else { return nil }
            let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            return HealthWorkoutSample(
                id: workout.uuid,
                name: workoutName(for: workout.workoutActivityType),
                durationMinutes: max(1, workout.duration / 60),
                caloriesBurned: calories,
                date: workout.startDate
            )
        }
        return HealthAnchoredChange(added: added, deletedIDs: change.deletedIDs, checkpoint: change.checkpoint)
    }

    func fetchNutritionChanges() async throws -> HealthAnchoredChange<HealthNutritionSample> {
        try await fetchNutritionChanges(from: lookbackStart)
    }

    func fetchNutritionChanges(from start: Date) async throws -> HealthAnchoredChange<HealthNutritionSample> {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            return HealthAnchoredChange(added: [], deletedIDs: [])
        }
        let change = try await fetchAnchored(type: energyType, anchorKey: "nutrition")
        // Re-read known meals as well as additions: another app can save or edit
        // nutrients after saving energy, without changing the energy sample UUID.
        let earliest = min(start, change.added.map(\.startDate).min() ?? start)
        let predicate = HKQuery.predicateForSamples(withStart: earliest, end: nil)
        var quantities: [HKQuantitySample] = []
        for identifier in Self.nutritionIdentifiers {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            quantities += try await querySamples(type: type, predicate: predicate, limit: HKObjectQueryNoLimit)
                .compactMap { $0 as? HKQuantitySample }.filter { !isFromBity($0) }
        }
        let correlations = try await fetchFoodCorrelations(predicate: predicate)
        let result = Self.associateNutrition(quantities: quantities, correlations: correlations)
        return HealthAnchoredChange(
            added: result.samples,
            deletedIDs: Array(Set(change.deletedIDs + result.supersededIDs)),
            checkpoint: change.checkpoint
        )
    }

    func fetchDailyActivity(from start: Date, to end: Date) async throws -> [HealthDailyActivity] {
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: start)
        let energy = try await dailyStatistics(.activeEnergyBurned, unit: .kilocalorie(), from: firstDay, to: end)
        let steps = try await dailyStatistics(.stepCount, unit: .count(), from: firstDay, to: end)
        var result: [HealthDailyActivity] = []
        var day = firstDay
        while day < end {
            result.append(HealthDailyActivity(date: day, activeEnergyKilocalories: energy[day], steps: steps[day]))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    func commit(_ checkpoint: HealthSyncCheckpoint) {
        defaults.set(checkpoint.data, forKey: anchorDefaultsKey(checkpoint.key))
    }

    func fetchProfileSnapshot() async throws -> HealthProfileSnapshot {
        guard let store else { return HealthProfileSnapshot() }
        var snapshot = HealthProfileSnapshot()
        if let sex = try? store.biologicalSex().biologicalSex {
            switch sex {
            case .female:
                snapshot.sex = .female
            case .male:
                snapshot.sex = .male
            case .other:
                snapshot.sex = .other
            default:
                break
            }
        }
        if let components = try? store.dateOfBirthComponents(),
           let date = Calendar.current.date(from: components)
        {
            snapshot.age = Calendar.current.dateComponents([.year], from: date, to: Date()).year
        }
        if let heightType = HKQuantityType.quantityType(forIdentifier: .height),
           let sample = try await querySamples(type: heightType, predicate: nil, limit: 1, ascending: false).first as? HKQuantitySample
        {
            snapshot.heightCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
        }
        snapshot.weightKg = try await fetchLatestWeight()
        return snapshot
    }

    private var shareTypes: Set<HKSampleType> {
        Set([
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .height),
            HKObjectType.quantityType(forIdentifier: .dietaryWater),
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKObjectType.quantityType(forIdentifier: .dietaryProtein),
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
            HKObjectType.quantityType(forIdentifier: .dietaryFiber),
            HKObjectType.quantityType(forIdentifier: .dietarySugar),
            HKObjectType.quantityType(forIdentifier: .dietarySodium),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.workoutType(),
        ].compactMap { $0 })
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = Set(shareTypes.map { $0 as HKObjectType })
        types.insert(HKObjectType.characteristicType(forIdentifier: .biologicalSex)!)
        types.insert(HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!)
        return types
    }

    private var observedTypes: [HKSampleType] {
        [
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .height),
            HKObjectType.quantityType(forIdentifier: .dietaryWater),
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKObjectType.quantityType(forIdentifier: .dietaryProtein),
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
            HKObjectType.quantityType(forIdentifier: .dietaryFiber),
            HKObjectType.quantityType(forIdentifier: .dietarySugar),
            HKObjectType.quantityType(forIdentifier: .dietarySodium),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.workoutType(),
        ].compactMap { $0 }
    }

    private func objectType(for kind: HealthPermissionKind) -> HKObjectType? {
        switch kind {
        case .activeEnergy:
            return HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        case .steps:
            return HKObjectType.quantityType(forIdentifier: .stepCount)
        case .workouts:
            return HKObjectType.workoutType()
        case .weight:
            return HKObjectType.quantityType(forIdentifier: .bodyMass)
        case .water:
            return HKObjectType.quantityType(forIdentifier: .dietaryWater)
        case .nutrition:
            return HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        case .height:
            return HKObjectType.quantityType(forIdentifier: .height)
        }
    }

    private var deletableTypes: [HKSampleType] {
        Array(shareTypes)
    }

    private var lookbackStart: Date {
        Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
    }

    private func metadata(entryID: UUID, kind: String = "entry") -> [String: Any] {
        metadataLock.lock()
        defer { metadataLock.unlock() }
        let key = "bity.health.exportVersion." + entryID.uuidString
        let version = max(Int(Date().timeIntervalSince1970 * 1000), defaults.integer(forKey: key) + 1)
        defaults.set(version, forKey: key)
        return [
            Metadata.sourceKey: Metadata.sourceValue,
            Metadata.entryIDKey: entryID.uuidString,
            HKMetadataKeyExternalUUID: entryID.uuidString,
            HKMetadataKeySyncIdentifier: entryID.uuidString + "." + kind,
            HKMetadataKeySyncVersion: version,
        ]
    }

    private func isFromBity(_ sample: HKObject) -> Bool {
        sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier
            || sample.metadata?[Metadata.sourceKey] as? String == Metadata.sourceValue
    }

    private func nutritionSamples(for entry: FoodEntry) -> [HKQuantitySample] {
        let date = entry.date
        var samples: [HKQuantitySample] = []
        func add(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, value: Double) {
            guard value > 0, let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
            samples.append(
                HKQuantitySample(
                    type: type,
                    quantity: HKQuantity(unit: unit, doubleValue: value),
                    start: date,
                    end: date,
                    metadata: metadata(entryID: entry.id, kind: identifier.rawValue)
                )
            )
        }
        add(.dietaryEnergyConsumed, unit: .kilocalorie(), value: entry.calories)
        add(.dietaryProtein, unit: .gram(), value: entry.protein)
        add(.dietaryCarbohydrates, unit: .gram(), value: entry.carbs)
        add(.dietaryFatTotal, unit: .gram(), value: entry.fats)
        add(.dietaryFiber, unit: .gram(), value: entry.fiber)
        add(.dietarySugar, unit: .gram(), value: entry.sugar)
        add(.dietarySodium, unit: .gram(), value: entry.sodium / 1000)
        return samples
    }

    private static let nutritionIdentifiers: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal,
        .dietaryFiber, .dietarySugar, .dietarySodium,
    ]

    private func fetchFoodCorrelations(predicate: NSPredicate) async throws -> [HKCorrelation] {
        guard let store, let type = HKCorrelationType.correlationType(forIdentifier: .food) else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKCorrelationQuery(type: type, predicate: predicate, samplePredicates: nil) { _, correlations, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: correlations ?? []) }
            }
            store.execute(query)
        }
    }

    /// Correlated foods retain their actual nutrient association. For producers
    /// without correlations, combine samples only within the same source and
    /// explicit external identifier (or exact timestamp), and emit one meal for
    /// that group so nutrients can never be copied onto multiple energy records.
    static func associateNutrition(
        quantities: [HKQuantitySample], correlations: [HKCorrelation]
    ) -> (samples: [HealthNutritionSample], supersededIDs: [UUID]) {
        let visible = Dictionary(quantities.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        var claimed = Set<UUID>()
        var groups: [[HKQuantitySample]] = []
        let energyID = HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue
        for correlation in correlations.sorted(by: { $0.uuid.uuidString < $1.uuid.uuidString }) {
            let members = correlation.objects.compactMap { visible[$0.uuid] }.filter { !claimed.contains($0.uuid) }
            guard members.contains(where: { $0.quantityType.identifier == energyID }) else { continue }
            groups.append(members)
            claimed.formUnion(members.map(\.uuid))
        }
        struct GroupKey: Hashable {
            let source: String
            let identity: String
        }
        let remaining = quantities.filter { !claimed.contains($0.uuid) }
        var parents = Array(remaining.indices)
        func root(_ index: Int) -> Int {
            var result = index
            while parents[result] != result { result = parents[result] }
            return result
        }
        var ownerByKey: [GroupKey: Int] = [:]
        for (index, sample) in remaining.enumerated() {
            let source = sample.sourceRevision.source.bundleIdentifier
            var identities = ["date:" + String(sample.startDate.timeIntervalSince1970)]
            if let externalID = sample.metadata?[HKMetadataKeyExternalUUID] as? String {
                identities.append("id:" + externalID)
            }
            // Some producers attach the shared ID only to energy. Link the
            // exact-time nutrients too, while keeping different sources apart.
            for identity in identities {
                let key = GroupKey(source: source, identity: identity)
                if let previous = ownerByKey[key] { parents[root(index)] = root(previous) }
                else { ownerByKey[key] = index }
            }
        }
        let joined = Dictionary(grouping: remaining.indices, by: root)
        groups += joined.values.map { $0.map { remaining[$0] } }
        var samples: [HealthNutritionSample] = []
        var supersededIDs: [UUID] = []
        for group in groups {
            let energies = group.filter { $0.quantityType.identifier == energyID }.sorted { $0.uuid.uuidString < $1.uuid.uuidString }
            guard let first = energies.first else { continue }
            func total(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) -> Double {
                group.filter { $0.quantityType.identifier == identifier.rawValue }
                    .reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
            }
            samples.append(HealthNutritionSample(
                id: first.uuid, date: first.startDate,
                calories: total(.dietaryEnergyConsumed, unit: .kilocalorie()),
                protein: total(.dietaryProtein, unit: .gram()),
                carbs: total(.dietaryCarbohydrates, unit: .gram()),
                fats: total(.dietaryFatTotal, unit: .gram()),
                fiber: total(.dietaryFiber, unit: .gram()),
                sugar: total(.dietarySugar, unit: .gram()),
                sodium: total(.dietarySodium, unit: .gram()) * 1000
            ))
            supersededIDs += energies.dropFirst().map(\.uuid)
        }
        return (samples.sorted { $0.date < $1.date }, supersededIDs)
    }

    private func dailyStatistics(
        _ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date
    ) async throws -> [Date: Double] {
        guard let store, let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [:] }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate),
            NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default())),
            NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(withMetadataKey: Metadata.sourceKey, allowedValues: [Metadata.sourceValue])),
        ])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type, quantitySamplePredicate: predicate,
                options: .cumulativeSum, anchorDate: start, intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                var values: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    if let quantity = statistics.sumQuantity() {
                        values[Calendar.current.startOfDay(for: statistics.startDate)] = quantity.doubleValue(for: unit)
                    }
                }
                continuation.resume(returning: values)
            }
            store.execute(query)
        }
    }

    private func fetchAnchored(
        type: HKSampleType,
        anchorKey: String
    ) async throws -> (added: [HKSample], deletedIDs: [UUID], checkpoint: HealthSyncCheckpoint?) {
        guard let store else { return ([], [], nil) }
        let anchor = loadAnchor(anchorKey)
        let initialStart = lookbackStart
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deleted, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let checkpoint = newAnchor.flatMap { anchor -> HealthSyncCheckpoint? in
                    guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else { return nil }
                    return HealthSyncCheckpoint(key: anchorKey, data: data)
                }
                let added = (samples ?? []).filter { anchor != nil || $0.startDate >= initialStart }
                continuation.resume(returning: (added, (deleted ?? []).map(\.uuid), checkpoint))
            }
            store.execute(query)
        }
    }

    private func querySamples(
        type: HKSampleType,
        predicate: NSPredicate?,
        limit: Int,
        ascending: Bool = true
    ) async throws -> [HKSample] {
        guard let store else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: ascending)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func loadAnchor(_ key: String) -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: anchorDefaultsKey(key)) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func anchorDefaultsKey(_ key: String) -> String {
        "bity.health.anchor.v2.\(key)"
    }

    private func workoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return L10n.tr("health.workout.running")
        case .walking: return L10n.tr("health.workout.walking")
        case .cycling: return L10n.tr("health.workout.cycling")
        case .swimming: return L10n.tr("health.workout.swimming")
        case .yoga: return L10n.tr("health.workout.yoga")
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return L10n.tr("health.workout.strength")
        case .coreTraining: return L10n.tr("health.workout.core")
        case .highIntensityIntervalTraining: return L10n.tr("health.workout.hiit")
        case .cardioDance, .socialDance: return L10n.tr("health.workout.dance")
        case .hiking: return L10n.tr("health.workout.hiking")
        case .elliptical: return L10n.tr("health.workout.elliptical")
        case .rowing: return L10n.tr("health.workout.rowing")
        case .stairClimbing, .stairs: return L10n.tr("health.workout.stairs")
        case .pilates: return L10n.tr("health.workout.pilates")
        case .cooldown: return L10n.tr("health.workout.cooldown")
        default: return L10n.tr("health.importedWorkout")
        }
    }

    private func workoutActivityType(for name: String) -> HKWorkoutActivityType {
        let value = name.lowercased()
        if value.contains("run") || value.contains("біг") { return .running }
        if value.contains("walk") || value.contains("ходь") { return .walking }
        if value.contains("cycl") || value.contains("bike") || value.contains("вело") { return .cycling }
        if value.contains("swim") || value.contains("плав") { return .swimming }
        if value.contains("yoga") || value.contains("йог") { return .yoga }
        if value.contains("strength") || value.contains("силов") { return .traditionalStrengthTraining }
        if value.contains("core") || value.contains("кор") { return .coreTraining }
        if value.contains("hiit") { return .highIntensityIntervalTraining }
        if value.contains("dance") || value.contains("танц") { return .cardioDance }
        if value.contains("hik") || value.contains("хайк") { return .hiking }
        if value.contains("ellip") || value.contains("еліп") { return .elliptical }
        if value.contains("row") || value.contains("весл") { return .rowing }
        if value.contains("stair") || value.contains("сход") { return .stairs }
        if value.contains("pilates") || value.contains("пілат") { return .pilates }
        if value.contains("cooldown") || value.contains("заминк") { return .cooldown }
        return .other
    }
}
