import Foundation

enum XPEventKind: String, Codable, Equatable {
    case food
    case water
    case weight
    case foodSwap
    case progressPhoto
    case workout

    var xpAmount: Int {
        switch self {
        case .food: return 10
        case .water: return 5
        case .weight: return 15
        case .foodSwap: return 20
        case .progressPhoto: return 25
        case .workout: return 10
        }
    }
}

enum RewardLevel: String, Equatable, CaseIterable {
    case rookie = "Rookie"
    case explorer = "Explorer"
    case consistent = "Consistent"
    case dedicated = "Dedicated"
    case masterOfWellness = "Master of Wellness"

    var localizedTitle: String {
        switch self {
        case .rookie: return L10n.tr("level.rookie")
        case .explorer: return L10n.tr("level.explorer")
        case .consistent: return L10n.tr("level.consistent")
        case .dedicated: return L10n.tr("level.dedicated")
        case .masterOfWellness: return L10n.tr("level.master")
        }
    }

    var minimumXP: Int {
        switch self {
        case .rookie: return 0
        case .explorer: return 100
        case .consistent: return 300
        case .dedicated: return 700
        case .masterOfWellness: return 1500
        }
    }

    static func level(for xp: Int) -> RewardLevel {
        let sorted = RewardLevel.allCases.sorted { $0.minimumXP > $1.minimumXP }
        return sorted.first(where: { xp >= $0.minimumXP }) ?? .rookie
    }
}

enum RewardBadge: String, CaseIterable, Equatable {
    case firstMeal = "first_meal"
    case mealTrackerMaster = "meal_tracker_master"
    case hydrationHero = "hydration_hero"
    case weightLogger = "weight_logger"
    case sevenDayStreak = "seven_day_streak"
    case fourteenDayStreak = "fourteen_day_streak"
    case swapStarter = "swap_starter"
    case photoProgress = "photo_progress"
    case workoutSpark = "workout_spark"
    case proteinPro = "protein_pro"
    case earlyBird = "early_bird"
    case balancedDay = "balanced_day"

    var title: String {
        switch self {
        case .firstMeal: return L10n.tr("badge.firstMeal")
        case .mealTrackerMaster: return L10n.tr("badge.mealTrackerMaster")
        case .hydrationHero: return L10n.tr("badge.hydrationHero")
        case .weightLogger: return L10n.tr("badge.weightLogger")
        case .sevenDayStreak: return L10n.tr("badge.sevenDayStreak")
        case .fourteenDayStreak: return L10n.tr("badge.fourteenDayStreak")
        case .swapStarter: return L10n.tr("badge.swapStarter")
        case .photoProgress: return L10n.tr("badge.photoProgress")
        case .workoutSpark: return L10n.tr("badge.workoutSpark")
        case .proteinPro: return L10n.tr("badge.proteinPro")
        case .earlyBird: return L10n.tr("badge.earlyBird")
        case .balancedDay: return L10n.tr("badge.balancedDay")
        }
    }
}

struct XPEvent: Identifiable, Equatable {
    let id: UUID
    let kind: XPEventKind
    let amount: Int
    let date: Date
    let relatedID: UUID?
}

struct RewardState: Equatable {
    var totalXP: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastFoodLogDay: Date?
    var unlockedBadgeIDs: [String]
    var updatedAt: Date

    var level: RewardLevel {
        RewardLevel.level(for: totalXP)
    }

    static let empty = RewardState(
        totalXP: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastFoodLogDay: nil,
        unlockedBadgeIDs: [],
        updatedAt: Date()
    )
}

struct StreakSnapshot: Equatable {
    var current: Int
    var longest: Int
    var lastFoodLogDay: Date?
}
