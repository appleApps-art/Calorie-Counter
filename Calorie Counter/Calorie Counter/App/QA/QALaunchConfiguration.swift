#if DEBUG
import Foundation

enum QASeedKind: String {
    case empty
    case filled
    case none
}

enum QARoute: String, CaseIterable {
    case recipesAll
    case recipesSaved
    case recipesSavedEmpty
    case recipesMealPlans
    case recipesMealPlansEmpty
    case recipesSearch
    case recipesSearchEmpty
    case recipesFilters
    case recipesSection
    case pantry
    case pantrySelect
    case pantrySelected
    case pantryDelete
    case pantryAdd
    case fridgeResult
    case pantryEdit
    case pantryProduct
    case recipesCreate
    case recipesCreateRecipe
    case recipesCreateCustom
    case recipesCreateMealPlan
    case recipeDetail
    case recipeDetailIngredients
    case recipeDetailInstructions
    case mealPlanPreview
    case mealPlanSwap
    case mealPlanSwapLoading
    case home
    case homeGlassVolume
    case progress
    case progressLog
    case progressPhotos
    case settings
    case settingsNutrition
    case settingsWeight
    case settingsTheme
    case settingsNotifications
    case settingsHealth
    case aiIntro
    case aiChat
    case aiMealSuggestion
    case aiFoodSwap
    case aiMealLogged
    case aiHistory
    case foodSearch
    case foodSearchResults
    case productDetails
    case addFoodEntry
    case foodRecipe
    case editMeal
    case textFood
    case voiceFood
    case voiceFoodResult
    case photoFood
    case photoFoodResult
    case barcodeScanner
    case logWeight
    case logWorkout
    case logWeightDate
    case logWorkoutDate
    case rewards
    case rewardDetail
    case rewardCelebration
    case onboardingWelcome
    case onboardingGoal
    case onboardingSex
    case onboardingActivity
    case onboardingAge
    case onboardingBody
    case onboardingHealth
    case onboardingPlan
    case appRating
}

enum QALaunchConfiguration {
    private static let arguments = ProcessInfo.processInfo.arguments
    private static let environment = ProcessInfo.processInfo.environment

    static var isActive: Bool {
        if environment["BITY_QA"] == "1" { return true }
        return arguments.contains(where: { $0 == "-qa" || $0.hasPrefix("-qa") })
    }

    static var skipOnboarding: Bool {
        flag("-qaSkipOnboarding") || isActive
    }

    static var skipSplash: Bool {
        flag("-qaSkipSplash") || isActive
    }

    static var cleanupOnly: Bool {
        flag("-qaCleanup")
    }

    static var capture: Bool {
        flag("-qaCapture")
    }

    static var theme: AppearanceMode? {
        switch value("-qaTheme")?.lowercased() {
        case "light": return .light
        case "dark": return .dark
        case "system": return .system
        default: return isActive ? .light : nil
        }
    }

    static var premium: Bool? {
        switch value("-qaPremium")?.lowercased() {
        case "0", "false", "off", "free": return false
        case "1", "true", "on", "premium": return true
        default: return nil
        }
    }

    static var seed: QASeedKind {
        switch value("-qaSeed")?.lowercased() {
        case "empty": return .empty
        case "filled": return .filled
        case "none": return .none
        default: return isActive && !cleanupOnly ? .filled : .none
        }
    }

    static var route: QARoute? {
        QARoute(rawValue: value("-qaRoute") ?? "")
    }

    static var captureSet: String {
        value("-qaCaptureSet") ?? "filled"
    }

    private static func flag(_ name: String) -> Bool {
        arguments.contains(name) || environment[name.trimmingCharacters(in: CharacterSet(charactersIn: "-"))] == "1"
    }

    private static func value(_ name: String) -> String? {
        if let index = arguments.firstIndex(of: name) {
            let next = arguments.index(after: index)
            if next < arguments.endIndex {
                let value = arguments[next]
                if !value.hasPrefix("-") { return value }
            }
        }
        return environment[name.trimmingCharacters(in: CharacterSet(charactersIn: "-"))]
    }
}
#endif
