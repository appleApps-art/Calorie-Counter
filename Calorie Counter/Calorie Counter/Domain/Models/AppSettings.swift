import Foundation

struct AppSettings: Equatable, Codable {
    var healthSyncEnabled: Bool
    var healthSyncWeight: Bool
    var healthSyncWater: Bool
    var healthSyncWorkouts: Bool

    static let `default` = AppSettings(
        healthSyncEnabled: false,
        healthSyncWeight: true,
        healthSyncWater: true,
        healthSyncWorkouts: true
    )
}

enum SubscriptionTier: String, Codable, Equatable {
    case free
    case trial
    case premium
}

struct SubscriptionStatus: Equatable {
    var tier: SubscriptionTier
    var productID: String?
    var expirationDate: Date?
    var isEligibleForTrial: Bool

    var isPremium: Bool {
        tier == .premium || tier == .trial
    }

    static let free = SubscriptionStatus(
        tier: .free,
        productID: nil,
        expirationDate: nil,
        isEligibleForTrial: true
    )
}

struct SubscriptionProduct: Equatable {
    var id: String
    var displayName: String
    var displayPrice: String
    var periodLabel: String
}

enum SubscriptionError: LocalizedError {
    case productUnavailable
    case cancelled
    case pending
    case unverified
    case failed

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return L10n.tr("subscription.unavailable")
        case .cancelled:
            return L10n.tr("subscription.cancelled")
        case .pending:
            return L10n.tr("subscription.pending")
        case .unverified:
            return L10n.tr("subscription.unverified")
        case .failed:
            return L10n.tr("subscription.failed")
        }
    }
}

struct ChatHistoryMessage: Identifiable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let createdAt: Date
}

struct DailyMacroPoint: Equatable {
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fats: Double
    let waterMilliliters: Double
}

struct ProgressSummary: Equatable {
    var weightEntries: [WeightEntry]
    var caloriePoints: [DailyMacroPoint]
    var workouts: [WorkoutEntry]
    var photos: [ProgressPhoto]
    var rewards: RewardState
    var streak: StreakSnapshot
}
