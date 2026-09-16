import Foundation

final class FetchProgressSummaryUseCase {
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let waterEntryRepository: WaterEntryRepositoryProtocol
    private let weightEntryRepository: WeightEntryRepositoryProtocol
    private let workoutEntryRepository: WorkoutEntryRepositoryProtocol
    private let fetchProgressPhotosUseCase: FetchProgressPhotosUseCase
    private let rewardsRepository: RewardsRepositoryProtocol
    private let evaluateStreakUseCase: EvaluateStreakUseCase
    private let userGoalsRepository: UserGoalsRepositoryProtocol
    private let fetchOnboardingStateUseCase: FetchOnboardingStateUseCase
    private let calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase
    private let healthActivityStore: HealthDailyActivityStoring?
    private let refreshGoals: (() throws -> Void)?

    init(
        foodEntryRepository: FoodEntryRepositoryProtocol,
        waterEntryRepository: WaterEntryRepositoryProtocol,
        weightEntryRepository: WeightEntryRepositoryProtocol,
        workoutEntryRepository: WorkoutEntryRepositoryProtocol,
        fetchProgressPhotosUseCase: FetchProgressPhotosUseCase,
        rewardsRepository: RewardsRepositoryProtocol,
        evaluateStreakUseCase: EvaluateStreakUseCase,
        userGoalsRepository: UserGoalsRepositoryProtocol,
        fetchOnboardingStateUseCase: FetchOnboardingStateUseCase,
        calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase,
        healthActivityStore: HealthDailyActivityStoring? = nil,
        refreshGoals: (() throws -> Void)? = nil
    ) {
        self.foodEntryRepository = foodEntryRepository
        self.waterEntryRepository = waterEntryRepository
        self.weightEntryRepository = weightEntryRepository
        self.workoutEntryRepository = workoutEntryRepository
        self.fetchProgressPhotosUseCase = fetchProgressPhotosUseCase
        self.rewardsRepository = rewardsRepository
        self.evaluateStreakUseCase = evaluateStreakUseCase
        self.userGoalsRepository = userGoalsRepository
        self.fetchOnboardingStateUseCase = fetchOnboardingStateUseCase
        self.calculateNutritionPlanUseCase = calculateNutritionPlanUseCase
        self.healthActivityStore = healthActivityStore
        self.refreshGoals = refreshGoals
    }

    func execute(days: Int = 180, now: Date = Date(), calendar: Calendar = .current) throws -> ProgressSummary {
        try refreshGoals?()
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
            let dayFoods = (foodsByDay[day] ?? []).filter(\.isEaten)
            let dayWaters = watersByDay[day] ?? []
            points.append(
                DailyMacroPoint(
                    date: day,
                    calories: dayFoods.reduce(0) { $0 + $1.calories },
                    protein: dayFoods.reduce(0) { $0 + $1.protein },
                    carbs: dayFoods.reduce(0) { $0 + $1.carbs },
                    fats: dayFoods.reduce(0) { $0 + $1.fats },
                    fiber: dayFoods.reduce(0) { $0 + $1.fiber },
                    waterMilliliters: dayWaters.reduce(0) { $0 + $1.amountMilliliters }
                )
            )
        }

        let streak = try evaluateStreakUseCase.execute(now: now, calendar: calendar)
        let goals = try userGoalsRepository.fetchGoals()
        let profile = try? fetchOnboardingStateUseCase.execute()
        let activityBurnTarget = profile.flatMap { calculateNutritionPlanUseCase.execute(profile: $0) }?.activityBurnTarget ?? 0
        return ProgressSummary(
            weightEntries: try weightEntryRepository.fetchEntries(),
            caloriePoints: points,
            workouts: try workoutEntryRepository.fetchEntries(from: start, to: now),
            photos: try fetchProgressPhotosUseCase.execute(),
            rewards: try rewardsRepository.fetchState(),
            streak: streak,
            goals: goals,
            activityBurnTarget: activityBurnTarget,
            healthActivity: try healthActivityStore?.fetch(from: start, to: now) ?? []
        )
    }
}

struct ChatConversation: Identifiable, Equatable {
    // Older versions saved no conversation boundaries. Keep those messages together
    // without rewriting their content or guessing which messages belong together.
    static let legacyID = UUID(uuidString: "39DBA9EE-431F-454D-B071-3602DF037FE5")!

    let id: UUID
    let messages: [ChatHistoryMessage]
}

final class PersistChatHistoryUseCase {
    private let chatHistoryRepository: ChatHistoryRepositoryProtocol

    init(chatHistoryRepository: ChatHistoryRepositoryProtocol) {
        self.chatHistoryRepository = chatHistoryRepository
    }

    func load(limit: Int = 40) throws -> [ChatHistoryMessage] {
        try chatHistoryRepository.fetchRecent(limit: limit)
    }

    func loadAll() throws -> [ChatHistoryMessage] {
        try chatHistoryRepository.fetchAll()
    }

    func conversations() throws -> [ChatConversation] {
        let grouped = Dictionary(grouping: try loadAll()) {
            $0.conversationID ?? ChatConversation.legacyID
        }
        return grouped.compactMap { id, messages in
            guard messages.contains(where: { $0.role == "user" }) else { return nil }
            return ChatConversation(id: id, messages: messages.sorted { $0.createdAt < $1.createdAt })
        }.sorted {
            ($0.messages.last?.createdAt ?? .distantPast) > ($1.messages.last?.createdAt ?? .distantPast)
        }
    }

    func loadConversation(id: UUID) throws -> [ChatHistoryMessage] {
        try loadAll().filter { ($0.conversationID ?? ChatConversation.legacyID) == id }
    }

    func append(id: UUID = UUID(), role: String, content: String, conversationID: UUID? = nil) throws {
        try chatHistoryRepository.append(
            ChatHistoryMessage(id: id, role: role, content: content, createdAt: Date(), conversationID: conversationID)
        )
    }

    func replace(_ message: ChatHistoryMessage) throws {
        // A delayed card update must not recreate a message after history was cleared.
        var all = try chatHistoryRepository.fetchAll()
        if let index = all.firstIndex(where: { $0.id == message.id }) {
            all[index] = ChatHistoryMessage(
                id: message.id,
                role: message.role,
                content: message.content,
                createdAt: all[index].createdAt,
                conversationID: all[index].conversationID
            )
            try chatHistoryRepository.replaceAll(all)
        }
    }

    func replaceAll(_ messages: [ChatHistoryMessage]) throws {
        try chatHistoryRepository.replaceAll(messages)
    }

    func deleteAll() throws {
        try chatHistoryRepository.replaceAll([])
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

    func purchase(productID: String, placement: SubscriptionPlacement) async throws -> SubscriptionStatus {
        try await subscriptionService.purchase(productID: productID, placement: placement)
    }

    func restore() async throws -> SubscriptionStatus {
        try await subscriptionService.restorePurchases()
    }

    func loadPlacement(_ placement: SubscriptionPlacement) async throws -> SubscriptionOffer {
        try await subscriptionService.loadPlacement(placement)
    }

    func logShowPlacement(_ placement: SubscriptionPlacement) async {
        await subscriptionService.logShowPlacement(placement)
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
        let completed = try await healthSync.requestAuthorization()
        var snapshot = healthSync.authorizationSnapshot()
        if completed { snapshot.canAttemptRead = true }
        apply(snapshot, requested: true)
        return completed
    }

    func refreshFromStore() -> HealthAuthorizationSnapshot {
        let snapshot = healthSync.authorizationSnapshot()
        apply(snapshot, requested: false)
        guard appSettingsStore.settings.healthSyncEnabled else { return snapshot.isAvailable ? .disconnected : .unavailable }
        return snapshot
    }

    private func apply(_ snapshot: HealthAuthorizationSnapshot, requested: Bool) {
        var settings = appSettingsStore.settings
        if requested {
            settings.healthAuthorizationRequested = true
            settings.healthSyncUserDisabled = false
            if snapshot.isConnected {
                // A fresh connection restores import choices that older app
                // versions incorrectly disabled from denied write permissions.
                settings.healthSyncWeight = true
                settings.healthSyncWater = true
                settings.healthSyncWorkouts = true
                settings.healthSyncFood = true
                settings.healthSyncProfile = true
            }
        }
        settings.healthSyncEnabled = !settings.healthSyncUserDisabled && snapshot.isConnected
        // Per-type flags are import preferences. Write-denied is not read-denied.
        appSettingsStore.settings = settings
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
