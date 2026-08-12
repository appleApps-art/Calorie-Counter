import Foundation

enum AIAssistantUserContextBuilder {
    static func make(
        from summary: DailyDiarySummary,
        profile: UserProfile? = nil,
        preferences: UserPreferenceProfile? = nil,
        locale: String = Locale.current.identifier,
        timezone: String = TimeZone.current.identifier,
        recipe: Recipe? = nil
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
            recipe: recipe.map(makeRecipeContext)
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

    init(
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        userProfileRepository: UserProfileRepositoryProtocol,
        userPreferenceRepository: UserPreferenceRepositoryProtocol
    ) {
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.userProfileRepository = userProfileRepository
        self.userPreferenceRepository = userPreferenceRepository
    }

    func execute(recipe: Recipe? = nil) throws -> AIAssistantUserContext {
        let summary = try fetchDailyDiaryUseCase.execute()
        let profile = try? userProfileRepository.fetchProfile()
        let preferences = UserPreferenceProfile(preferences: (try? userPreferenceRepository.fetchAll()) ?? [])
        return AIAssistantUserContextBuilder.make(
            from: summary,
            profile: profile,
            preferences: preferences,
            recipe: recipe
        )
    }
}
