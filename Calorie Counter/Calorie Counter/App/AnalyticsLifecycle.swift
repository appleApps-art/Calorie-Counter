import Foundation

/// Launches and sessions for analytics: the very first launch, every return to the app and where
/// the user was when they left it.
final class AnalyticsLifecycle {
    private enum Key {
        static let firstOpenAt = "bity.analytics.firstOpenAt"
        static let openCount = "bity.analytics.openCount"
        static let lastBackgroundAt = "bity.analytics.lastBackgroundAt"
    }

    private let analytics: AnalyticsHub
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let appVersion: String
    private let now: () -> Date
    private var foregroundSince: Date?

    init(
        analytics: AnalyticsHub = Analytics.hub,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        appVersion: String = AnalyticsLifecycle.bundleVersion,
        now: @escaping () -> Date = Date.init
    ) {
        self.analytics = analytics
        self.defaults = defaults
        self.calendar = calendar
        self.appVersion = appVersion
        self.now = now
    }

    /// - Parameters:
    ///   - isColdStart: the process was just launched rather than brought back from the background.
    ///   - isExistingUser: finished onboarding before this build tracked launches; such a user is
    ///     not reported as a first launch.
    ///   - snapshot: who the user is right now (plan, goal, streak, settings…), sent as user properties.
    func appWillEnterForeground(isColdStart: Bool, isExistingUser: Bool, snapshot: [String: Any]) {
        guard foregroundSince == nil else { return }
        let date = now()
        foregroundSince = date

        let firstOpen: Date
        if let stored = defaults.object(forKey: Key.firstOpenAt) as? Date {
            firstOpen = stored
        } else {
            firstOpen = date
            defaults.set(date, forKey: Key.firstOpenAt)
            if !isExistingUser {
                analytics.track(.appFirstOpened(appVersion: appVersion))
                analytics.setUserPropertiesOnce([
                    "first_open_date": Self.isoDate(date),
                    "first_app_version": appVersion
                ])
            }
        }

        let openCount = defaults.integer(forKey: Key.openCount) + 1
        defaults.set(openCount, forKey: Key.openCount)
        let daysSinceFirstOpen = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: firstOpen), to: calendar.startOfDay(for: date)
        ).day ?? 0
        let hoursAway = (defaults.object(forKey: Key.lastBackgroundAt) as? Date).map {
            max(0, Int(date.timeIntervalSince($0) / 3600))
        }

        analytics.journey.startSession()
        analytics.track(.appOpened(
            launch: isColdStart ? "cold" : "warm",
            openCount: openCount,
            daysSinceFirstOpen: max(0, daysSinceFirstOpen),
            hoursSinceLastOpen: hoursAway
        ))
        var properties = snapshot
        properties["open_count"] = openCount
        properties["days_since_first_open"] = max(0, daysSinceFirstOpen)
        properties["last_open_date"] = Self.isoDate(date)
        properties["app_version"] = appVersion
        analytics.setUserProperties(properties)
    }

    func appDidEnterBackground() {
        guard let since = foregroundSince else { return }
        let date = now()
        foregroundSince = nil
        defaults.set(date, forKey: Key.lastBackgroundAt)
        analytics.track(.appBackgrounded(
            secondsInForeground: max(0, Int(date.timeIntervalSince(since).rounded())),
            lastScreen: analytics.journey.currentScreen,
            secondsOnLastScreen: analytics.journey.secondsOnCurrentScreen(at: date)
        ))
    }

    static var bundleVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}

extension DIContainer {
    /// Who the user is at the start of a session, for segmenting every event by it.
    func analyticsUserSnapshot() -> [String: Any] {
        var properties: [String: Any] = [
            "is_premium": subscriptionService.currentStatus().isPremium,
            "theme": appSettingsStore.settings.appearanceMode.rawValue,
            "units": appSettingsStore.settings.usesMetric ? "metric" : "imperial",
            "health_sync_enabled": appSettingsStore.settings.healthSyncEnabled,
            "language": Locale.preferredLanguages.first ?? "unknown"
        ]
        if let profile = try? fetchOnboardingStateUseCase.execute() {
            properties["onboarding_completed"] = profile.onboardingCompleted
            if let goal = profile.goalType?.rawValue { properties["goal"] = goal }
            if let sex = profile.sex?.rawValue { properties["sex"] = sex }
            if let activity = profile.activityLevel?.rawValue { properties["activity_level"] = activity }
            if let age = profile.age { properties["age_group"] = Self.ageGroup(age) }
        }
        if let rewards = try? fetchRewardStateUseCase.execute() {
            properties["current_streak"] = rewards.currentStreak
            properties["longest_streak"] = rewards.longestStreak
            properties["level"] = rewards.level.number
            properties["xp"] = rewards.totalXP
            properties["badges_unlocked"] = rewards.unlockedBadgeIDs.count
        }
        properties["saved_recipes"] = (try? recipeRepository.fetchSaved().count) ?? 0
        return properties
    }

    static func ageGroup(_ age: Int) -> String {
        switch age {
        case ..<18: return "under_18"
        case 18..<25: return "18_24"
        case 25..<35: return "25_34"
        case 35..<45: return "35_44"
        case 45..<55: return "45_54"
        default: return "55_plus"
        }
    }
}
