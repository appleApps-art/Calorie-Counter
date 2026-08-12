import Foundation

final class OnboardingViewModel {
    let step = Observable(OnboardingStep.welcome)
    let profile = Observable(UserProfile.empty)
    let plan = Observable<NutritionPlan?>(nil)
    let titleText = Observable("")
    let subtitleText = Observable("")
    let detailsText = Observable("")
    let statusText = Observable("")
    let nextButtonTitle = Observable("")
    let canAdvance = Observable(true)
    let showsBack = Observable(false)
    let showsGoalPicker = Observable(false)
    let showsQuestions = Observable(false)
    let isCompleted = Observable(false)
    let avatarURL = Observable<URL?>(nil)
    let frontPhotoURL = Observable<URL?>(nil)
    let sidePhotoURL = Observable<URL?>(nil)
    let baselinePhotos = Observable(ProgressPhotoPair.empty)

    private let fetchOnboardingStateUseCase: FetchOnboardingStateUseCase
    private let saveUserProfileUseCase: SaveUserProfileUseCase
    private let calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase
    private let completeOnboardingUseCase: CompleteOnboardingUseCase
    private let saveUserAvatarUseCase: SaveUserAvatarUseCase
    private let deleteUserAvatarUseCase: DeleteUserAvatarUseCase
    private let fetchProgressPhotosUseCase: FetchProgressPhotosUseCase
    private let saveBaselineBodyPhotoUseCase: SaveBaselineBodyPhotoUseCase
    private let deleteBaselineBodyPhotoUseCase: DeleteBaselineBodyPhotoUseCase

    init(
        fetchOnboardingStateUseCase: FetchOnboardingStateUseCase,
        saveUserProfileUseCase: SaveUserProfileUseCase,
        calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase,
        completeOnboardingUseCase: CompleteOnboardingUseCase,
        saveUserAvatarUseCase: SaveUserAvatarUseCase,
        deleteUserAvatarUseCase: DeleteUserAvatarUseCase,
        fetchProgressPhotosUseCase: FetchProgressPhotosUseCase,
        saveBaselineBodyPhotoUseCase: SaveBaselineBodyPhotoUseCase,
        deleteBaselineBodyPhotoUseCase: DeleteBaselineBodyPhotoUseCase
    ) {
        self.fetchOnboardingStateUseCase = fetchOnboardingStateUseCase
        self.saveUserProfileUseCase = saveUserProfileUseCase
        self.calculateNutritionPlanUseCase = calculateNutritionPlanUseCase
        self.completeOnboardingUseCase = completeOnboardingUseCase
        self.saveUserAvatarUseCase = saveUserAvatarUseCase
        self.deleteUserAvatarUseCase = deleteUserAvatarUseCase
        self.fetchProgressPhotosUseCase = fetchProgressPhotosUseCase
        self.saveBaselineBodyPhotoUseCase = saveBaselineBodyPhotoUseCase
        self.deleteBaselineBodyPhotoUseCase = deleteBaselineBodyPhotoUseCase
    }

    func viewDidLoad() {
        load()
    }

    func load() {
        do {
            let stored = try fetchOnboardingStateUseCase.execute()
            apply(stored)
            applyBaseline(try fetchProgressPhotosUseCase.baselinePair())
            step.value = stored.onboardingCompleted ? .completed : stored.onboardingStep
            isCompleted.value = stored.onboardingCompleted
            if stored.isReadyForPlan {
                plan.value = calculateNutritionPlanUseCase.execute(profile: stored)
            }
            refreshAdvance()
        } catch {
            statusText.value = error.localizedDescription
            publishContent()
        }
    }

    func setGoal(_ goal: GoalType) {
        var next = profile.value
        next.goalType = goal
        next.onboardingStep = .goal
        persist(next)
    }

    func setSex(_ sex: BiologicalSex) {
        var next = profile.value
        next.sex = sex
        persist(next)
    }

    func setAge(_ age: Int) {
        var next = profile.value
        next.age = max(13, min(age, 100))
        persist(next)
    }

    func setHeight(_ centimeters: Double) {
        var next = profile.value
        next.heightCm = max(100, min(centimeters, 250))
        persist(next)
    }

    func setWeight(_ kilograms: Double) {
        var next = profile.value
        next.weightKg = max(30, min(kilograms, 300))
        persist(next)
    }

    func setActivity(_ level: ActivityLevel) {
        var next = profile.value
        next.activityLevel = level
        persist(next)
    }

    func setAvatar(imageData: Data) {
        do {
            apply(try saveUserAvatarUseCase.execute(imageData: imageData))
            statusText.value = L10n.tr("onboarding.photoSaved")
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func removeAvatar() {
        do {
            apply(try deleteUserAvatarUseCase.execute())
            statusText.value = L10n.tr("onboarding.photoRemoved")
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func setBodyPhoto(pose: ProgressPhotoPose, imageData: Data) {
        do {
            applyBaseline(try saveBaselineBodyPhotoUseCase.execute(imageData: imageData, pose: pose))
            statusText.value = L10n.format("onboarding.bodySaved", pose.title)
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func removeBodyPhoto(pose: ProgressPhotoPose) {
        do {
            applyBaseline(try deleteBaselineBodyPhotoUseCase.execute(pose: pose))
            statusText.value = L10n.format("onboarding.bodyRemoved", pose.title)
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func advance() {
        switch step.value {
        case .welcome:
            move(to: .goal)
        case .goal:
            guard profile.value.goalType != nil else {
                statusText.value = L10n.tr("onboarding.chooseGoal")
                return
            }
            move(to: .questions)
        case .questions:
            guard profile.value.isReadyForPlan else {
                statusText.value = L10n.tr("onboarding.answerQuestions")
                return
            }
            plan.value = calculateNutritionPlanUseCase.execute(profile: profile.value)
            move(to: .animation)
        case .animation:
            move(to: .plan)
        case .plan:
            move(to: .rating)
        case .rating:
            move(to: .aiIntro)
        case .aiIntro:
            complete()
        case .completed:
            break
        }
    }

    func back() {
        switch step.value {
        case .welcome, .completed:
            break
        case .goal:
            move(to: .welcome)
        case .questions:
            move(to: .goal)
        case .animation:
            move(to: .questions)
        case .plan:
            move(to: .animation)
        case .rating:
            move(to: .plan)
        case .aiIntro:
            move(to: .rating)
        }
    }

    func complete() {
        do {
            let finished = try completeOnboardingUseCase.execute(profile: profile.value)
            plan.value = finished
            var stored = profile.value
            stored.onboardingCompleted = true
            stored.onboardingStep = .completed
            apply(stored)
            step.value = .completed
            isCompleted.value = true
            statusText.value = L10n.tr("onboarding.planReady")
            refreshAdvance()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    private func move(to next: OnboardingStep) {
        var stored = profile.value
        stored.onboardingStep = next
        persist(stored)
        step.value = next
        statusText.value = ""
        refreshAdvance()
    }

    private func persist(_ next: UserProfile) {
        apply(next)
        do {
            try saveUserProfileUseCase.execute(next)
            if next.isReadyForPlan {
                plan.value = calculateNutritionPlanUseCase.execute(profile: next)
            }
            refreshAdvance()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    private func apply(_ stored: UserProfile) {
        profile.value = stored
        avatarURL.value = stored.avatarURL
    }

    private func applyBaseline(_ pair: ProgressPhotoPair) {
        baselinePhotos.value = pair
        frontPhotoURL.value = pair.front?.fileURL
        sidePhotoURL.value = pair.side?.fileURL
    }

    private func refreshAdvance() {
        switch step.value {
        case .welcome, .animation, .plan, .rating, .aiIntro:
            canAdvance.value = true
        case .goal:
            canAdvance.value = profile.value.goalType != nil
        case .questions:
            canAdvance.value = profile.value.isReadyForPlan
        case .completed:
            canAdvance.value = false
        }
        publishContent()
    }

    private func publishContent() {
        showsBack.value = step.value != .welcome && step.value != .completed
        showsGoalPicker.value = step.value == .goal
        showsQuestions.value = step.value == .questions
        nextButtonTitle.value = step.value == .aiIntro ? L10n.tr("onboarding.start") : L10n.tr("common.next")

        switch step.value {
        case .welcome:
            titleText.value = L10n.tr("onboarding.welcome.title")
            subtitleText.value = L10n.tr("onboarding.welcome.subtitle")
            detailsText.value = ""
        case .goal:
            titleText.value = L10n.tr("onboarding.goal.title")
            subtitleText.value = L10n.tr("onboarding.goal.subtitle")
            detailsText.value = ""
        case .questions:
            titleText.value = L10n.tr("onboarding.questions.title")
            subtitleText.value = L10n.tr("onboarding.questions.subtitle")
            detailsText.value = ""
        case .animation:
            titleText.value = L10n.tr("onboarding.animation.title")
            subtitleText.value = L10n.tr("onboarding.animation.subtitle")
            detailsText.value = ""
        case .plan:
            titleText.value = L10n.tr("onboarding.plan.title")
            subtitleText.value = L10n.tr("onboarding.plan.subtitle")
            if let plan = plan.value {
                detailsText.value = L10n.format(
                    "onboarding.plan.details",
                    Int(plan.goals.calorieTarget),
                    Int(plan.goals.proteinTarget),
                    Int(plan.goals.carbsTarget),
                    Int(plan.goals.fatsTarget)
                )
            } else {
                detailsText.value = ""
            }
        case .rating:
            titleText.value = L10n.tr("onboarding.rating.title")
            subtitleText.value = L10n.tr("onboarding.rating.subtitle")
            detailsText.value = ""
        case .aiIntro:
            titleText.value = L10n.tr("onboarding.aiIntro.title")
            subtitleText.value = L10n.tr("onboarding.aiIntro.subtitle")
            detailsText.value = ""
        case .completed:
            titleText.value = L10n.tr("onboarding.planReady")
            subtitleText.value = ""
            detailsText.value = ""
        }
    }
}
