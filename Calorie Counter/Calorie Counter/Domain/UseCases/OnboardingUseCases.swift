import Foundation

final class CalculateNutritionPlanUseCase {
    func execute(profile: UserProfile) -> NutritionPlan? {
        guard
            let sex = profile.sex,
            let age = profile.age,
            let height = profile.heightCm,
            let weight = profile.weightKg,
            let activity = profile.activityLevel,
            let goal = profile.goalType
        else {
            return nil
        }

        let bmr: Double
        switch sex {
        case .male:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        case .female:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
        case .other:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 78
        }

        let tdee = bmr * activity.tdeeMultiplier
        let calories: Double
        switch goal {
        case .lose:
            calories = max(1200, tdee - 500)
        case .maintain:
            calories = tdee
        case .gain:
            calories = tdee + 300
        }

        let proteinPerKg: Double
        let fatPerKg: Double
        switch goal {
        case .lose:
            proteinPerKg = 2.0
            fatPerKg = 0.8
        case .maintain:
            proteinPerKg = 1.6
            fatPerKg = 0.9
        case .gain:
            proteinPerKg = 1.8
            fatPerKg = 1.0
        }

        let protein = proteinPerKg * weight
        let fats = fatPerKg * weight
        let remaining = max(0, calories - protein * 4 - fats * 9)
        let carbs = remaining / 4
        let water = max(2000, weight * 35)

        let goals = UserGoals(
            calorieTarget: calories.rounded(),
            proteinTarget: protein.rounded(),
            carbsTarget: carbs.rounded(),
            fatsTarget: fats.rounded(),
            fiberTarget: 25,
            sugarTarget: 50,
            sodiumTarget: 2300,
            waterTargetMilliliters: water.rounded()
        )

        return NutritionPlan(bmr: bmr.rounded(), tdee: tdee.rounded(), goals: goals, goalType: goal)
    }
}

final class FetchOnboardingStateUseCase {
    private let userProfileRepository: UserProfileRepositoryProtocol
    private let avatarFileStore: LocalImageFileStoring?

    init(
        userProfileRepository: UserProfileRepositoryProtocol,
        avatarFileStore: LocalImageFileStoring? = nil
    ) {
        self.userProfileRepository = userProfileRepository
        self.avatarFileStore = avatarFileStore
    }

    func execute() throws -> UserProfile {
        resolveAvatar(try userProfileRepository.fetchProfile())
    }

    func resolveAvatar(_ profile: UserProfile) -> UserProfile {
        var copy = profile
        copy.avatarURL = nil
        if let fileName = profile.avatarFileName, let avatarFileStore, avatarFileStore.fileExists(fileName: fileName) {
            copy.avatarURL = avatarFileStore.url(for: fileName)
        }
        return copy
    }
}

final class SaveUserProfileUseCase {
    private let userProfileRepository: UserProfileRepositoryProtocol

    init(userProfileRepository: UserProfileRepositoryProtocol) {
        self.userProfileRepository = userProfileRepository
    }

    func execute(_ profile: UserProfile) throws {
        try userProfileRepository.save(profile)
    }
}

final class SaveUserAvatarUseCase {
    private let userProfileRepository: UserProfileRepositoryProtocol
    private let fileStore: LocalImageFileStoring
    private let fetchOnboardingStateUseCase: FetchOnboardingStateUseCase

    init(
        userProfileRepository: UserProfileRepositoryProtocol,
        fileStore: LocalImageFileStoring,
        fetchOnboardingStateUseCase: FetchOnboardingStateUseCase
    ) {
        self.userProfileRepository = userProfileRepository
        self.fileStore = fileStore
        self.fetchOnboardingStateUseCase = fetchOnboardingStateUseCase
    }

    func execute(imageData: Data) throws -> UserProfile {
        guard !imageData.isEmpty else {
            throw UserAvatarError.emptyImage
        }
        var profile = try userProfileRepository.fetchProfile()
        let fileName = profile.avatarFileName ?? "\(profile.id.uuidString).jpg"
        _ = try fileStore.saveJPEG(imageData, fileName: fileName)
        profile.avatarFileName = fileName
        try userProfileRepository.save(profile)
        return fetchOnboardingStateUseCase.resolveAvatar(profile)
    }
}

final class DeleteUserAvatarUseCase {
    private let userProfileRepository: UserProfileRepositoryProtocol
    private let fileStore: LocalImageFileStoring
    private let fetchOnboardingStateUseCase: FetchOnboardingStateUseCase

    init(
        userProfileRepository: UserProfileRepositoryProtocol,
        fileStore: LocalImageFileStoring,
        fetchOnboardingStateUseCase: FetchOnboardingStateUseCase
    ) {
        self.userProfileRepository = userProfileRepository
        self.fileStore = fileStore
        self.fetchOnboardingStateUseCase = fetchOnboardingStateUseCase
    }

    func execute() throws -> UserProfile {
        var profile = try userProfileRepository.fetchProfile()
        if let fileName = profile.avatarFileName {
            try? fileStore.delete(fileName: fileName)
        }
        profile.avatarFileName = nil
        try userProfileRepository.save(profile)
        return fetchOnboardingStateUseCase.resolveAvatar(profile)
    }
}

enum UserAvatarError: LocalizedError {
    case emptyImage

    var errorDescription: String? {
        switch self {
        case .emptyImage:
            return L10n.tr("onboarding.avatarEmpty")
        }
    }
}

final class CompleteOnboardingUseCase {
    private let userProfileRepository: UserProfileRepositoryProtocol
    private let userGoalsRepository: UserGoalsRepositoryProtocol
    private let calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase

    init(
        userProfileRepository: UserProfileRepositoryProtocol,
        userGoalsRepository: UserGoalsRepositoryProtocol,
        calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase = CalculateNutritionPlanUseCase()
    ) {
        self.userProfileRepository = userProfileRepository
        self.userGoalsRepository = userGoalsRepository
        self.calculateNutritionPlanUseCase = calculateNutritionPlanUseCase
    }

    func execute(profile: UserProfile) throws -> NutritionPlan {
        guard let plan = calculateNutritionPlanUseCase.execute(profile: profile) else {
            throw OnboardingError.incompleteProfile
        }
        var completed = profile
        completed.onboardingStep = .completed
        completed.onboardingCompleted = true
        try userProfileRepository.save(completed)
        try userGoalsRepository.save(plan.goals)
        return plan
    }
}

final class UpdateProfileAndGoalsUseCase {
    private let userProfileRepository: UserProfileRepositoryProtocol
    private let userGoalsRepository: UserGoalsRepositoryProtocol
    private let calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase

    init(
        userProfileRepository: UserProfileRepositoryProtocol,
        userGoalsRepository: UserGoalsRepositoryProtocol,
        calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase = CalculateNutritionPlanUseCase()
    ) {
        self.userProfileRepository = userProfileRepository
        self.userGoalsRepository = userGoalsRepository
        self.calculateNutritionPlanUseCase = calculateNutritionPlanUseCase
    }

    func execute(_ profile: UserProfile) throws -> NutritionPlan? {
        try userProfileRepository.save(profile)
        guard let plan = calculateNutritionPlanUseCase.execute(profile: profile) else {
            return nil
        }
        try userGoalsRepository.save(plan.goals)
        return plan
    }
}

enum OnboardingError: LocalizedError {
    case incompleteProfile

    var errorDescription: String? {
        switch self {
        case .incompleteProfile:
            return L10n.tr("onboarding.incomplete")
        }
    }
}
