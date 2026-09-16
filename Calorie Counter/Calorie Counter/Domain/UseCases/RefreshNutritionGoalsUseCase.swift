import Foundation

final class RefreshNutritionGoalsUseCase {
    private let profileRepository: UserProfileRepositoryProtocol
    private let goalsRepository: UserGoalsRepositoryProtocol
    private let settingsStore: AppSettingsStoring
    private let calculator: CalculateNutritionPlanUseCase
    private let weightRepository: WeightEntryRepositoryProtocol?

    init(profileRepository: UserProfileRepositoryProtocol, goalsRepository: UserGoalsRepositoryProtocol,
         settingsStore: AppSettingsStoring, calculator: CalculateNutritionPlanUseCase = .init(),
         weightRepository: WeightEntryRepositoryProtocol? = nil) {
        self.profileRepository = profileRepository
        self.goalsRepository = goalsRepository
        self.settingsStore = settingsStore
        self.calculator = calculator
        self.weightRepository = weightRepository
    }

    func execute(profile: UserProfile? = nil) throws {
        let profile = try profile ?? profileRepository.fetchProfile()
        try resolveLegacyMode(profile: profile)
        guard settingsStore.settings.automaticallyAdjustNutritionGoals else { return }
        guard let plan = calculator.execute(profile: profile),
              try goalsRepository.fetchGoals() != plan.goals else { return }
        try goalsRepository.save(plan.goals)
    }

    func applyLatestWeight(_ entry: WeightEntry) throws {
        var profile = try profileRepository.fetchProfile()
        guard entry.weightKilograms.isFinite, entry.weightKilograms > 0 else { return }
        profile.weightKg = entry.weightKilograms
        try execute(profile: profile)
        try profileRepository.save(profile)
    }

    private func resolveLegacyMode(profile: UserProfile) throws {
        var settings = settingsStore.settings
        guard !settings.nutritionGoalModeResolved else { return }
        let goals = try goalsRepository.fetchGoals()
        var candidates = [profile, try profileRepository.fetchProfile()]
        for weight in try weightRepository?.fetchEntries() ?? [] {
            var previous = profile
            previous.weightKg = weight.weightKilograms
            candidates.append(previous)
        }
        // Older builds did not record whether targets were manual. Only migrate
        // a recognizable calculated plan; preserve ambiguous/custom targets.
        settings.automaticallyAdjustNutritionGoals = candidates.contains { candidate in
            guard let plan = calculator.execute(profile: candidate) else { return false }
            if plan.goals == goals { return true }
            guard let weight = candidate.weightKg, let goal = candidate.goalType else { return false }
            let proteinFactor: Double = goal == .lose ? 2 : (goal == .gain ? 1.8 : 1.6)
            let fatFactor: Double = goal == .lose ? 0.8 : (goal == .gain ? 1 : 0.9)
            let protein = proteinFactor * weight
            let fats = fatFactor * weight
            let carbs = max(0, (plan.goals.calorieTarget - protein * 4 - fats * 9) / 4).rounded()
            return goals.calorieTarget == plan.goals.calorieTarget
                && goals.proteinTarget == protein.rounded()
                && goals.fatsTarget == fats.rounded()
                && abs(goals.carbsTarget - carbs) <= 1
                && goals.fiberTarget == plan.goals.fiberTarget
                && goals.sugarTarget == plan.goals.sugarTarget
                && goals.sodiumTarget == plan.goals.sodiumTarget
                && goals.waterTargetMilliliters == plan.goals.waterTargetMilliliters
        }
        settings.nutritionGoalModeResolved = true
        settingsStore.settings = settings
    }
}
