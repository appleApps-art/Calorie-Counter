import Foundation

enum AnalyticsScreen: String {
    case splash
    case welcome
    case onboardingGoal = "onboarding_goal"
    case onboardingSex = "onboarding_sex"
    case onboardingAge = "onboarding_age"
    case onboardingBody = "onboarding_body"
    case onboardingHealth = "onboarding_health"
    case onboardingActivity = "onboarding_activity"
    case onboardingCalculating = "onboarding_calculating"
    case onboardingPlan = "onboarding_plan"
    case onboardingRating = "onboarding_rating"
    case appRating = "app_rating"
    case aiIntro = "ai_intro"
    case home
    case progress
    case aiAssistant = "ai_assistant"
    case aiChatHistory = "ai_chat_history"
    case recipes
    case recipesCreate = "recipes_create"
    case recipesCreateRecipe = "recipes_create_recipe"
    case recipesCreateMealPlan = "recipes_create_meal_plan"
    case recipeFilters = "recipe_filters"
    case recipeSection = "recipe_section"
    case myPantry = "my_pantry"
    case pantryAdd = "pantry_add"
    case pantryEdit = "pantry_edit"
    case fridgePhotoResult = "fridge_photo_result"
    case rewards
    case rewardDetail = "reward_detail"
    case settings
    case settingsNutritionGoals = "settings_nutrition_goals"
    case settingsWeightGoal = "settings_weight_goal"
    case settingsTheme = "settings_theme"
    case settingsHealth = "settings_health"
    case notifications
    case editMeal = "edit_meal"
    case foodSearch = "food_search"
    case barcodeScanner = "barcode_scanner"
    case barcodeManual = "barcode_manual"
    case aiPhoto = "ai_photo"
    case voiceLog = "voice_log"
    case textLog = "text_log"
    case productDetails = "product_details"
    case addFoodEntry = "add_food_entry"
    case quickLog = "quick_log"
    case glassVolume = "glass_volume"
    case logWeight = "log_weight"
    case logWorkout = "log_workout"
    case progressPhoto = "progress_photo"
    case progressPhotos = "progress_photos"
    case progressLog = "progress_log"
    case recipeDetail = "recipe_detail"
    case mealPlanPreview = "meal_plan_preview"
    case foodProductDetail = "food_product_detail"
    case changeDate = "change_date"
}

enum AnalyticsEvent {
    // Launches and sessions
    case appFirstOpened(appVersion: String)
    case appOpened(launch: String, openCount: Int, daysSinceFirstOpen: Int, hoursSinceLastOpen: Int?)
    case appBackgrounded(secondsInForeground: Int, lastScreen: String?, secondsOnLastScreen: Int?)

    case screenViewed(AnalyticsScreen)
    case tabSelected(String)
    case onboardingStarted
    case onboardingCompleted(goal: String?)
    case foodLogStarted(method: String, source: String, mealType: String)
    case foodLogged(method: String, mealType: String, calories: Int)
    case foodLogFailed(method: String)
    case foodSearchPerformed(queryLength: Int, resultCount: Int)
    case foodDeleted(mealType: String)
    case mealEditOpened(mealType: String, itemCount: Int)
    case mealAISent(mealType: String, hasImage: Bool)
    case mealAICompleted(mealType: String, success: Bool)
    case waterLogged(amountMilliliters: Int)
    case glassVolumeSaved(amountMilliliters: Int)
    case weightLogged
    case workoutLogged
    case progressPhotoSaved
    case aiMessageSent(hasImage: Bool, source: String)
    case aiMessageCompleted(success: Bool, actionCount: Int, source: String)
    case aiIntroCompleted
    case healthSyncToggled(enabled: Bool)
    case paywallShown(placement: String)
    case purchaseCompleted(placement: String, isPremium: Bool)
    case purchaseFailed(placement: String)
    case paywallClosed(placement: String)
    case appRatingShown(source: String)
    case appRatingTapped(action: String)

    // Onboarding answers, one per step
    case onboardingStepCompleted(step: String, value: String?)
    case onboardingStepBack(step: String)

    // Diary on Home
    case quickLogOptionSelected(option: String)
    case diaryDateChanged(daysFromToday: Int)
    case foodMarkedEaten(eaten: Bool, mealType: String)
    case allFoodMarkedEaten(count: Int)
    case foodPortionChanged(mealType: String)
    case waterRemoved

    // Recognition by photo, voice, text or barcode
    case foodRecognitionFinished(method: String, outcome: String, confidence: Int?)
    case foodItemOpened(source: String, foodType: String?)

    // Recipes, meal plans and pantry
    case recipeHubTabSelected(tab: String)
    case recipeOpened(source: String, origin: String)
    case recipeSectionOpened(section: String)
    case recipeFiltersApplied(count: Int)
    case recipeSaved(saved: Bool)
    case recipeAddTapped(mealType: String)
    case recipeShared
    case recipeCreateStarted(kind: String, source: String, ingredientCount: Int)
    case recipeCreateFinished(kind: String, success: Bool, origin: String?, seconds: Int)
    case mealPlanOpened
    case pantryItemsAdded(count: Int, method: String)
    case pantryItemsDeleted(count: Int)

    // Assistant actions the user confirms from a chat card
    case aiActionApplied(kind: String, success: Bool)

    // Rewards
    case badgeUnlocked(badge: String)
    case badgeCelebrationShown(badge: String)
    case badgeOpened(badge: String, earned: Bool)
    case badgeShared(badge: String)
    case levelReached(level: Int)

    // Settings and notifications
    case settingChanged(name: String, value: String)
    case notificationOpened(kind: String)
    case notificationPermissionAnswered(granted: Bool)

    // Friction: where the app could not do what the user asked
    case errorShown(context: String, reason: String)
    case offlineStateShown(context: String)
    case retryTapped(context: String)

    var appRatingTriggerSource: String? {
        switch self {
        case .foodLogged:
            return "food_logged"
        case .waterLogged:
            return "water_logged"
        case .weightLogged:
            return "weight_logged"
        case .workoutLogged:
            return "workout_logged"
        case .foodSearchPerformed:
            return "food_search"
        case .progressPhotoSaved:
            return "progress_photo"
        case .mealAICompleted(_, let success):
            return success ? "meal_ai" : nil
        default:
            return nil
        }
    }

    var name: String {
        switch self {
        case .appFirstOpened:
            return "app_first_opened"
        case .appOpened:
            return "app_opened"
        case .appBackgrounded:
            return "app_backgrounded"
        case .onboardingStepCompleted:
            return "onboarding_step_completed"
        case .onboardingStepBack:
            return "onboarding_step_back"
        case .quickLogOptionSelected:
            return "quick_log_option_selected"
        case .diaryDateChanged:
            return "diary_date_changed"
        case .foodMarkedEaten:
            return "food_marked_eaten"
        case .allFoodMarkedEaten:
            return "all_food_marked_eaten"
        case .foodPortionChanged:
            return "food_portion_changed"
        case .waterRemoved:
            return "water_removed"
        case .foodRecognitionFinished:
            return "food_recognition_finished"
        case .foodItemOpened:
            return "food_item_opened"
        case .recipeHubTabSelected:
            return "recipe_hub_tab_selected"
        case .recipeOpened:
            return "recipe_opened"
        case .recipeSectionOpened:
            return "recipe_section_opened"
        case .recipeFiltersApplied:
            return "recipe_filters_applied"
        case .recipeSaved:
            return "recipe_saved"
        case .recipeAddTapped:
            return "recipe_add_tapped"
        case .recipeShared:
            return "recipe_shared"
        case .recipeCreateStarted:
            return "recipe_create_started"
        case .recipeCreateFinished:
            return "recipe_create_finished"
        case .mealPlanOpened:
            return "meal_plan_opened"
        case .pantryItemsAdded:
            return "pantry_items_added"
        case .pantryItemsDeleted:
            return "pantry_items_deleted"
        case .aiActionApplied:
            return "ai_action_applied"
        case .badgeUnlocked:
            return "badge_unlocked"
        case .badgeCelebrationShown:
            return "badge_celebration_shown"
        case .badgeOpened:
            return "badge_opened"
        case .badgeShared:
            return "badge_shared"
        case .levelReached:
            return "level_reached"
        case .settingChanged:
            return "setting_changed"
        case .notificationOpened:
            return "notification_opened"
        case .notificationPermissionAnswered:
            return "notification_permission_answered"
        case .errorShown:
            return "error_shown"
        case .offlineStateShown:
            return "offline_state_shown"
        case .retryTapped:
            return "retry_tapped"
        case .screenViewed:
            return "screen_viewed"
        case .tabSelected:
            return "tab_selected"
        case .onboardingStarted:
            return "onboarding_started"
        case .onboardingCompleted:
            return "onboarding_completed"
        case .foodLogStarted:
            return "food_log_started"
        case .foodLogged:
            return "food_logged"
        case .foodLogFailed:
            return "food_log_failed"
        case .foodSearchPerformed:
            return "food_search_performed"
        case .foodDeleted:
            return "food_deleted"
        case .mealEditOpened:
            return "meal_edit_opened"
        case .mealAISent:
            return "meal_ai_sent"
        case .mealAICompleted:
            return "meal_ai_completed"
        case .waterLogged:
            return "water_logged"
        case .glassVolumeSaved:
            return "glass_volume_saved"
        case .weightLogged:
            return "weight_logged"
        case .workoutLogged:
            return "workout_logged"
        case .progressPhotoSaved:
            return "progress_photo_saved"
        case .aiMessageSent:
            return "ai_message_sent"
        case .aiMessageCompleted:
            return "ai_message_completed"
        case .aiIntroCompleted:
            return "ai_intro_completed"
        case .healthSyncToggled:
            return "health_sync_toggled"
        case .paywallShown:
            return "paywall_shown"
        case .purchaseCompleted:
            return "purchase_completed"
        case .purchaseFailed:
            return "purchase_failed"
        case .paywallClosed:
            return "paywall_closed"
        case .appRatingShown:
            return "app_rating_shown"
        case .appRatingTapped:
            return "app_rating_tapped"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .appFirstOpened(let appVersion):
            return ["app_version": appVersion]
        case .appOpened(let launch, let openCount, let daysSinceFirstOpen, let hoursSinceLastOpen):
            var properties: [String: Any] = [
                "launch": launch, "open_count": openCount, "days_since_first_open": daysSinceFirstOpen
            ]
            properties["hours_since_last_open"] = hoursSinceLastOpen
            return properties
        case .appBackgrounded(let secondsInForeground, let lastScreen, let secondsOnLastScreen):
            var properties: [String: Any] = ["seconds_in_foreground": secondsInForeground]
            properties["last_screen"] = lastScreen
            properties["seconds_on_last_screen"] = secondsOnLastScreen
            return properties
        case .onboardingStepCompleted(let step, let value):
            var properties: [String: Any] = ["step": step]
            properties["value"] = value
            return properties
        case .onboardingStepBack(let step):
            return ["step": step]
        case .quickLogOptionSelected(let option):
            return ["option": option]
        case .diaryDateChanged(let days):
            return ["days_from_today": days]
        case .foodMarkedEaten(let eaten, let mealType):
            return ["eaten": eaten, "meal_type": mealType]
        case .allFoodMarkedEaten(let count):
            return ["count": count]
        case .foodPortionChanged(let mealType):
            return ["meal_type": mealType]
        case .waterRemoved, .recipeShared, .mealPlanOpened:
            return [:]
        case .foodRecognitionFinished(let method, let outcome, let confidence):
            var properties: [String: Any] = ["method": method, "outcome": outcome]
            properties["confidence"] = confidence
            return properties
        case .foodItemOpened(let source, let foodType):
            var properties: [String: Any] = ["source": source]
            properties["food_type"] = foodType
            return properties
        case .recipeHubTabSelected(let tab):
            return ["tab": tab]
        case .recipeOpened(let source, let origin):
            return ["source": source, "origin": origin]
        case .recipeSectionOpened(let section):
            return ["section": section]
        case .recipeFiltersApplied(let count):
            return ["filter_count": count]
        case .recipeSaved(let saved):
            return ["saved": saved]
        case .recipeAddTapped(let mealType):
            return ["meal_type": mealType]
        case .recipeCreateStarted(let kind, let source, let ingredientCount):
            return ["kind": kind, "source": source, "ingredient_count": ingredientCount]
        case .recipeCreateFinished(let kind, let success, let origin, let seconds):
            var properties: [String: Any] = ["kind": kind, "success": success, "seconds": seconds]
            properties["origin"] = origin
            return properties
        case .pantryItemsAdded(let count, let method):
            return ["count": count, "method": method]
        case .pantryItemsDeleted(let count):
            return ["count": count]
        case .aiActionApplied(let kind, let success):
            return ["kind": kind, "success": success]
        case .badgeUnlocked(let badge), .badgeCelebrationShown(let badge), .badgeShared(let badge):
            return ["badge": badge]
        case .badgeOpened(let badge, let earned):
            return ["badge": badge, "earned": earned]
        case .levelReached(let level):
            return ["level": level]
        case .settingChanged(let name, let value):
            return ["setting": name, "value": value]
        case .notificationOpened(let kind):
            return ["kind": kind]
        case .notificationPermissionAnswered(let granted):
            return ["granted": granted]
        case .errorShown(let context, let reason):
            return ["context": context, "reason": reason]
        case .offlineStateShown(let context), .retryTapped(let context):
            return ["context": context]
        case .screenViewed(let screen):
            return ["screen": screen.rawValue]
        case .tabSelected(let tab):
            return ["tab": tab]
        case .onboardingStarted, .weightLogged, .workoutLogged, .progressPhotoSaved, .aiIntroCompleted:
            return [:]
        case .onboardingCompleted(let goal):
            return goal.map { ["goal": $0] } ?? [:]
        case .foodLogStarted(let method, let source, let mealType):
            return ["method": method, "source": source, "meal_type": mealType]
        case .foodLogged(let method, let mealType, let calories):
            return ["method": method, "meal_type": mealType, "calories": calories]
        case .foodLogFailed(let method):
            return ["method": method]
        case .foodSearchPerformed(let queryLength, let resultCount):
            return ["query_length": queryLength, "result_count": resultCount]
        case .foodDeleted(let mealType):
            return ["meal_type": mealType]
        case .mealEditOpened(let mealType, let itemCount):
            return ["meal_type": mealType, "item_count": itemCount]
        case .mealAISent(let mealType, let hasImage):
            return ["meal_type": mealType, "has_image": hasImage]
        case .mealAICompleted(let mealType, let success):
            return ["meal_type": mealType, "success": success]
        case .waterLogged(let amount):
            return ["amount_ml": amount]
        case .glassVolumeSaved(let amount):
            return ["amount_ml": amount]
        case .aiMessageSent(let hasImage, let source):
            return ["has_image": hasImage, "source": source]
        case .aiMessageCompleted(let success, let actionCount, let source):
            return ["success": success, "action_count": actionCount, "source": source]
        case .healthSyncToggled(let enabled):
            return ["enabled": enabled]
        case .paywallShown(let placement), .paywallClosed(let placement), .purchaseFailed(let placement):
            return ["placement": placement]
        case .purchaseCompleted(let placement, let isPremium):
            return ["placement": placement, "is_premium": isPremium]
        case .appRatingShown(let source):
            return ["source": source]
        case .appRatingTapped(let action):
            return ["action": action]
        }
    }
}

extension AnalyticsEvent {
    /// A photo, voice, text or barcode recognition that gave the user a result.
    static func recognized(_ method: String, confidence: Double? = nil) -> AnalyticsEvent {
        .foodRecognitionFinished(
            method: method,
            outcome: "recognized",
            confidence: confidence.map { Int(($0 * 100).rounded()) }
        )
    }

    /// Why a recognition gave the user nothing: no connection, nothing edible, an unknown barcode
    /// or the service failing.
    static func recognitionFailed(_ method: String, error: Error) -> AnalyticsEvent {
        let outcome: String
        if (error as? FoodPhotoAnalysisError) == .noFood {
            outcome = "no_food"
        } else if (error as? BarcodeLookupError) == .notFound {
            outcome = "not_found"
        } else if error.isNoConnection {
            outcome = "offline"
        } else {
            outcome = "failed"
        }
        return .foodRecognitionFinished(method: method, outcome: outcome, confidence: nil)
    }
}

extension AIAssistantAction {
    var analyticsKind: String {
        switch self {
        case .logFood: return "log_food"
        case .replaceFood: return "replace_food"
        case .swapFood: return "swap_food"
        case .mealSuggestions: return "meal_suggestions"
        case .saveRecipe: return "save_recipe"
        case .swapRecipeIngredient: return "swap_recipe_ingredient"
        case .swapMealPlanMeal: return "swap_meal_plan_meal"
        case .logWater: return "log_water"
        case .savePreference: return "save_preference"
        }
    }
}
