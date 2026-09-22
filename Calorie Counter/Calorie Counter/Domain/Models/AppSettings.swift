import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Equatable {
    case system
    case light
    case dark

    var localizedTitle: String {
        L10n.tr("settings.theme.\(rawValue)")
    }
}

struct AppSettings: Equatable, Codable {
    var healthSyncEnabled: Bool
    var healthSyncWeight: Bool
    var healthSyncWater: Bool
    var healthSyncWorkouts: Bool
    var healthSyncFood: Bool
    var healthSyncProfile: Bool
    var healthAuthorizationRequested: Bool
    var healthLastSyncedAt: Date?
    var healthSyncUserDisabled: Bool
    var automaticallyAdjustNutritionGoals: Bool
    var nutritionGoalModeResolved: Bool
    var waterGlassMilliliters: Double
    var usesMetric: Bool
    var appearanceMode: AppearanceMode
    var hasSeenAIIntro: Bool
    var hasSeenAppRating: Bool

    static let `default` = AppSettings(
        healthSyncEnabled: false,
        healthSyncWeight: true,
        healthSyncWater: true,
        healthSyncWorkouts: true,
        healthSyncFood: true,
        healthSyncProfile: true,
        healthAuthorizationRequested: false,
        healthLastSyncedAt: nil,
        waterGlassMilliliters: 150,
        usesMetric: true,
        appearanceMode: .system,
        hasSeenAIIntro: false,
        hasSeenAppRating: false
    )

    init(
        healthSyncEnabled: Bool,
        healthSyncWeight: Bool,
        healthSyncWater: Bool,
        healthSyncWorkouts: Bool,
        healthSyncFood: Bool,
        healthSyncProfile: Bool,
        healthAuthorizationRequested: Bool,
        healthLastSyncedAt: Date? = nil,
        waterGlassMilliliters: Double = 150,
        usesMetric: Bool = true,
        appearanceMode: AppearanceMode = .system,
        hasSeenAIIntro: Bool = false,
        hasSeenAppRating: Bool = false,
        healthSyncUserDisabled: Bool = false,
        automaticallyAdjustNutritionGoals: Bool = true,
        nutritionGoalModeResolved: Bool = true
    ) {
        self.healthSyncEnabled = healthSyncEnabled
        self.healthSyncWeight = healthSyncWeight
        self.healthSyncWater = healthSyncWater
        self.healthSyncWorkouts = healthSyncWorkouts
        self.healthSyncFood = healthSyncFood
        self.healthSyncProfile = healthSyncProfile
        self.healthAuthorizationRequested = healthAuthorizationRequested
        self.healthLastSyncedAt = healthLastSyncedAt
        self.healthSyncUserDisabled = healthSyncUserDisabled
        self.automaticallyAdjustNutritionGoals = automaticallyAdjustNutritionGoals
        self.nutritionGoalModeResolved = nutritionGoalModeResolved
        self.waterGlassMilliliters = waterGlassMilliliters
        self.usesMetric = usesMetric
        self.appearanceMode = appearanceMode
        self.hasSeenAIIntro = hasSeenAIIntro
        self.hasSeenAppRating = hasSeenAppRating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        healthSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .healthSyncEnabled) ?? false
        healthSyncWeight = try container.decodeIfPresent(Bool.self, forKey: .healthSyncWeight) ?? true
        healthSyncWater = try container.decodeIfPresent(Bool.self, forKey: .healthSyncWater) ?? true
        healthSyncWorkouts = try container.decodeIfPresent(Bool.self, forKey: .healthSyncWorkouts) ?? true
        healthSyncFood = try container.decodeIfPresent(Bool.self, forKey: .healthSyncFood) ?? true
        healthSyncProfile = try container.decodeIfPresent(Bool.self, forKey: .healthSyncProfile) ?? true
        healthAuthorizationRequested = try container.decodeIfPresent(Bool.self, forKey: .healthAuthorizationRequested) ?? false
        healthLastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .healthLastSyncedAt)
        healthSyncUserDisabled = try container.decodeIfPresent(Bool.self, forKey: .healthSyncUserDisabled) ?? false
        automaticallyAdjustNutritionGoals = try container.decodeIfPresent(Bool.self, forKey: .automaticallyAdjustNutritionGoals) ?? true
        nutritionGoalModeResolved = try container.decodeIfPresent(Bool.self, forKey: .nutritionGoalModeResolved)
            ?? container.contains(.automaticallyAdjustNutritionGoals)
        waterGlassMilliliters = try container.decodeIfPresent(Double.self, forKey: .waterGlassMilliliters) ?? 150
        usesMetric = try container.decodeIfPresent(Bool.self, forKey: .usesMetric) ?? true
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        hasSeenAIIntro = try container.decodeIfPresent(Bool.self, forKey: .hasSeenAIIntro) ?? false
        hasSeenAppRating = try container.decodeIfPresent(Bool.self, forKey: .hasSeenAppRating) ?? false
    }
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
    /// The numbers behind the paywall copy: the price per month of a yearly plan, the savings badge
    /// and the free-trial timeline all come from these.
    var price: Decimal? = nil
    var priceLocale: Locale? = nil
    var period: SubscriptionPeriod? = nil
    var freeTrialDays: Int? = nil
    /// Stand-in plans shown until the store returns real products; they cannot be bought.
    var isPlaceholder = false

    /// The design's plans, shown while App Store products are not set up or cannot load.
    static let placeholders: [SubscriptionProduct] = [
        SubscriptionProduct(
            id: "bity.placeholder.yearly",
            displayName: "Bity Premium",
            displayPrice: "$49.99",
            periodLabel: "",
            price: Decimal(string: "49.99"),
            priceLocale: Locale(identifier: "en_US"),
            period: SubscriptionPeriod(unit: .year, count: 1),
            freeTrialDays: 7,
            isPlaceholder: true
        ),
        SubscriptionProduct(
            id: "bity.placeholder.monthly",
            displayName: "Bity Premium",
            displayPrice: "$9.99",
            periodLabel: "",
            price: Decimal(string: "9.99"),
            priceLocale: Locale(identifier: "en_US"),
            period: SubscriptionPeriod(unit: .month, count: 1),
            freeTrialDays: nil,
            isPlaceholder: true
        )
    ]
}

struct SubscriptionPeriod: Equatable {
    enum Unit: String {
        case day
        case week
        case month
        case year
    }

    var unit: Unit
    var count: Int

    /// Length in weeks, to compare plans of different periods.
    var weeks: Double {
        let count = Double(max(count, 1))
        switch unit {
        case .day: return count / 7
        case .week: return count
        case .month: return count * 52 / 12
        case .year: return count * 52
        }
    }

    var days: Int {
        let count = max(self.count, 1)
        switch unit {
        case .day: return count
        case .week: return count * 7
        case .month: return count * 30
        case .year: return count * 365
        }
    }
}

enum SubscriptionPlacement: String, CaseIterable, Equatable {
    case onboarding
    case main
    case settings
}

struct SubscriptionOffer: Equatable {
    var placement: SubscriptionPlacement
    var products: [SubscriptionProduct]
    var hasPaywallBuilder: Bool
}

struct SubscriptionPaywallEvents {
    var onPurchased: (SubscriptionStatus) -> Void
    var onRestored: (SubscriptionStatus) -> Void
    var onCancelled: () -> Void
    var onClosed: () -> Void
    var onError: (Error) -> Void
    var onCustomAction: (String) -> Void

    init(
        onPurchased: @escaping (SubscriptionStatus) -> Void = { _ in },
        onRestored: @escaping (SubscriptionStatus) -> Void = { _ in },
        onCancelled: @escaping () -> Void = {},
        onClosed: @escaping () -> Void = {},
        onError: @escaping (Error) -> Void = { _ in },
        onCustomAction: @escaping (String) -> Void = { _ in }
    ) {
        self.onPurchased = onPurchased
        self.onRestored = onRestored
        self.onCancelled = onCancelled
        self.onClosed = onClosed
        self.onError = onError
        self.onCustomAction = onCustomAction
    }
}

enum SubscriptionError: LocalizedError {
    case productUnavailable
    case cancelled
    case pending
    case unverified
    case failed
    case paywallUnavailable
    case placementFailed

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
        case .paywallUnavailable:
            return L10n.tr("subscription.paywallUnavailable")
        case .placementFailed:
            return L10n.tr("subscription.placementFailed")
        }
    }
}

struct ChatHistoryMessage: Identifiable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let createdAt: Date
    let conversationID: UUID?

    init(id: UUID, role: String, content: String, createdAt: Date, conversationID: UUID? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.conversationID = conversationID
    }
}

struct DailyMacroPoint: Equatable {
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double
    let waterMilliliters: Double
}

enum ProgressChartPeriod: CaseIterable, Equatable {
    case week
    case month
    case threeMonths
    case sixMonths

    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        }
    }

    var title: String {
        switch self {
        case .week: return L10n.tr("progress.period.week")
        case .month: return L10n.tr("progress.period.month")
        case .threeMonths: return L10n.tr("progress.period.threeMonths")
        case .sixMonths: return L10n.tr("progress.period.sixMonths")
        }
    }
}

struct ProgressSummary: Equatable {
    var weightEntries: [WeightEntry]
    var caloriePoints: [DailyMacroPoint]
    var workouts: [WorkoutEntry]
    var photos: [ProgressPhoto]
    var rewards: RewardState
    var streak: StreakSnapshot
    var goals: UserGoals
    var activityBurnTarget: Double
    var healthActivity: [HealthDailyActivity] = []
}
