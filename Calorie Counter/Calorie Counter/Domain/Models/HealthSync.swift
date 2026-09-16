import Foundation

enum HealthSyncSource {
    static let healthKit = "healthkit"
}

nonisolated struct HealthQuantitySample: Equatable {
    let id: UUID
    let value: Double
    let date: Date
}

nonisolated struct HealthWorkoutSample: Equatable {
    let id: UUID
    let name: String
    let durationMinutes: Double
    let caloriesBurned: Double
    let date: Date
}

nonisolated struct HealthNutritionSample: Equatable {
    let id: UUID
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
}

struct HealthProfileSnapshot: Equatable {
    var sex: BiologicalSex?
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
}

nonisolated struct HealthAnchoredChange<Sample: Equatable>: Equatable {
    var added: [Sample]
    var deletedIDs: [UUID]
    var checkpoint: HealthSyncCheckpoint? = nil
}

nonisolated struct HealthSyncCheckpoint: Equatable, Sendable {
    let key: String
    let data: Data
}

enum HealthPermissionKind: Equatable, CaseIterable {
    case activeEnergy
    case steps
    case workouts
    case weight
    case water
    case nutrition
    case height

    var isDisplayed: Bool {
        switch self {
        case .activeEnergy, .steps, .workouts:
            return true
        case .weight, .water, .nutrition, .height:
            return false
        }
    }

    var title: String {
        switch self {
        case .activeEnergy:
            return L10n.tr("settings.health.activeEnergy")
        case .steps:
            return L10n.tr("settings.health.steps")
        case .workouts:
            return L10n.tr("settings.health.workouts")
        case .weight, .water, .nutrition, .height:
            return ""
        }
    }
}

struct HealthTypeAuthorization: Equatable {
    let kind: HealthPermissionKind
    let isAuthorized: Bool
    var canAttemptRead: Bool = false

    var statusTitle: String {
        if canAttemptRead { return L10n.tr("settings.health.accessManaged") }
        return isAuthorized
            ? L10n.tr("settings.health.connected")
            : L10n.tr("settings.health.disconnected")
    }
}

struct HealthAuthorizationSnapshot: Equatable {
    var isAvailable: Bool
    var types: [HealthTypeAuthorization]
    // HealthKit reports write authorization only. A completed request also permits
    // attempting reads, whose authorization state Apple deliberately keeps private.
    var canAttemptRead: Bool = false

    var isConnected: Bool {
        isAvailable && (canAttemptRead || types.contains(where: \.isAuthorized))
    }

    var displayedTypes: [HealthTypeAuthorization] {
        types.filter(\.kind.isDisplayed).map { item in
            var display = item
            display.canAttemptRead = isConnected
            return display
        }
    }

    func isAuthorized(for kind: HealthPermissionKind) -> Bool {
        types.first(where: { $0.kind == kind })?.isAuthorized ?? false
    }

    static let unavailable = HealthAuthorizationSnapshot(isAvailable: false, types: [])

    static let disconnected = HealthAuthorizationSnapshot(
        isAvailable: true,
        types: HealthPermissionKind.allCases.map {
            HealthTypeAuthorization(kind: $0, isAuthorized: false)
        }
    )

    static let authorized = HealthAuthorizationSnapshot(
        isAvailable: true,
        types: HealthPermissionKind.allCases.map {
            HealthTypeAuthorization(kind: $0, isAuthorized: true)
        }
    )
}
