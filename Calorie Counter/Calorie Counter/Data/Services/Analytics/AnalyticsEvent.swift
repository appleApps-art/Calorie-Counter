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
}

enum AnalyticsEvent {
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
