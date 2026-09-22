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
    case rookie
    case explorer
    case consistent
    case healthyExplorer
    case masterOfWellness

    var localizedTitle: String {
        switch self {
        case .rookie: return L10n.tr("level.rookie")
        case .explorer: return L10n.tr("level.explorer")
        case .consistent: return L10n.tr("level.consistent")
        case .healthyExplorer: return L10n.tr("level.healthyExplorer")
        case .masterOfWellness: return L10n.tr("level.master")
        }
    }

    var minimumXP: Int {
        switch self {
        case .rookie: return 0
        case .explorer: return 100
        case .consistent: return 200
        case .healthyExplorer: return 300
        case .masterOfWellness: return 500
        }
    }

    var number: Int {
        (Self.allCases.firstIndex(of: self) ?? 0) + 1
    }

    var next: RewardLevel? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    static func level(for xp: Int) -> RewardLevel {
        let sorted = RewardLevel.allCases.sorted { $0.minimumXP > $1.minimumXP }
        return sorted.first(where: { xp >= $0.minimumXP }) ?? .rookie
    }
}

enum RewardProgressUnit: Equatable {
    case days
    case weeks
    /// A running total, not a streak: food swaps the user has accepted.
    case swaps
}

enum RewardBadge: String, CaseIterable, Equatable {
    case mealTrackerMaster = "meal_tracker_master"
    case hydrationHero = "hydration_hero"
    case consistentWeigher = "consistent_weigher"
    case macroBalancer = "macro_balancer"
    case fiberChampion = "fiber_champion"
    case weekendWarrior = "weekend_warrior"
    case proteinMaster = "protein_master"
    case earlyBirdLogger = "early_bird_logger"
    case smartChoice = "smart_choice"
    case visualJourney = "visual_journey"
    case noLateSnacks = "no_late_snacks"
    case nutrientExplorer = "nutrient_explorer"

    var title: String {
        L10n.tr(titleKey)
    }

    var celebrationTitle: String {
        L10n.tr(celebrationKey)
    }

    var imageName: String {
        switch self {
        case .mealTrackerMaster: return "BadgeMealTracker"
        case .hydrationHero: return "BadgeHydration"
        case .consistentWeigher: return "BadgeWeigher"
        case .macroBalancer: return "BadgeMacro"
        case .fiberChampion: return "BadgeFiber"
        case .weekendWarrior: return "BadgeWeekend"
        case .proteinMaster: return "BadgeProtein"
        case .earlyBirdLogger: return "BadgeEarlyBird"
        case .smartChoice: return "BadgeSmartChoice"
        case .visualJourney: return "BadgeVisualJourney"
        case .noLateSnacks: return "BadgeNoLateSnacks"
        case .nutrientExplorer: return "BadgeNutrientExplorer"
        }
    }

    var unit: RewardProgressUnit {
        switch self {
        // Weigh-ins and progress photos are weekly habits; a daily streak would be the wrong ask.
        case .consistentWeigher, .visualJourney: return .weeks
        case .smartChoice: return .swaps
        default: return .days
        }
    }

    var goal: Int {
        switch self {
        case .mealTrackerMaster: return 7
        case .hydrationHero: return 7
        case .consistentWeigher: return 3
        case .macroBalancer: return 5
        case .fiberChampion: return 7
        case .weekendWarrior: return 2
        case .proteinMaster: return 3
        case .earlyBirdLogger: return 5
        case .smartChoice: return 7
        case .visualJourney: return 4
        case .noLateSnacks: return 3
        case .nutrientExplorer: return 7
        }
    }

    private var titleKey: String {
        switch self {
        case .mealTrackerMaster: return "badge.mealTrackerMaster"
        case .hydrationHero: return "badge.hydrationHero"
        case .consistentWeigher: return "badge.consistentWeigher"
        case .macroBalancer: return "badge.macroBalancer"
        case .fiberChampion: return "badge.fiberChampion"
        case .weekendWarrior: return "badge.weekendWarrior"
        case .proteinMaster: return "badge.proteinMaster"
        case .earlyBirdLogger: return "badge.earlyBirdLogger"
        case .smartChoice: return "badge.smartChoice"
        case .visualJourney: return "badge.visualJourney"
        case .noLateSnacks: return "badge.noLateSnacks"
        case .nutrientExplorer: return "badge.nutrientExplorer"
        }
    }

    private var celebrationKey: String {
        switch self {
        case .mealTrackerMaster: return "rewards.celebration.mealTrackerMaster"
        case .hydrationHero: return "rewards.celebration.hydrationHero"
        case .consistentWeigher: return "rewards.celebration.consistentWeigher"
        case .macroBalancer: return "rewards.celebration.macroBalancer"
        case .fiberChampion: return "rewards.celebration.fiberChampion"
        case .weekendWarrior: return "rewards.celebration.weekendWarrior"
        case .proteinMaster: return "rewards.celebration.proteinMaster"
        case .earlyBirdLogger: return "rewards.celebration.earlyBirdLogger"
        case .smartChoice: return "rewards.celebration.smartChoice"
        case .visualJourney: return "rewards.celebration.visualJourney"
        case .noLateSnacks: return "rewards.celebration.noLateSnacks"
        case .nutrientExplorer: return "rewards.celebration.nutrientExplorer"
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
    var seenBadgeIDs: [String]
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
        seenBadgeIDs: [],
        updatedAt: Date()
    )
}

struct StreakSnapshot: Equatable {
    var current: Int
    var longest: Int
    var lastFoodLogDay: Date?
}

struct BadgeProgress: Equatable {
    let badge: RewardBadge
    let current: Int
    let goal: Int

    var isComplete: Bool { current >= goal }
    /// The badge art only lights up once it is earned, so a badge on its way never looks won.
    var showsLockedArt: Bool { !isComplete }
    var fill: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(current) / Double(goal))
    }

    var listSubtitle: String {
        if current == 0 {
            return unitLabel(goal)
        }
        return progressLabel(current, goal)
    }

    var pillTitle: String {
        let value = current > 0 ? current : goal
        switch badge.unit {
        case .weeks:
            return L10n.format("rewards.weeksActivePill", value)
        case .days:
            return L10n.format("rewards.dayStreakPill", value)
        case .swaps:
            return L10n.format("rewards.swapsPill", value)
        }
    }

    var rewardDetail: String {
        let value = current > 0 ? current : goal
        switch badge.unit {
        case .weeks:
            return L10n.format("rewards.weeksStreakBadge", value)
        case .days:
            return L10n.format("rewards.dayStreakBadge", value)
        case .swaps:
            return L10n.format("rewards.swapsBadge", value)
        }
    }

    var tickLabels: [String] {
        (1...goal).map { index in
            switch badge.unit {
            case .weeks: return L10n.format("rewards.tick.week", index)
            case .days: return L10n.format("rewards.tick.day", index)
            case .swaps: return "\(index)"
            }
        }
    }

    static func awaitingCelebration(in badges: [BadgeProgress], seenIDs: [String]) -> [BadgeProgress] {
        let seen = Set(seenIDs)
        return badges.filter { $0.isComplete && !seen.contains($0.badge.rawValue) }
    }

    private func unitLabel(_ value: Int) -> String {
        switch badge.unit {
        case .weeks: return L10n.format("rewards.weeks", value)
        case .days: return L10n.format("rewards.days", value)
        case .swaps: return L10n.format("rewards.swaps", value)
        }
    }

    private func progressLabel(_ current: Int, _ goal: Int) -> String {
        switch badge.unit {
        case .weeks: return L10n.format("rewards.weeksProgress", current, goal)
        case .days: return L10n.format("rewards.daysProgress", current, goal)
        case .swaps: return L10n.format("rewards.swapsProgress", current, goal)
        }
    }
}

struct RewardsScreenState: Equatable {
    let xp: Int
    let level: RewardLevel
    let badges: [BadgeProgress]

    var unlockedCount: Int {
        badges.filter(\.isComplete).count
    }

    var totalCount: Int { badges.count }

    var levelTitle: String {
        L10n.format("rewards.levelTitle", level.number, level.localizedTitle)
    }

    var unlockedText: String {
        L10n.format("rewards.unlockedCount", unlockedCount, totalCount)
    }

    var xpText: String {
        if let next = level.next {
            guard xp > 0 else { return "" }
            return L10n.format("rewards.xpToLevel", xp, next.minimumXP, next.number)
        }
        return xp > 0 ? L10n.format("rewards.xpValue", xp) : ""
    }

    var levelFill: Double {
        guard let next = level.next, next.minimumXP > 0 else { return 1 }
        return min(1, Double(xp) / Double(next.minimumXP))
    }
}
