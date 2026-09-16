import Foundation

struct OnboardingPlanDisplay: Equatable {
    let energyValue: String
    let goalDateText: String
    let proteinValue: String
    let fatsValue: String
    let carbsValue: String
    let waterValue: String
    let fiberValue: String
    let sugarValue: String
    let sodiumValue: String
}

final class OnboardingFlowViewModel {
    private let fetchOnboardingStateUseCase: FetchOnboardingStateUseCase
    private let saveUserProfileUseCase: SaveUserProfileUseCase
    private let calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase
    private let completeOnboardingUseCase: CompleteOnboardingUseCase
    private let requestHealthSyncAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase

    private(set) var profile: UserProfile

    init(
        fetchOnboardingStateUseCase: FetchOnboardingStateUseCase,
        saveUserProfileUseCase: SaveUserProfileUseCase,
        calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase,
        completeOnboardingUseCase: CompleteOnboardingUseCase,
        requestHealthSyncAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase
    ) {
        self.fetchOnboardingStateUseCase = fetchOnboardingStateUseCase
        self.saveUserProfileUseCase = saveUserProfileUseCase
        self.calculateNutritionPlanUseCase = calculateNutritionPlanUseCase
        self.completeOnboardingUseCase = completeOnboardingUseCase
        self.requestHealthSyncAuthorizationUseCase = requestHealthSyncAuthorizationUseCase
        profile = (try? fetchOnboardingStateUseCase.execute()) ?? .empty
    }

    func setGoal(_ goal: GoalType) {
        mutate { profile in
            profile.goalType = goal
            profile.onboardingStep = .goal
        }
    }

    func setSex(_ sex: BiologicalSex) {
        mutate { profile in
            profile.sex = sex
            profile.onboardingStep = .questions
        }
    }

    func setAge(_ age: Int) {
        mutate { profile in
            profile.age = age
            profile.onboardingStep = .questions
        }
    }

    func setBody(heightCm: Double, weightKg: Double) {
        mutate { profile in
            profile.heightCm = heightCm
            profile.weightKg = weightKg
            profile.onboardingStep = .questions
        }
    }

    func setActivity(_ activity: ActivityLevel) {
        mutate { profile in
            profile.activityLevel = activity
            profile.onboardingStep = .plan
        }
    }

    func requestHealthAuthorization() async {
        _ = try? await requestHealthSyncAuthorizationUseCase.execute()
    }

    func makePlanDisplay(now: Date = Date(), calendar: Calendar = .current) -> OnboardingPlanDisplay? {
        guard let plan = calculateNutritionPlanUseCase.execute(profile: profile, now: now, calendar: calendar) else {
            return nil
        }
        return Self.display(for: plan)
    }

    func complete() throws {
        _ = try completeOnboardingUseCase.execute(profile: profile)
    }

    static func display(for plan: NutritionPlan, locale: Locale = .current) -> OnboardingPlanDisplay {
        let calories = groupedInteger(plan.goals.calorieTarget, locale: locale)
        let sodium = groupedInteger(plan.goals.sodiumTarget, locale: locale)
        let water = liters(plan.goals.waterTargetMilliliters, locale: locale)
        let goalDateText: String
        if plan.goalType == .maintain {
            goalDateText = L10n.tr("onboarding.plan.goalDateMaintain")
        } else if let date = plan.estimatedGoalDate {
            goalDateText = L10n.format("onboarding.plan.goalDateFormat", Self.dateFormatter(locale: locale).string(from: date))
        } else {
            goalDateText = L10n.tr("onboarding.plan.goalDateMaintain")
        }
        return OnboardingPlanDisplay(
            energyValue: L10n.format("onboarding.plan.energyValueFormat", calories),
            goalDateText: goalDateText,
            proteinValue: L10n.format("onboarding.plan.gramsFormat", Int(plan.goals.proteinTarget)),
            fatsValue: L10n.format("onboarding.plan.gramsFormat", Int(plan.goals.fatsTarget)),
            carbsValue: L10n.format("onboarding.plan.gramsFormat", Int(plan.goals.carbsTarget)),
            waterValue: L10n.format("onboarding.plan.waterValueFormat", water),
            fiberValue: L10n.format("onboarding.plan.fiberValueFormat", Int(plan.goals.fiberTarget)),
            sugarValue: L10n.format("onboarding.plan.sugarValueFormat", Int(plan.goals.sugarTarget)),
            sodiumValue: L10n.format("onboarding.plan.sodiumValueFormat", sodium)
        )
    }

    private func mutate(_ update: (inout UserProfile) -> Void) {
        update(&profile)
        profile.updatedAt = Date()
        try? saveUserProfileUseCase.execute(profile)
    }

    private static func groupedInteger(_ value: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    private static func liters(_ milliliters: Double, locale: Locale) -> String {
        let liters = milliliters / 1000
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = liters.rounded() == liters ? 0 : 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: liters)) ?? String(format: "%.1f", liters)
    }

    private static func dateFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }
}
