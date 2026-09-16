import Foundation

final class CalculateNutritionPlanUseCase {
    func execute(
        profile: UserProfile,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> NutritionPlan? {
        guard
            let sex = profile.sex,
            let age = profile.age,
            let height = profile.heightCm,
            let weight = profile.weightKg,
            let activity = profile.activityLevel,
            let goal = profile.goalType,
            age > 0, height.isFinite, height > 0, weight.isFinite, weight > 0
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

        let calorieBudget = max(0, calories.rounded())
        let proposedProtein = proteinPerKg * weight
        let proposedFats = fatPerKg * weight
        let requiredEnergy = proposedProtein * 4 + proposedFats * 9
        let factor = requiredEnergy > 0 ? min(1, calorieBudget / requiredEnergy) : 1
        let protein = (proposedProtein * factor).rounded(.down)
        let fats = (proposedFats * factor).rounded(.down)
        let carbs = max(0, (calorieBudget - protein * 4 - fats * 9) / 4).rounded(.down)
        let water = max(2000, weight * 35)
        let fiber = max(
            Guideline.fiberMinimumGrams,
            (Guideline.fiberGramsPer1000Kcal * calories / 1000).rounded()
        )
        let sugar = (calories * Guideline.addedSugarEnergyFraction / Guideline.kcalPerGramCarbohydrate).rounded()

        let goals = UserGoals(
            calorieTarget: calories.rounded(),
            proteinTarget: protein.rounded(),
            carbsTarget: carbs.rounded(),
            fatsTarget: fats.rounded(),
            fiberTarget: fiber,
            sugarTarget: sugar,
            sodiumTarget: Guideline.sodiumUpperLimitMilligrams,
            waterTargetMilliliters: water.rounded()
        )

        return NutritionPlan(
            bmr: bmr.rounded(),
            tdee: tdee.rounded(),
            goals: goals,
            goalType: goal,
            estimatedGoalDate: estimatedGoalDate(
                goal: goal,
                weightKg: weight,
                targetKg: Self.resolvedTargetWeightKilograms(profile: profile),
                now: now,
                calendar: calendar
            )
        )
    }

    static func defaultTargetWeightKilograms(
        goal: GoalType?,
        heightCm: Double?,
        weightKg: Double?
    ) -> Double? {
        guard let weightKg else { return nil }
        switch goal {
        case .lose:
            guard let heightCm, heightCm > 0 else { return weightKg }
            let heightM = heightCm / 100
            return min(weightKg, Guideline.loseTargetBMI * heightM * heightM)
        case .gain:
            return weightKg + Guideline.gainTargetExtraKg
        case .maintain, .none:
            return weightKg
        }
    }

    static func resolvedTargetWeightKilograms(profile: UserProfile) -> Double? {
        profile.targetWeightKg ?? defaultTargetWeightKilograms(
            goal: profile.goalType,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg
        )
    }

    private func estimatedGoalDate(
        goal: GoalType,
        weightKg: Double,
        targetKg: Double?,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        switch goal {
        case .maintain:
            return nil
        case .lose:
            guard let targetKg else { return nil }
            let delta = weightKg - targetKg
            guard delta > 0.05 else { return now }
            let days = Int(((delta / Guideline.loseWeeklyKg) * 7).rounded())
            return calendar.date(byAdding: .day, value: max(1, days), to: now)
        case .gain:
            let extra = (targetKg ?? weightKg + Guideline.gainTargetExtraKg) - weightKg
            guard extra > 0.05 else { return now }
            let days = Int(((extra / Guideline.gainWeeklyKg) * 7).rounded())
            return calendar.date(byAdding: .day, value: max(1, days), to: now)
        }
    }

    private enum Guideline {
        static let fiberGramsPer1000Kcal = 14.0
        static let fiberMinimumGrams = 25.0
        static let addedSugarEnergyFraction = 0.05
        static let kcalPerGramCarbohydrate = 4.0
        static let sodiumUpperLimitMilligrams = 2300.0
        static let loseTargetBMI = 22.0
        static let loseWeeklyKg = 0.5
        static let gainTargetExtraKg = 5.0
        static let gainWeeklyKg = 0.25
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
    private let healthSync: HealthSyncing?
    private let appSettingsStore: AppSettingsStoring?

    init(
        userProfileRepository: UserProfileRepositoryProtocol,
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil
    ) {
        self.userProfileRepository = userProfileRepository
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
    }

    func execute(_ profile: UserProfile) throws {
        try userProfileRepository.save(profile)
        syncHeight(profile)
    }

    private func syncHeight(_ profile: UserProfile) {
        guard let height = profile.heightCm else { return }
        let settings = appSettingsStore?.settings
        guard settings?.healthSyncEnabled == true, settings?.healthSyncProfile == true else { return }
        HealthExportQueue.shared.enqueue(entryID: profile.id) { [healthSync] in
            try await healthSync?.saveHeight(height, date: Date(), entryID: profile.id)
        }
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
    private let healthSync: HealthSyncing?
    private let appSettingsStore: AppSettingsStoring?

    init(
        userProfileRepository: UserProfileRepositoryProtocol,
        userGoalsRepository: UserGoalsRepositoryProtocol,
        calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase = CalculateNutritionPlanUseCase(),
        healthSync: HealthSyncing? = nil,
        appSettingsStore: AppSettingsStoring? = nil
    ) {
        self.userProfileRepository = userProfileRepository
        self.userGoalsRepository = userGoalsRepository
        self.calculateNutritionPlanUseCase = calculateNutritionPlanUseCase
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
    }

    func execute(_ profile: UserProfile, applyNutritionGoal: Bool = false) throws -> NutritionPlan? {
        // An explicit goal selection must replace stale/manual targets too.
        if applyNutritionGoal, calculateNutritionPlanUseCase.execute(profile: profile) == nil {
            throw OnboardingError.incompleteProfile
        }
        if let appSettingsStore, !appSettingsStore.settings.nutritionGoalModeResolved {
            try RefreshNutritionGoalsUseCase(
                profileRepository: userProfileRepository, goalsRepository: userGoalsRepository,
                settingsStore: appSettingsStore, calculator: calculateNutritionPlanUseCase
            ).execute()
        }
        try userProfileRepository.save(profile)
        if let height = profile.heightCm {
            let settings = appSettingsStore?.settings
            if settings?.healthSyncEnabled == true, settings?.healthSyncProfile == true {
                HealthExportQueue.shared.enqueue(entryID: profile.id) { [healthSync] in
                    try await healthSync?.saveHeight(height, date: Date(), entryID: profile.id)
                }
            }
        }
        guard let plan = calculateNutritionPlanUseCase.execute(profile: profile) else {
            return nil
        }
        if applyNutritionGoal || appSettingsStore?.settings.automaticallyAdjustNutritionGoals != false {
            try userGoalsRepository.save(plan.goals)
        }
        if applyNutritionGoal, let appSettingsStore {
            var settings = appSettingsStore.settings
            settings.automaticallyAdjustNutritionGoals = true
            settings.nutritionGoalModeResolved = true
            appSettingsStore.settings = settings
        }
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
