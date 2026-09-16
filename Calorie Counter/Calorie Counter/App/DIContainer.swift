import Foundation

final class DIContainer {
    let coreDataStack: CoreDataStack
    private let reminderRefreshHook = CallbackHook()
    private let badgeEvaluationHook = CallbackHook()

    private lazy var foodEntryRepositoryBase: FoodEntryRepositoryProtocol = FoodEntryRepository(
        coreDataStack: coreDataStack
    )
    private lazy var waterEntryRepositoryBase: WaterEntryRepositoryProtocol = WaterEntryRepository(
        coreDataStack: coreDataStack
    )
    private lazy var weightEntryRepositoryBase: WeightEntryRepositoryProtocol = WeightEntryRepository(
        coreDataStack: coreDataStack
    )

    private(set) lazy var foodEntryRepository: FoodEntryRepositoryProtocol = DiaryChangeNotifyingFoodEntryRepository(
        base: foodEntryRepositoryBase,
        onChange: { [weak self] in
            self?.notifyDiaryChanged()
        }
    )
    private(set) lazy var waterEntryRepository: WaterEntryRepositoryProtocol = DiaryChangeNotifyingWaterEntryRepository(
        base: waterEntryRepositoryBase,
        onChange: { [weak self] in
            self?.notifyDiaryChanged()
        }
    )
    private(set) lazy var weightEntryRepository: WeightEntryRepositoryProtocol = DiaryChangeNotifyingWeightEntryRepository(
        base: weightEntryRepositoryBase,
        onChange: { [weak self] in
            self?.notifyDiaryChanged()
        }
    )
    private(set) lazy var workoutEntryRepository: WorkoutEntryRepositoryProtocol = DiaryChangeNotifyingWorkoutEntryRepository(
        base: workoutEntryRepositoryBase,
        onChange: { [weak self] in
            self?.notifyDiaryChanged()
        }
    )
    private(set) lazy var userGoalsRepository: UserGoalsRepositoryProtocol = UserGoalsRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var healthDailyActivityRepository: HealthDailyActivityStoring = HealthDailyActivityRepository(
        coreDataStack: coreDataStack,
        onChange: { [weak self] in self?.notifyDiaryChanged() }
    )
    private(set) lazy var refreshNutritionGoalsUseCase = RefreshNutritionGoalsUseCase(
        profileRepository: userProfileRepository,
        goalsRepository: userGoalsRepository,
        settingsStore: appSettingsStore,
        weightRepository: weightEntryRepository
    )
    private(set) lazy var recipeRepository: RecipeRepositoryProtocol = RecipeRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var pantryRepository: PantryRepositoryProtocol = PantryRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var mealPlanRepository: MealPlanRepositoryProtocol = MealPlanRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var userProfileRepository: UserProfileRepositoryProtocol = UserProfileRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var userPreferenceRepository: UserPreferenceRepositoryProtocol = UserPreferenceRepository(
        coreDataStack: coreDataStack
    )
    private lazy var workoutEntryRepositoryBase: WorkoutEntryRepositoryProtocol = WorkoutEntryRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var progressPhotoRepository: ProgressPhotoRepositoryProtocol = ProgressPhotoRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var chatHistoryRepository: ChatHistoryRepositoryProtocol = ChatHistoryRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var rewardsRepository: RewardsRepositoryProtocol = RewardsRepository(
        coreDataStack: coreDataStack
    )

    private(set) lazy var fetchDailyDiaryUseCase: FetchDailyDiaryUseCase = FetchDailyDiaryUseCase(
        foodEntryRepository: foodEntryRepository,
        waterEntryRepository: waterEntryRepository,
        userGoalsRepository: userGoalsRepository,
        workoutEntryRepository: workoutEntryRepository,
        healthActivityStore: healthDailyActivityRepository,
        refreshGoals: { [weak self] in try self?.refreshNutritionGoalsUseCase.execute() }
    )
    private(set) lazy var fetchSavedFoodsUseCase: FetchSavedFoodsUseCase = FetchSavedFoodsUseCase(
        foodEntryRepository: foodEntryRepository
    )
    private(set) lazy var buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase = BuildAIAssistantUserContextUseCase(
        fetchDailyDiaryUseCase: fetchDailyDiaryUseCase,
        userProfileRepository: userProfileRepository,
        userPreferenceRepository: userPreferenceRepository
    )

    private(set) lazy var aiAssistantService: AIAssistantServiceProtocol = AIAssistantService(
        configuration: .production
    )
    private(set) lazy var spoonacularService: SpoonacularServiceProtocol = SpoonacularService(
        configuration: .production
    )
    private(set) lazy var openFoodFactsService: OpenFoodFactsService = OpenFoodFactsService()
    private(set) lazy var aiFoodSearchService: AIFoodSearching = {
        #if DEBUG
        if QALaunchConfiguration.isActive {
            return QAFoodSearchService()
        }
        #endif
        return AIFoodSearchService()
    }()
    private(set) lazy var searchRecipesUseCase: SearchRecipesUseCase = SearchRecipesUseCase(
        spoonacularService: spoonacularService,
        aiFoodSearchService: aiFoodSearchService
    )
    private(set) lazy var recipeSectionsService: RecipeSectionsFetching = {
        #if DEBUG
        if QALaunchConfiguration.isActive {
            return QARecipeSectionsService()
        }
        #endif
        return RecipeSectionsService()
    }()
    private(set) lazy var fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase = FetchRecipeBrowseSectionsUseCase(
        service: recipeSectionsService
    )
    private(set) lazy var fetchPantryItemsUseCase: FetchPantryItemsUseCase = FetchPantryItemsUseCase(
        pantryRepository: pantryRepository
    )
    private(set) lazy var savePantryItemUseCase: SavePantryItemUseCase = SavePantryItemUseCase(
        pantryRepository: pantryRepository
    )
    private(set) lazy var deletePantryItemsUseCase: DeletePantryItemsUseCase = DeletePantryItemsUseCase(
        pantryRepository: pantryRepository
    )
    private(set) lazy var fetchMealPlansUseCase: FetchMealPlansUseCase = FetchMealPlansUseCase(
        mealPlanRepository: mealPlanRepository
    )
    private(set) lazy var createRecipeUseCase: CreateRecipeUseCase = CreateRecipeUseCase(
        searchRecipesUseCase: searchRecipesUseCase,
        recipeRepository: recipeRepository
    )
    private(set) lazy var createMealPlanUseCase: CreateMealPlanUseCase = CreateMealPlanUseCase(
        mealPlanRepository: mealPlanRepository,
        spoonacularService: spoonacularService,
        fetchUserPreferencesUseCase: fetchUserPreferencesUseCase,
        fetchDailyDiaryUseCase: fetchDailyDiaryUseCase,
        pantryRepository: pantryRepository
    )
    private(set) lazy var searchFoodProductsUseCase: SearchFoodProductsUseCase = SearchFoodProductsUseCase(
        spoonacularService: spoonacularService,
        aiFoodSearchService: aiFoodSearchService,
        openFoodFactsService: openFoodFactsService,
        textFoodAnalysisService: textFoodAnalysisService
    )
    private(set) lazy var appSettingsStore: AppSettingsStoring = AppSettingsStore()
    private(set) lazy var healthSyncService: HealthSyncing = HealthKitSyncService()
    private(set) lazy var subscriptionService: AdaptySubscriptionService = AdaptySubscriptionService()
    private(set) lazy var notificationInboxStore: NotificationInboxStoring = NotificationInboxStore()
    private(set) lazy var paywallFactory: SubscriptionPaywallPresenting = AdaptyPaywallFactory(
        service: subscriptionService
    )
    private(set) lazy var progressPhotoFileStore: ProgressPhotoFileStoring = LocalImageFileStore(folderName: "ProgressPhotos")
    private(set) lazy var avatarFileStore: LocalImageFileStoring = LocalImageFileStore(folderName: "ProfileAvatar")

    private(set) lazy var evaluateBadgesUseCase: EvaluateBadgesUseCase = {
        let useCase = EvaluateBadgesUseCase(
            rewardsRepository: rewardsRepository,
            foodEntryRepository: foodEntryRepository,
            waterEntryRepository: waterEntryRepository,
            weightEntryRepository: weightEntryRepository,
            workoutEntryRepository: workoutEntryRepository,
            progressPhotoRepository: progressPhotoRepository,
            userGoalsRepository: userGoalsRepository
        )
        badgeEvaluationHook.handler = { [weak useCase] in
            DispatchQueue.main.async {
                _ = try? useCase?.execute()
            }
        }
        return useCase
    }()
    private(set) lazy var awardXPUseCase: AwardXPUseCase = AwardXPUseCase(
        rewardsRepository: rewardsRepository,
        evaluateBadgesUseCase: evaluateBadgesUseCase
    )
    private(set) lazy var evaluateStreakUseCase: EvaluateStreakUseCase = EvaluateStreakUseCase(
        foodEntryRepository: foodEntryRepository,
        rewardsRepository: rewardsRepository
    )
    private(set) lazy var fetchRewardStateUseCase: FetchRewardStateUseCase = FetchRewardStateUseCase(
        rewardsRepository: rewardsRepository
    )
    private(set) lazy var markBadgeSeenUseCase: MarkBadgeSeenUseCase = MarkBadgeSeenUseCase(
        rewardsRepository: rewardsRepository
    )
    private(set) lazy var fetchRewardsScreenUseCase: FetchRewardsScreenUseCase = FetchRewardsScreenUseCase(
        evaluateStreakUseCase: evaluateStreakUseCase,
        evaluateBadgesUseCase: evaluateBadgesUseCase,
        rewardsRepository: rewardsRepository
    )

    private(set) lazy var analytics: AnalyticsTracking = Analytics.tracker
    private(set) lazy var logFoodUseCase: LogFoodUseCase = LogFoodUseCase(
        foodEntryRepository: foodEntryRepository,
        awardXPUseCase: awardXPUseCase,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore,
        analytics: analytics
    )
    private(set) lazy var updateFoodEntryUseCase: UpdateFoodEntryUseCase = UpdateFoodEntryUseCase(
        foodEntryRepository: foodEntryRepository,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore
    )
    private(set) lazy var deleteFoodEntryUseCase: DeleteFoodEntryUseCase = DeleteFoodEntryUseCase(
        foodEntryRepository: foodEntryRepository,
        healthSync: healthSyncService,
        analytics: analytics
    )
    private(set) lazy var deleteWaterEntryUseCase: DeleteWaterEntryUseCase = DeleteWaterEntryUseCase(
        waterEntryRepository: waterEntryRepository,
        healthSync: healthSyncService
    )
    private(set) lazy var deleteWorkoutEntryUseCase: DeleteWorkoutEntryUseCase = DeleteWorkoutEntryUseCase(
        workoutEntryRepository: workoutEntryRepository,
        healthSync: healthSyncService
    )
    private(set) lazy var fetchWeightHistoryUseCase: FetchWeightHistoryUseCase = FetchWeightHistoryUseCase(
        weightEntryRepository: weightEntryRepository
    )
    private(set) lazy var scaleFoodPortionUseCase: ScaleFoodPortionUseCase = ScaleFoodPortionUseCase()
    private(set) lazy var replaceFoodEntryUseCase: ReplaceFoodEntryUseCase = ReplaceFoodEntryUseCase(
        foodEntryRepository: foodEntryRepository,
        awardXPUseCase: awardXPUseCase,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore
    )
    private(set) lazy var logWaterUseCase: LogWaterUseCase = LogWaterUseCase(
        waterEntryRepository: waterEntryRepository,
        awardXPUseCase: awardXPUseCase,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore,
        analytics: analytics
    )
    private(set) lazy var logWeightUseCase: LogWeightUseCase = LogWeightUseCase(
        weightEntryRepository: weightEntryRepository,
        awardXPUseCase: awardXPUseCase,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore,
        analytics: analytics,
        onWeightLogged: { [weak self] entry in
            guard let self,
                  let latest = try self.weightEntryRepository.fetchEntries().max(by: { $0.date < $1.date }),
                  latest.id == entry.id else { return }
            try self.refreshNutritionGoalsUseCase.applyLatestWeight(latest)
            self.notifyDiaryChanged()
        }
    )
    private(set) lazy var saveUserGoalsUseCase: SaveUserGoalsUseCase = SaveUserGoalsUseCase(
        userGoalsRepository: userGoalsRepository,
        appSettingsStore: appSettingsStore
    )
    private(set) lazy var calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase = CalculateNutritionPlanUseCase()
    private(set) lazy var fetchOnboardingStateUseCase: FetchOnboardingStateUseCase = FetchOnboardingStateUseCase(
        userProfileRepository: userProfileRepository,
        avatarFileStore: avatarFileStore
    )
    private(set) lazy var saveUserProfileUseCase: SaveUserProfileUseCase = SaveUserProfileUseCase(
        userProfileRepository: userProfileRepository,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore
    )
    private(set) lazy var saveUserAvatarUseCase: SaveUserAvatarUseCase = SaveUserAvatarUseCase(
        userProfileRepository: userProfileRepository,
        fileStore: avatarFileStore,
        fetchOnboardingStateUseCase: fetchOnboardingStateUseCase
    )
    private(set) lazy var deleteUserAvatarUseCase: DeleteUserAvatarUseCase = DeleteUserAvatarUseCase(
        userProfileRepository: userProfileRepository,
        fileStore: avatarFileStore,
        fetchOnboardingStateUseCase: fetchOnboardingStateUseCase
    )
    private(set) lazy var completeOnboardingUseCase: CompleteOnboardingUseCase = CompleteOnboardingUseCase(
        userProfileRepository: userProfileRepository,
        userGoalsRepository: userGoalsRepository,
        calculateNutritionPlanUseCase: calculateNutritionPlanUseCase
    )
    private(set) lazy var updateProfileAndGoalsUseCase: UpdateProfileAndGoalsUseCase = UpdateProfileAndGoalsUseCase(
        userProfileRepository: userProfileRepository,
        userGoalsRepository: userGoalsRepository,
        calculateNutritionPlanUseCase: calculateNutritionPlanUseCase,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore
    )
    private(set) lazy var saveUserPreferenceUseCase: SaveUserPreferenceUseCase = SaveUserPreferenceUseCase(
        userPreferenceRepository: userPreferenceRepository
    )
    private(set) lazy var fetchUserPreferencesUseCase: FetchUserPreferencesUseCase = FetchUserPreferencesUseCase(
        userPreferenceRepository: userPreferenceRepository
    )
    private(set) lazy var logWorkoutUseCase: LogWorkoutUseCase = LogWorkoutUseCase(
        workoutEntryRepository: workoutEntryRepository,
        awardXPUseCase: awardXPUseCase,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore,
        analytics: analytics
    )
    private(set) lazy var saveProgressPhotoUseCase: SaveProgressPhotoUseCase = SaveProgressPhotoUseCase(
        progressPhotoRepository: progressPhotoRepository,
        fileStore: progressPhotoFileStore,
        awardXPUseCase: awardXPUseCase,
        analytics: analytics
    )
    private(set) lazy var deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase = DeleteProgressPhotoUseCase(
        progressPhotoRepository: progressPhotoRepository,
        fileStore: progressPhotoFileStore
    )
    private(set) lazy var deleteUserPreferenceUseCase: DeleteUserPreferenceUseCase = DeleteUserPreferenceUseCase(
        userPreferenceRepository: userPreferenceRepository
    )
    private(set) lazy var importHealthWeightUseCase: ImportHealthWeightUseCase = ImportHealthWeightUseCase(
        syncHealthDataUseCase: syncHealthDataUseCase,
        weightEntryRepository: weightEntryRepository
    )
    private(set) lazy var fetchProgressPhotosUseCase: FetchProgressPhotosUseCase = FetchProgressPhotosUseCase(
        progressPhotoRepository: progressPhotoRepository,
        fileStore: progressPhotoFileStore
    )
    private(set) lazy var saveBaselineBodyPhotoUseCase: SaveBaselineBodyPhotoUseCase = SaveBaselineBodyPhotoUseCase(
        saveProgressPhotoUseCase: saveProgressPhotoUseCase,
        fetchProgressPhotosUseCase: fetchProgressPhotosUseCase,
        deleteProgressPhotoUseCase: deleteProgressPhotoUseCase
    )
    private(set) lazy var deleteBaselineBodyPhotoUseCase: DeleteBaselineBodyPhotoUseCase = DeleteBaselineBodyPhotoUseCase(
        fetchProgressPhotosUseCase: fetchProgressPhotosUseCase,
        deleteProgressPhotoUseCase: deleteProgressPhotoUseCase
    )
    private(set) lazy var fetchProgressSummaryUseCase: FetchProgressSummaryUseCase = FetchProgressSummaryUseCase(
        foodEntryRepository: foodEntryRepository,
        waterEntryRepository: waterEntryRepository,
        weightEntryRepository: weightEntryRepository,
        workoutEntryRepository: workoutEntryRepository,
        fetchProgressPhotosUseCase: fetchProgressPhotosUseCase,
        rewardsRepository: rewardsRepository,
        evaluateStreakUseCase: evaluateStreakUseCase,
        userGoalsRepository: userGoalsRepository,
        fetchOnboardingStateUseCase: fetchOnboardingStateUseCase,
        calculateNutritionPlanUseCase: calculateNutritionPlanUseCase,
        healthActivityStore: healthDailyActivityRepository,
        refreshGoals: { [weak self] in try self?.refreshNutritionGoalsUseCase.execute() }
    )
    private(set) lazy var persistChatHistoryUseCase: PersistChatHistoryUseCase = PersistChatHistoryUseCase(
        chatHistoryRepository: chatHistoryRepository
    )
    private(set) lazy var parseAIAssistantActionsUseCase: ParseAIAssistantActionsUseCase = ParseAIAssistantActionsUseCase()
    private(set) lazy var confirmAIAssistantActionUseCase: ConfirmAIAssistantActionUseCase = ConfirmAIAssistantActionUseCase(
        logFoodUseCase: logFoodUseCase,
        replaceFoodEntryUseCase: replaceFoodEntryUseCase,
        logWaterUseCase: logWaterUseCase,
        saveUserPreferenceUseCase: saveUserPreferenceUseCase,
        recipeRepository: recipeRepository,
        foodEntryRepository: foodEntryRepository,
        awardXPUseCase: awardXPUseCase
    )
    private(set) lazy var computeNutritionFactsUseCase: ComputeNutritionFactsUseCase = ComputeNutritionFactsUseCase()
    private(set) lazy var updateAppSettingsUseCase: UpdateAppSettingsUseCase = UpdateAppSettingsUseCase(
        store: appSettingsStore
    )
    private(set) lazy var refreshSubscriptionStatusUseCase: RefreshSubscriptionStatusUseCase = RefreshSubscriptionStatusUseCase(
        subscriptionService: subscriptionService
    )
    private(set) lazy var requestHealthSyncAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase = RequestHealthSyncAuthorizationUseCase(
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore
    )
    private(set) lazy var syncHealthDataUseCase: SyncHealthDataUseCase = SyncHealthDataUseCase(
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore,
        waterEntryRepository: waterEntryRepository,
        weightEntryRepository: weightEntryRepository,
        workoutEntryRepository: workoutEntryRepository,
        foodEntryRepository: foodEntryRepository,
        userProfileRepository: userProfileRepository,
        activityStore: healthDailyActivityRepository,
        onProfileUpdated: { [weak self] profile in
            try self?.refreshNutritionGoalsUseCase.execute(profile: profile)
        },
        onProfileSaved: { [weak self] in self?.notifyDiaryChanged() }
    )
    private(set) lazy var healthSyncController: HealthSyncController = HealthSyncController(
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore,
        requestAuthorizationUseCase: requestHealthSyncAuthorizationUseCase,
        syncHealthDataUseCase: syncHealthDataUseCase
    )

    private(set) lazy var spoonacularBarcodeLookupService: SpoonacularBarcodeLookupService = SpoonacularBarcodeLookupService(
        spoonacularService: spoonacularService
    )
    private(set) lazy var lookupBarcodeProductUseCase: LookupBarcodeProductUseCase = LookupBarcodeProductUseCase(
        primary: openFoodFactsService,
        fallback: spoonacularBarcodeLookupService
    )
    private(set) lazy var foodPhotoAnalysisService: FoodPhotoAnalysisServiceProtocol = FoodPhotoAnalysisService(
        configuration: .production
    )
    private(set) lazy var analyzeFoodPhotoUseCase: AnalyzeFoodPhotoUseCase = AnalyzeFoodPhotoUseCase(
        foodPhotoAnalysisService: foodPhotoAnalysisService,
        buildAIAssistantUserContextUseCase: buildAIAssistantUserContextUseCase
    )
    private(set) lazy var textFoodAnalysisService: TextFoodAnalysisServiceProtocol = TextFoodAnalysisService(
        configuration: .production
    )
    private(set) lazy var analyzeTextFoodUseCase: AnalyzeTextFoodUseCase = AnalyzeTextFoodUseCase(
        textFoodAnalysisService: textFoodAnalysisService,
        buildAIAssistantUserContextUseCase: buildAIAssistantUserContextUseCase
    )
    private(set) lazy var voiceFoodTranscriptionService: VoiceFoodTranscriptionServiceProtocol = VoiceFoodTranscriptionService(
        configuration: .production
    )
    private(set) lazy var voiceFoodAudioRecorder: VoiceFoodAudioRecording = VoiceFoodAudioRecorder()
    private(set) lazy var transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase = TranscribeFoodVoiceUseCase(
        voiceFoodTranscriptionService: voiceFoodTranscriptionService
    )
    private(set) lazy var analyzeVoiceFoodUseCase: AnalyzeVoiceFoodUseCase = AnalyzeVoiceFoodUseCase(
        voiceFoodTranscriptionService: voiceFoodTranscriptionService,
        buildAIAssistantUserContextUseCase: buildAIAssistantUserContextUseCase
    )

    private(set) lazy var reminderPreferencesStore: ReminderPreferencesStoring = ReminderPreferencesStore()
    private(set) lazy var localNotificationScheduler: LocalNotificationScheduling = LocalNotificationScheduler()
    private(set) lazy var reminderHabitAnalyzer: ReminderHabitAnalyzing = ReminderHabitAnalyzer(
        foodEntryRepository: foodEntryRepository,
        waterEntryRepository: waterEntryRepository,
        weightEntryRepository: weightEntryRepository
    )
    private(set) lazy var reminderScheduleBuilder: ReminderScheduleBuilding = ReminderScheduleBuilder(
        foodEntryRepository: foodEntryRepository,
        weightEntryRepository: weightEntryRepository
    )
    private(set) lazy var requestNotificationPermissionUseCase: RequestNotificationPermissionUseCase = RequestNotificationPermissionUseCase(
        scheduler: localNotificationScheduler
    )
    private(set) lazy var refreshReminderScheduleUseCase: RefreshReminderScheduleUseCase = RefreshReminderScheduleUseCase(
        preferencesStore: reminderPreferencesStore,
        habitAnalyzer: reminderHabitAnalyzer,
        scheduleBuilder: reminderScheduleBuilder,
        scheduler: localNotificationScheduler
    )
    private(set) lazy var bootstrapRemindersUseCase: BootstrapRemindersUseCase = BootstrapRemindersUseCase(
        requestPermissionUseCase: requestNotificationPermissionUseCase,
        refreshReminderScheduleUseCase: refreshReminderScheduleUseCase
    )
    private(set) lazy var updateReminderPreferencesUseCase: UpdateReminderPreferencesUseCase = UpdateReminderPreferencesUseCase(
        store: reminderPreferencesStore,
        refreshReminderScheduleUseCase: refreshReminderScheduleUseCase
    )
    private(set) lazy var reminderScheduleController: ReminderScheduleController = {
        let controller = ReminderScheduleController(
            bootstrapRemindersUseCase: bootstrapRemindersUseCase,
            refreshReminderScheduleUseCase: refreshReminderScheduleUseCase,
            evaluateStreakUseCase: evaluateStreakUseCase
        )
        reminderRefreshHook.handler = { [weak controller] in
            controller?.refreshAfterDiaryChange()
        }
        return controller
    }()

    init(coreDataStack: CoreDataStack = CoreDataStack()) {
        self.coreDataStack = coreDataStack
    }

    private func notifyDiaryChanged() {
        reminderRefreshHook.call()
        badgeEvaluationHook.call()
        NotificationCenter.default.post(name: .bityDiaryDidChange, object: nil)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            fetchDailyDiaryUseCase: fetchDailyDiaryUseCase,
            logWaterUseCase: logWaterUseCase,
            deleteFoodEntryUseCase: deleteFoodEntryUseCase,
            updateFoodEntryUseCase: updateFoodEntryUseCase,
            scaleFoodPortionUseCase: scaleFoodPortionUseCase,
            logWorkoutUseCase: logWorkoutUseCase,
            logWeightUseCase: logWeightUseCase,
            deleteWaterEntryUseCase: deleteWaterEntryUseCase,
            deleteWorkoutEntryUseCase: deleteWorkoutEntryUseCase,
            appSettingsStore: appSettingsStore,
            fetchOnboardingStateUseCase: fetchOnboardingStateUseCase,
            calculateNutritionPlanUseCase: calculateNutritionPlanUseCase,
            evaluateStreakUseCase: evaluateStreakUseCase
        )
    }

    func makeRewardsViewModel() -> RewardsViewModel {
        RewardsViewModel(fetchRewardsScreenUseCase: fetchRewardsScreenUseCase)
    }

    func makeProgressViewModel() -> ProgressViewModel {
        ProgressViewModel(
            fetchProgressSummaryUseCase: fetchProgressSummaryUseCase,
            logWeightUseCase: logWeightUseCase,
            saveProgressPhotoUseCase: saveProgressPhotoUseCase,
            deleteProgressPhotoUseCase: deleteProgressPhotoUseCase,
            refreshSubscriptionStatusUseCase: refreshSubscriptionStatusUseCase
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            fetchDailyDiaryUseCase: fetchDailyDiaryUseCase,
            saveUserGoalsUseCase: saveUserGoalsUseCase,
            fetchOnboardingStateUseCase: fetchOnboardingStateUseCase,
            updateProfileAndGoalsUseCase: updateProfileAndGoalsUseCase,
            updateAppSettingsUseCase: updateAppSettingsUseCase,
            requestHealthSyncAuthorizationUseCase: requestHealthSyncAuthorizationUseCase,
            importHealthWeightUseCase: importHealthWeightUseCase,
            refreshSubscriptionStatusUseCase: refreshSubscriptionStatusUseCase,
            fetchUserPreferencesUseCase: fetchUserPreferencesUseCase,
            saveUserPreferenceUseCase: saveUserPreferenceUseCase,
            deleteUserPreferenceUseCase: deleteUserPreferenceUseCase,
            updateReminderPreferencesUseCase: updateReminderPreferencesUseCase,
            saveUserAvatarUseCase: saveUserAvatarUseCase,
            deleteUserAvatarUseCase: deleteUserAvatarUseCase,
            healthSync: healthSyncService
        )
    }

    func makeOnboardingFlowViewModel() -> OnboardingFlowViewModel {
        OnboardingFlowViewModel(
            fetchOnboardingStateUseCase: fetchOnboardingStateUseCase,
            saveUserProfileUseCase: saveUserProfileUseCase,
            calculateNutritionPlanUseCase: calculateNutritionPlanUseCase,
            completeOnboardingUseCase: completeOnboardingUseCase,
            requestHealthSyncAuthorizationUseCase: requestHealthSyncAuthorizationUseCase
        )
    }

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            fetchOnboardingStateUseCase: fetchOnboardingStateUseCase,
            saveUserProfileUseCase: saveUserProfileUseCase,
            calculateNutritionPlanUseCase: calculateNutritionPlanUseCase,
            completeOnboardingUseCase: completeOnboardingUseCase,
            saveUserAvatarUseCase: saveUserAvatarUseCase,
            deleteUserAvatarUseCase: deleteUserAvatarUseCase,
            fetchProgressPhotosUseCase: fetchProgressPhotosUseCase,
            saveBaselineBodyPhotoUseCase: saveBaselineBodyPhotoUseCase,
            deleteBaselineBodyPhotoUseCase: deleteBaselineBodyPhotoUseCase
        )
    }

    func makeVoiceFoodLoggingViewModel(
        mealType: MealType = .snacks,
        date: Date = Date()
    ) -> VoiceFoodLoggingViewModel {
        VoiceFoodLoggingViewModel(
            recorder: voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: transcribeFoodVoiceUseCase,
            analyzeTextFoodUseCase: analyzeTextFoodUseCase,
            mealType: mealType,
            date: date
        )
    }

    func makeAIAssistantViewModel(
        recipeContext: Recipe? = nil,
        initialInput: String? = nil,
        isPersistentSession: Bool = false
    ) -> AIAssistantViewModel {
        AIAssistantViewModel(
            aiAssistantService: aiAssistantService,
            fetchDailyDiaryUseCase: fetchDailyDiaryUseCase,
            logWaterUseCase: logWaterUseCase,
            recipeContext: recipeContext,
            initialInput: initialInput,
            buildAIAssistantUserContextUseCase: buildAIAssistantUserContextUseCase,
            parseAIAssistantActionsUseCase: parseAIAssistantActionsUseCase,
            confirmAIAssistantActionUseCase: confirmAIAssistantActionUseCase,
            persistChatHistoryUseCase: isPersistentSession ? persistChatHistoryUseCase : nil,
            deleteFoodEntryUseCase: deleteFoodEntryUseCase,
            searchFoodProductsUseCase: searchFoodProductsUseCase,
            voiceRecorder: voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: transcribeFoodVoiceUseCase
        )
    }

    func makeSubscriptionCoordinator() -> SubscriptionCoordinator {
        SubscriptionCoordinator(factory: paywallFactory)
    }
}

private final class CallbackHook {
    var handler: (() -> Void)?

    func call() {
        handler?()
    }
}
