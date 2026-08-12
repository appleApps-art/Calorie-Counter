import Foundation

final class FetchProgressSummaryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let weightEntryRepository: WeightEntryRepositoryProtocol
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol
    private let fetchProgressPhotosUseCase: FetchProgressPhotosUseCase
    private let rewardsRepository: RewardsRepositoryProtocol
    private let evaluateStreakUseCase: EvaluateStreakUseCase

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        waterEntryRepository: WaterEntryRepositoryProtocol,
        weightEntryRepository: WeightEntryRepositoryProtocol,
        workoutEntryRepository: WorkoutEntryRepositoryProtocol,
        fetchProgressPhotosUseCase: FetchProgressPhotosUseCase,
        rewardsRepository: RewardsRepositoryProtocol,
        evaluateStreakUseCase: EvaluateStreakUseCase
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.waterEntryRepository = waterEntryRepository
        self.weightEntryRepository = weightEntryRepository
        self.workoutEntryRepository = workoutEntryRepository
        self.fetchProgressPhotosUseCase = fetchProgressPhotosUseCase
        self.rewardsRepository = rewardsRepository
        self.evaluateStreakUseCase = evaluateStreakUseCase
    }

    func execute(days: Int = 30, now: Date = Date(), calendar: Calendar = .current) throws -> ProgressSummary {
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) ?? now
        let foods = try foodEntryRepository.fetchEntries(from: start, to: now)
        let waters = try waterEntryRepository.fetchEntries(from: start, to: now)
        let foodsByDay = Dictionary(grouping: foods) { calendar.startOfDay(for: $0.date) }
        let watersByDay = Dictionary(grouping: waters) { calendar.startOfDay(for: $0.date) }

        var points: [DailyMacroPoint] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -((days - 1) - offset), to: calendar.startOfDay(for: now)) else {
                continue
            }
            let dayFoods = foodsByDay[day] ?? []
            let dayWaters = watersByDay[day] ?? []
            points.append(
                DailyMacroPoint(
                    date: day,
                    calories: dayFoods.reduce(0) { $0 + $1.calories },
                    protein: dayFoods.reduce(0) { $0 + $1.protein },
                    carbs: dayFoods.reduce(0) { $0 + $1.carbs },
                    fats: dayFoods.reduce(0) { $0 + $1.fats },
                    waterMilliliters: dayWaters.reduce(0) { $0 + $1.amountMilliliters }
                )
            )
        }

        let streak = try evaluateStreakUseCase.execute(now: now, calendar: calendar)
        return ProgressSummary(
            weightEntries: try weightEntryRepository.fetchEntries(),
            caloriePoints: points,
            workouts: try workoutEntryRepository.fetchEntries(from: start, to: now),
            photos: try fetchProgressPhotosUseCase.execute(),
            rewards: try rewardsRepository.fetchState(),
            streak: streak
        )
    }
}

final class PersistChatHistoryUseCase {
    private let chatHistoryRepository: ChatHistoryRepositoryProtocol

    init(chatHistoryRepository: ChatHistoryRepositoryProtocol) {
        self.chatHistoryRepository = chatHistoryRepository
    }

    func load(limit: Int = 40) throws -> [ChatHistoryMessage] {
        try chatHistoryRepository.fetchRecent(limit: limit)
    }

    func append(role: String, content: String) throws {
        try chatHistoryRepository.append(
            ChatHistoryMessage(id: UUID(), role: role, content: content, createdAt: Date())
        )
    }
}

final class UpdateAppSettingsUseCase {
    private let store: AppSettingsStoring

    init(store: AppSettingsStoring) {
        self.store = store
    }

    func execute(_ settings: AppSettings) {
        store.settings = settings
    }

    func current() -> AppSettings {
        store.settings
    }
}

final class RefreshSubscriptionStatusUseCase {
    private let subscriptionService: SubscriptionStatusProviding

    init(subscriptionService: SubscriptionStatusProviding) {
        self.subscriptionService = subscriptionService
    }

    func cached() -> SubscriptionStatus {
        subscriptionService.currentStatus()
    }

    func execute() async -> SubscriptionStatus {
        await subscriptionService.refresh()
    }

    func products() async throws -> [SubscriptionProduct] {
        try await subscriptionService.availableProducts()
    }

    func purchase(productID: String) async throws -> SubscriptionStatus {
        try await subscriptionService.purchase(productID: productID)
    }

    func restore() async throws -> SubscriptionStatus {
        try await subscriptionService.restorePurchases()
    }
}

final class UpdateReminderPreferencesUseCase {
    private let store: ReminderPreferencesStoring
    private let refreshReminderScheduleUseCase: RefreshReminderScheduleUseCase?

    init(
        store: ReminderPreferencesStoring,
        refreshReminderScheduleUseCase: RefreshReminderScheduleUseCase? = nil
    ) {
        self.store = store
        self.refreshReminderScheduleUseCase = refreshReminderScheduleUseCase
    }

    func current() -> ReminderScheduleConfiguration {
        store.configuration
    }

    func execute(_ configuration: ReminderScheduleConfiguration) {
        store.configuration = configuration
        Task {
            try? await refreshReminderScheduleUseCase?.execute()
        }
    }

    func updatePreference(_ preference: ReminderPreference) {
        store.updatePreference(preference)
        Task {
            try? await refreshReminderScheduleUseCase?.execute()
        }
    }
}

final class RequestHealthSyncAuthorizationUseCase {
    private let healthSync: HealthSyncing
    private let appSettingsStore: AppSettingsStoring

    init(healthSync: HealthSyncing, appSettingsStore: AppSettingsStoring) {
        self.healthSync = healthSync
        self.appSettingsStore = appSettingsStore
    }

    func execute() async throws -> Bool {
        let granted = try await healthSync.requestAuthorization()
        if granted {
            var settings = appSettingsStore.settings
            settings.healthSyncEnabled = true
            appSettingsStore.settings = settings
        }
        return granted
    }
}

final class ComputeNutritionFactsUseCase {
    func execute(for entry: FoodEntry) -> FoodNutritionFacts {
        NutritionFactsCalculator.facts(for: entry)
    }

    func execute(
        calories: Double,
        protein: Double,
        carbs: Double,
        fats: Double,
        fiber: Double,
        sugar: Double,
        sodium: Double
    ) -> FoodNutritionFacts {
        NutritionFactsCalculator.facts(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
        )
    }
}
