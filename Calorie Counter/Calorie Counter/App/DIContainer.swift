import Foundation

final class DIContainer {
    let coreDataStack: CoreDataStack
    private let reminderRefreshHook = ReminderRefreshHook()

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
        onChange: { [reminderRefreshHook] in
            reminderRefreshHook.call()
        }
    )
    private(set) lazy var waterEntryRepository: WaterEntryRepositoryProtocol = DiaryChangeNotifyingWaterEntryRepository(
        base: waterEntryRepositoryBase,
        onChange: { [reminderRefreshHook] in
            reminderRefreshHook.call()
        }
    )
    private(set) lazy var weightEntryRepository: WeightEntryRepositoryProtocol = DiaryChangeNotifyingWeightEntryRepository(
        base: weightEntryRepositoryBase,
        onChange: { [reminderRefreshHook] in
            reminderRefreshHook.call()
        }
    )
    private(set) lazy var userGoalsRepository: UserGoalsRepositoryProtocol = UserGoalsRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var recipeRepository: RecipeRepositoryProtocol = RecipeRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var userProfileRepository: UserProfileRepositoryProtocol = UserProfileRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var userPreferenceRepository: UserPreferenceRepositoryProtocol = UserPreferenceRepository(
        coreDataStack: coreDataStack
    )
    private(set) lazy var workoutEntryRepository: WorkoutEntryRepositoryProtocol = WorkoutEntryRepository(
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
        workoutEntryRepository: workoutEntryRepository
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
    private(set) lazy var searchRecipesUseCase: SearchRecipesUseCase = SearchRecipesUseCase(
        spoonacularService: spoonacularService
    )
    private(set) lazy var searchFoodProductsUseCase: SearchFoodProductsUseCase = SearchFoodProductsUseCase(
        spoonacularService: spoonacularService
    )
    private(set) lazy var appSettingsStore: AppSettingsStoring = AppSettingsStore()
    private(set) lazy var healthSyncService: HealthSyncing = HealthKitSyncService()
    private(set) lazy var subscriptionService: SubscriptionStatusProviding = StoreKitSubscriptionService()
    private(set) lazy var progressPhotoFileStore: ProgressPhotoFileStoring = LocalImageFileStore(folderName: "ProgressPhotos")
    private(set) lazy var avatarFileStore: LocalImageFileStoring = LocalImageFileStore(folderName: "ProfileAvatar")

    private(set) lazy var evaluateBadgesUseCase: EvaluateBadgesUseCase = EvaluateBadgesUseCase(
        rewardsRepository: rewardsRepository,
        foodEntryRepository: foodEntryRepository,
        waterEntryRepository: waterEntryRepository,
        weightEntryRepository: weightEntryRepository,
        workoutEntryRepository: workoutEntryRepository,
        progressPhotoRepository: progressPhotoRepository
    )
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

    private(set) lazy var logFoodUseCase: LogFoodUseCase = LogFoodUseCase(
        foodEntryRepository: foodEntryRepository,
        awardXPUseCase: awardXPUseCase
    )
    private(set) lazy var updateFoodEntryUseCase: UpdateFoodEntryUseCase = UpdateFoodEntryUseCase(
        foodEntryRepository: foodEntryRepository
    )
    private(set) lazy var deleteFoodEntryUseCase: DeleteFoodEntryUseCase = DeleteFoodEntryUseCase(
        foodEntryRepository: foodEntryRepository
    )
    private(set) lazy var deleteWaterEntryUseCase: DeleteWaterEntryUseCase = DeleteWaterEntryUseCase(
        waterEntryRepository: waterEntryRepository
    )
    private(set) lazy var deleteWorkoutEntryUseCase: DeleteWorkoutEntryUseCase = DeleteWorkoutEntryUseCase(
        workoutEntryRepository: workoutEntryRepository
    )
    private(set) lazy var fetchWeightHistoryUseCase: FetchWeightHistoryUseCase = FetchWeightHistoryUseCase(
        weightEntryRepository: weightEntryRepository
    )
    private(set) lazy var scaleFoodPortionUseCase: ScaleFoodPortionUseCase = ScaleFoodPortionUseCase()
    private(set) lazy var replaceFoodEntryUseCase: ReplaceFoodEntryUseCase = ReplaceFoodEntryUseCase(
        foodEntryRepository: foodEntryRepository,
        awardXPUseCase: awardXPUseCase
    )
    private(set) lazy var logWaterUseCase: LogWaterUseCase = LogWaterUseCase(
        waterEntryRepository: waterEntryRepository,
        awardXPUseCase: awardXPUseCase,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore
    )
    private(set) lazy var logWeightUseCase: LogWeightUseCase = LogWeightUseCase(
        weightEntryRepository: weightEntryRepository,
        awardXPUseCase: awardXPUseCase,
        healthSync: healthSyncService,
        appSettingsStore: appSettingsStore
    )
    private(set) lazy var saveUserGoalsUseCase: SaveUserGoalsUseCase = SaveUserGoalsUseCase(
        userGoalsRepository: userGoalsRepository
    )
    private(set) lazy var calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase = CalculateNutritionPlanUseCase()
    private(set) lazy var fetchOnboardingStateUseCase: FetchOnboardingStateUseCase = FetchOnboardingStateUseCase(
        userProfileRepository: userProfileRepository,
        avatarFileStore: avatarFileStore
    )
    private(set) lazy var saveUserProfileUseCase: SaveUserProfileUseCase = SaveUserProfileUseCase(
        userProfileRepository: userProfileRepository
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
        calculateNutritionPlanUseCase: calculateNutritionPlanUseCase
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
        appSettingsStore: appSettingsStore
    )
    private(set) lazy var saveProgressPhotoUseCase: SaveProgressPhotoUseCase = SaveProgressPhotoUseCase(
        progressPhotoRepository: progressPhotoRepository,
        fileStore: progressPhotoFileStore,
        awardXPUseCase: awardXPUseCase
    )
    private(set) lazy var deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase = DeleteProgressPhotoUseCase(
        progressPhotoRepository: progressPhotoRepository,
        fileStore: progressPhotoFileStore
    )
    private(set) lazy var deleteUserPreferenceUseCase: DeleteUserPreferenceUseCase = DeleteUserPreferenceUseCase(
        userPreferenceRepository: userPreferenceRepository
    )
    private(set) lazy var importHealthWeightUseCase: ImportHealthWeightUseCase = ImportHealthWeightUseCase(
        healthSync: healthSyncService,
        logWeightUseCase: logWeightUseCase
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
        evaluateStreakUseCase: evaluateStreakUseCase
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

    private(set) lazy var openFoodFactsService: OpenFoodFactsService = OpenFoodFactsService()
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
            deleteWorkoutEntryUseCase: deleteWorkoutEntryUseCase
        )
    }

    func makeProgressViewModel() -> ProgressViewModel {
        ProgressViewModel(
            fetchProgressSummaryUseCase: fetchProgressSummaryUseCase,
            logWeightUseCase: logWeightUseCase,
            saveProgressPhotoUseCase: saveProgressPhotoUseCase,
            deleteProgressPhotoUseCase: deleteProgressPhotoUseCase,
            fetchProgressPhotosUseCase: fetchProgressPhotosUseCase,
            fetchRewardStateUseCase: fetchRewardStateUseCase
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

    func makeVoiceFoodLoggingViewModel() -> VoiceFoodLoggingViewModel {
        VoiceFoodLoggingViewModel(
            recorder: voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: transcribeFoodVoiceUseCase,
            analyzeVoiceFoodUseCase: analyzeVoiceFoodUseCase,
            logFoodUseCase: logFoodUseCase
        )
    }
}

private final class ReminderRefreshHook {
    var handler: (() -> Void)?

    func call() {
        handler?()
    }
}
