import Foundation

enum BiologicalSex: String, Codable, CaseIterable, Equatable {
    case female
    case male
    case other

    var localizedTitle: String {
        L10n.tr("sex.\(rawValue)")
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Equatable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var tdeeMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var localizedTitle: String {
        L10n.tr("activity.\(rawValue)")
    }
}

enum GoalType: String, Codable, CaseIterable, Equatable {
    case lose
    case maintain
    case gain

    var localizedTitle: String {
        L10n.tr("goal.\(rawValue)")
    }
}

enum OnboardingStep: String, Codable, CaseIterable, Equatable {
    case welcome
    case goal
    case questions
    case animation
    case plan
    case rating
    case aiIntro
    case completed
}

struct UserProfile: Equatable {
    var id: UUID
    var sex: BiologicalSex?
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    var activityLevel: ActivityLevel?
    var goalType: GoalType?
    var avatarFileName: String?
    var avatarURL: URL?
    var onboardingStep: OnboardingStep
    var onboardingCompleted: Bool
    var updatedAt: Date

    static let empty = UserProfile(
        id: UUID(),
        sex: nil,
        age: nil,
        heightCm: nil,
        weightKg: nil,
        activityLevel: nil,
        goalType: nil,
        avatarFileName: nil,
        avatarURL: nil,
        onboardingStep: .welcome,
        onboardingCompleted: false,
        updatedAt: Date()
    )

    var hasAvatar: Bool {
        avatarFileName != nil
    }

    var isReadyForPlan: Bool {
        sex != nil && age != nil && heightCm != nil && weightKg != nil && activityLevel != nil && goalType != nil
    }
}

struct NutritionPlan: Equatable {
    var bmr: Double
    var tdee: Double
    var goals: UserGoals
    var goalType: GoalType
}
