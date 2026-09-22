import Foundation

enum AIAssistantUserContextBuilder {
    static func make(
        from summary: DailyDiarySummary,
        profile: UserProfile? = nil,
        preferences: UserPreferenceProfile? = nil,
        locale: String = Locale.deviceIdentifier,
        timezone: String = TimeZone.current.identifier,
        recipe: Recipe? = nil,
        mealPlan: MealPlan? = nil,
        mealPlans: [MealPlan] = []
    ) -> AIAssistantUserContext {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar.current
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return AIAssistantUserContext(
            locale: locale,
            timezone: timezone,
            goals: .init(
                calorieTarget: summary.goals.calorieTarget,
                proteinTarget: summary.goals.proteinTarget,
                carbsTarget: summary.goals.carbsTarget,
                fatsTarget: summary.goals.fatsTarget,
                fiberTarget: summary.goals.fiberTarget,
                sugarTarget: summary.goals.sugarTarget,
                sodiumTarget: summary.goals.sodiumTarget,
                waterTargetMilliliters: summary.goals.waterTargetMilliliters
            ),
            today: .init(
                date: dateFormatter.string(from: summary.date),
                consumedCalories: summary.totalCalories,
                remainingCalories: summary.remainingCalories,
                protein: summary.totalProtein,
                carbs: summary.totalCarbs,
                fats: summary.totalFats,
                waterMilliliters: summary.waterMilliliters,
                localHour: Calendar.current.component(.hour, from: Date()),
                meals: summary.foodEntries.map {
                    .init(
                        id: $0.id.uuidString,
                        name: $0.name,
                        mealType: $0.mealType.rawValue,
                        calories: $0.calories,
                        protein: $0.protein,
                        carbs: $0.carbs,
                        fats: $0.fats,
                        portionGrams: $0.portionGrams
                    )
                }
            ),
            preferences: preferences.map {
                .init(
                    allergies: $0.allergies,
                    dislikes: $0.dislikes,
                    diet: $0.diet,
                    goalType: $0.goalType
                )
            },
            profile: profile.map {
                .init(
                    sex: $0.sex?.rawValue,
                    age: $0.age,
                    heightCm: $0.heightCm,
                    weightKg: $0.weightKg
                )
            },
            recipe: recipe.map(makeRecipeContext),
            mealPlan: mealPlan.map { makeMealPlanContext(from: $0, includingDays: true) },
            // Bity is asked about "my plan" from any screen, so the plans travel with every request,
            // newest first and with their dishes: a headline alone cannot answer "what is on day two".
            mealPlans: mealPlans.isEmpty
                ? nil
                : mealPlans
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(maxPlansInContext)
                    .map { makeMealPlanContext(from: $0, includingDays: true) }
        )
    }

    /// More than a handful of plans would crowd out the diary in the prompt.
    private static let maxPlansInContext = 5

    private static func rounded(_ value: Double) -> Double {
        value.rounded()
    }

    static func makeMealPlanContext(
        from plan: MealPlan,
        includingDays: Bool
    ) -> AIAssistantUserContext.MealPlanContext {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return .init(
            id: plan.id.uuidString,
            title: plan.title,
            dayCount: plan.dayCount,
            mealCount: plan.mealCount,
            createdAt: formatter.string(from: plan.createdAt),
            days: includingDays
                ? plan.days().map { day in
                    let totals = MealPlanPacker.dayTotals(day.slots.map(\.recipe), types: day.slots.map(\.mealType))
                    return .init(
                        number: day.index + 1,
                        meals: day.slots.map {
                            .init(
                                mealType: $0.mealType.rawValue,
                                title: $0.recipe.title,
                                calories: $0.recipe.calories.map(Self.rounded),
                                protein: $0.recipe.protein.map(Self.rounded),
                                carbs: $0.recipe.carbs.map(Self.rounded),
                                fats: $0.recipe.fats.map(Self.rounded)
                            )
                        },
                        totals: .init(
                            calories: Self.rounded(totals.calories),
                            protein: Self.rounded(totals.protein),
                            carbs: Self.rounded(totals.carbs),
                            fats: Self.rounded(totals.fats)
                        )
                    )
                }
                : nil
        )
    }

    static func makeRecipeContext(from recipe: Recipe) -> AIAssistantUserContext.RecipeContext {
        .init(
            externalId: recipe.externalId,
            title: recipe.title,
            calories: recipe.calories,
            protein: recipe.protein,
            carbs: recipe.carbs,
            fats: recipe.fats,
            ingredients: recipe.ingredients.map {
                .init(name: $0.name, amount: $0.amount, unit: $0.unit)
            }
        )
    }
}

final class BuildAIAssistantUserContextUseCase {
    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let userProfileRepository: UserProfileRepositoryProtocol
    private let userPreferenceRepository: UserPreferenceRepositoryProtocol
    private let fetchMealPlansUseCase: FetchMealPlansUseCase?

    init(
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        userProfileRepository: UserProfileRepositoryProtocol,
        userPreferenceRepository: UserPreferenceRepositoryProtocol,
        fetchMealPlansUseCase: FetchMealPlansUseCase? = nil
    ) {
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.userProfileRepository = userProfileRepository
        self.userPreferenceRepository = userPreferenceRepository
        self.fetchMealPlansUseCase = fetchMealPlansUseCase
    }

    func execute(
        recipe: Recipe? = nil,
        mealPlan: MealPlan? = nil,
        date: Date = Date()
    ) throws -> AIAssistantUserContext {
        let summary = try fetchDailyDiaryUseCase.execute(for: date)
        let profile = try? userProfileRepository.fetchProfile()
        let preferences = UserPreferenceProfile(preferences: (try? userPreferenceRepository.fetchAll()) ?? [])
        var plans = (try? fetchMealPlansUseCase?.execute()) ?? []
        if let mealPlan, !plans.contains(where: { $0.id == mealPlan.id }) {
            plans.insert(mealPlan, at: 0)
        }
        return AIAssistantUserContextBuilder.make(
            from: summary,
            profile: profile,
            preferences: preferences,
            recipe: recipe,
            mealPlan: mealPlan,
            mealPlans: plans
        )
    }
}
