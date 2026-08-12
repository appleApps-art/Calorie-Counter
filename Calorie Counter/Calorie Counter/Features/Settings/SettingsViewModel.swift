import Foundation

final class SettingsViewModel {
    let titleText = Observable(L10n.tr("settings.title"))
    let subtitleText = Observable(L10n.tr("settings.subtitle"))
    let goalsText = Observable("")
    let healthText = Observable("")
    let subscriptionText = Observable("")
    let statusText = Observable("")
    let settings = Observable(AppSettings.default)
    let goals = Observable<UserGoals?>(nil)
    let profile = Observable(UserProfile.empty)
    let preferences = Observable(UserPreferenceProfile.empty)
    let subscription = Observable(SubscriptionStatus.free)
    let products = Observable<[SubscriptionProduct]>([])
    let reminderConfiguration = Observable(ReminderScheduleConfiguration.default)
    let isHealthAvailable = Observable(false)
    let avatarURL = Observable<URL?>(nil)

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

    func viewDidLoad() {
        reload()
        Task { @MainActor in
            subscription.value = await refreshSubscriptionStatusUseCase.execute()
            publishSubscription()
            products.value = (try? await refreshSubscriptionStatusUseCase.products()) ?? []
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
        publishSettings()
        publishSubscription()
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

    func updateHealthSync(enabled: Bool, weight: Bool, water: Bool, workouts: Bool) {
        var next = settings.value
        next.healthSyncEnabled = enabled
        next.healthSyncWeight = weight
        next.healthSyncWater = water
        next.healthSyncWorkouts = workouts
        updateAppSettingsUseCase.execute(next)
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
                    statusText.value = L10n.format("settings.importedWeight", entry.weightKilograms)
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
        healthText.value = settings.value.healthSyncEnabled
            ? L10n.tr("settings.healthOn")
            : L10n.tr("settings.healthOff")
    }

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
