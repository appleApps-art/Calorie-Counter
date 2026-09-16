import Foundation

final class SettingsViewModel {
    let titleText = Observable(L10n.tr("settings.title"))
    let subtitleText = Observable(L10n.tr("settings.subtitle"))
    let goalsText = Observable("")
    let healthText = Observable("")
    let subscriptionText = Observable("")
    let statusText = Observable("")
    let nutritionGoalError = Observable("")
    let settings = Observable(AppSettings.default)
    let goals = Observable<UserGoals?>(nil)
    let profile = Observable(UserProfile.empty)
    let preferences = Observable(UserPreferenceProfile.empty)
    let subscription = Observable(SubscriptionStatus.free)
    let products = Observable<[SubscriptionProduct]>([])
    let paywallAvailable = Observable(false)
    let reminderConfiguration = Observable(ReminderScheduleConfiguration.default)
    let isHealthAvailable = Observable(false)
    let avatarURL = Observable<URL?>(nil)

    let appearanceMode = Observable(AppearanceMode.system)
    let usesMetric = Observable(true)
    let userIDText = Observable("")
    let nutritionGoalText = Observable("")
    let weightGoalText = Observable("")
    let themeText = Observable("")
    let healthStatusText = Observable("")
    let healthDetailText = Observable("")
    let healthAuthorization = Observable(HealthAuthorizationSnapshot.unavailable)
    let showsUpgrade = Observable(true)
    let showsShareApp = Observable(true)

    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let saveUserGoalsUseCase: SaveUserGoalsUseCase
    private let fetchOnboardingStateUseCase: FetchOnboardingStateUseCase
    private let updateProfileAndGoalsUseCase: UpdateProfileAndGoalsUseCase
    private let updateAppSettingsUseCase: UpdateAppSettingsUseCase
    private let requestHealthSyncAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase
    private let importHealthWeightUseCase: ImportHealthWeightUseCase
    private let refreshSubscriptionStatusUseCase: RefreshSubscriptionStatusUseCase
    private let fetchUserPreferencesUseCase: FetchUserPreferencesUseCase
    private let saveUserPreferenceUseCase: SaveUserPreferenceUseCase
    private let deleteUserPreferenceUseCase: DeleteUserPreferenceUseCase
    private let updateReminderPreferencesUseCase: UpdateReminderPreferencesUseCase
    private let saveUserAvatarUseCase: SaveUserAvatarUseCase
    private let deleteUserAvatarUseCase: DeleteUserAvatarUseCase
    private let healthSync: HealthSyncing

    init(
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        saveUserGoalsUseCase: SaveUserGoalsUseCase,
        fetchOnboardingStateUseCase: FetchOnboardingStateUseCase,
        updateProfileAndGoalsUseCase: UpdateProfileAndGoalsUseCase,
        updateAppSettingsUseCase: UpdateAppSettingsUseCase,
        requestHealthSyncAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase,
        importHealthWeightUseCase: ImportHealthWeightUseCase,
        refreshSubscriptionStatusUseCase: RefreshSubscriptionStatusUseCase,
        fetchUserPreferencesUseCase: FetchUserPreferencesUseCase,
        saveUserPreferenceUseCase: SaveUserPreferenceUseCase,
        deleteUserPreferenceUseCase: DeleteUserPreferenceUseCase,
        updateReminderPreferencesUseCase: UpdateReminderPreferencesUseCase,
        saveUserAvatarUseCase: SaveUserAvatarUseCase,
        deleteUserAvatarUseCase: DeleteUserAvatarUseCase,
        healthSync: HealthSyncing
    ) {
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.saveUserGoalsUseCase = saveUserGoalsUseCase
        self.fetchOnboardingStateUseCase = fetchOnboardingStateUseCase
        self.updateProfileAndGoalsUseCase = updateProfileAndGoalsUseCase
        self.updateAppSettingsUseCase = updateAppSettingsUseCase
        self.requestHealthSyncAuthorizationUseCase = requestHealthSyncAuthorizationUseCase
        self.importHealthWeightUseCase = importHealthWeightUseCase
        self.refreshSubscriptionStatusUseCase = refreshSubscriptionStatusUseCase
        self.fetchUserPreferencesUseCase = fetchUserPreferencesUseCase
        self.saveUserPreferenceUseCase = saveUserPreferenceUseCase
        self.deleteUserPreferenceUseCase = deleteUserPreferenceUseCase
        self.updateReminderPreferencesUseCase = updateReminderPreferencesUseCase
        self.saveUserAvatarUseCase = saveUserAvatarUseCase
        self.deleteUserAvatarUseCase = deleteUserAvatarUseCase
        self.healthSync = healthSync
    }

    func refreshSubscription() {
        Task { @MainActor in
            subscription.value = await refreshSubscriptionStatusUseCase.execute()
            publishSubscription()
            publishAccount()
            if let offer = try? await refreshSubscriptionStatusUseCase.loadPlacement(.settings) {
                products.value = offer.products
                paywallAvailable.value = offer.hasPaywallBuilder
            } else {
                products.value = (try? await refreshSubscriptionStatusUseCase.products()) ?? []
                paywallAvailable.value = false
            }
        }
    }

    func reload() {
        settings.value = updateAppSettingsUseCase.current()
        isHealthAvailable.value = healthSync.isAvailable
        reminderConfiguration.value = updateReminderPreferencesUseCase.current()
        subscription.value = refreshSubscriptionStatusUseCase.cached()
        do {
            let diary = try fetchDailyDiaryUseCase.execute()
            goals.value = diary.goals
            goalsText.value = L10n.format(
                "settings.goalsFormat",
                Int(diary.goals.calorieTarget),
                Int(diary.goals.proteinTarget)
            )
        } catch {
            statusText.value = error.localizedDescription
        }
        do {
            profile.value = try fetchOnboardingStateUseCase.execute()
            avatarURL.value = profile.value.avatarURL
        } catch {
            statusText.value = error.localizedDescription
        }
        do {
            preferences.value = try fetchUserPreferencesUseCase.execute()
        } catch {
            statusText.value = error.localizedDescription
        }
        publishSubscription()
        publishAccount()
        refreshHealthAuthorization()
    }

    func saveNutritionGoal(_ goal: GoalType) {
        nutritionGoalError.value = ""
        var next = profile.value
        next.goalType = goal
        do {
            _ = try updateProfileAndGoalsUseCase.execute(next, applyNutritionGoal: true)
            reload()
        } catch {
            nutritionGoalError.value = error.localizedDescription
        }
    }

    func saveWeightGoal(_ kilograms: Double) {
        var next = profile.value
        next.targetWeightKg = kilograms
        saveProfile(next)
    }

    func resolvedWeightGoalKilograms() -> Double? {
        CalculateNutritionPlanUseCase.resolvedTargetWeightKilograms(profile: profile.value)
    }

    func saveAppearance(_ mode: AppearanceMode) {
        var next = settings.value
        next.appearanceMode = mode
        updateAppSettingsUseCase.execute(next)
        reload()
    }

    func setUsesMetric(_ isMetric: Bool) {
        var next = settings.value
        next.usesMetric = isMetric
        updateAppSettingsUseCase.execute(next)
        reload()
    }

    func disconnectHealth() {
        healthAuthorization.value = .disconnected
        var next = settings.value
        next.healthSyncEnabled = false
        next.healthSyncUserDisabled = true
        updateAppSettingsUseCase.execute(next)
        settings.value = next
        Analytics.tracker.track(.healthSyncToggled(enabled: false))
        Analytics.tracker.setUserProperties(["health_sync_enabled": false])
        publishSettings()
        Task {
            await healthSync.stopSyncing()
        }
    }

    func isHealthConnected() -> Bool {
        healthAuthorization.value.isConnected
    }

    func saveGoals(_ next: UserGoals) {
        do {
            try saveUserGoalsUseCase.execute(next)
            reload()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func saveProfile(_ next: UserProfile) {
        do {
            _ = try updateProfileAndGoalsUseCase.execute(next)
            reload()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func saveAvatar(imageData: Data) {
        do {
            let stored = try saveUserAvatarUseCase.execute(imageData: imageData)
            profile.value = stored
            avatarURL.value = stored.avatarURL
            statusText.value = L10n.tr("settings.photoSaved")
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func removeAvatar() {
        do {
            let stored = try deleteUserAvatarUseCase.execute()
            profile.value = stored
            avatarURL.value = stored.avatarURL
            statusText.value = L10n.tr("settings.photoRemoved")
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func updateHealthSync(
        enabled: Bool,
        weight: Bool,
        water: Bool,
        workouts: Bool,
        food: Bool = true,
        profile: Bool = true
    ) {
        var next = settings.value
        next.healthSyncEnabled = enabled
        next.healthSyncUserDisabled = !enabled
        next.healthSyncWeight = weight
        next.healthSyncWater = water
        next.healthSyncWorkouts = workouts
        next.healthSyncFood = food
        next.healthSyncProfile = profile
        updateAppSettingsUseCase.execute(next)
        Analytics.tracker.track(.healthSyncToggled(enabled: enabled))
        Analytics.tracker.setUserProperties(["health_sync_enabled": enabled])
        reload()
    }

    func requestHealthAuthorization() {
        Task { @MainActor in
            do {
                let granted = try await requestHealthSyncAuthorizationUseCase.execute()
                statusText.value = granted ? L10n.tr("settings.healthGranted") : L10n.tr("settings.healthDenied")
                reload()
            } catch {
                statusText.value = error.localizedDescription
            }
        }
    }

    func importLatestHealthWeight() {
        Task { @MainActor in
            do {
                if let entry = try await importHealthWeightUseCase.execute() {
                    statusText.value = L10n.format("settings.importedWeightValue", AppUnits.current.weightText(entry.weightKilograms))
                } else {
                    statusText.value = L10n.tr("settings.noHealthWeight")
                }
            } catch {
                statusText.value = error.localizedDescription
            }
        }
    }

    func purchase(productID: String) {
        Task { @MainActor in
            do {
                subscription.value = try await refreshSubscriptionStatusUseCase.purchase(productID: productID)
                publishSubscription()
                statusText.value = subscription.value.isPremium
                    ? L10n.tr("settings.premiumUnlocked")
                    : L10n.tr("settings.purchaseComplete")
            } catch {
                statusText.value = error.localizedDescription
            }
        }
    }

    func restorePurchases() {
        Task { @MainActor in
            do {
                subscription.value = try await refreshSubscriptionStatusUseCase.restore()
                publishSubscription()
                statusText.value = subscription.value.isPremium
                    ? L10n.tr("settings.purchasesRestored")
                    : L10n.tr("settings.noSubscription")
            } catch {
                statusText.value = error.localizedDescription
            }
        }
    }

    func addPreference(kind: UserPreferenceKind, value: String, note: String? = nil) {
        do {
            _ = try saveUserPreferenceUseCase.execute(kind: kind, value: value, note: note)
            reload()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func deletePreference(id: UUID) {
        do {
            try deleteUserPreferenceUseCase.execute(id: id)
            reload()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func updateReminder(_ preference: ReminderPreference) {
        updateReminderPreferencesUseCase.updatePreference(preference)
        reminderConfiguration.value = updateReminderPreferencesUseCase.current()
    }

    private func publishSettings() {
        let connected = healthAuthorization.value.isConnected
        healthText.value = connected
            ? L10n.tr("settings.healthOn")
            : L10n.tr("settings.healthOff")
        usesMetric.value = settings.value.usesMetric
        appearanceMode.value = settings.value.appearanceMode
        themeText.value = settings.value.appearanceMode.localizedTitle
        healthStatusText.value = connected
            ? L10n.tr("settings.health.connected")
            : L10n.tr("settings.health.disconnected")
        healthDetailText.value = healthSyncDetailText()
    }

    private func publishAccount() {
        userIDText.value = profile.value.id.uuidString
        nutritionGoalText.value = nutritionTitle(for: profile.value.goalType)
        weightGoalText.value = formattedWeight(resolvedWeightGoalKilograms())
        let premium = subscription.value.isPremium
        showsUpgrade.value = !premium
        showsShareApp.value = !premium
    }

    func nutritionTitle(for goal: GoalType?) -> String {
        switch goal {
        case .lose: return L10n.tr("settings.nutrition.lose")
        case .maintain: return L10n.tr("settings.nutrition.maintain")
        case .gain: return L10n.tr("settings.nutrition.gain")
        case .none: return ""
        }
    }

    func formattedWeight(_ kilograms: Double?) -> String {
        guard let kilograms else { return "" }
        if settings.value.usesMetric {
            return L10n.format("settings.weight.kg", Int(kilograms.rounded()))
        }
        let pounds = (kilograms * 2.2046226218).rounded()
        return L10n.format("settings.weight.lb", Int(pounds))
    }

    func healthSyncDetailText() -> String {
        if healthAuthorization.value.isConnected {
            guard let date = settings.value.healthLastSyncedAt else { return "" }
            if Calendar.current.isDateInToday(date) {
                return Self.timeFormatter.string(from: date)
            }
            return Self.dateTimeFormatter.string(from: date)
        }
        return L10n.tr("settings.health.accessDenied")
    }

    private func refreshHealthAuthorization() {
        healthAuthorization.value = requestHealthSyncAuthorizationUseCase.refreshFromStore()
        settings.value = updateAppSettingsUseCase.current()
        publishSettings()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func publishSubscription() {
        let status = subscription.value
        switch status.tier {
        case .free:
            subscriptionText.value = L10n.tr("settings.tier.free")
        case .trial:
            subscriptionText.value = L10n.tr("settings.tier.trial")
        case .premium:
            subscriptionText.value = L10n.tr("settings.tier.premium")
        }
        subtitleText.value = subscriptionText.value
    }
}
