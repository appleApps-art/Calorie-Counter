import Foundation

/// What a free account may try a few times before the paywall. Each scanner has its own single try;
/// Bity answers two messages in total.
enum FreeUsageFeature: String, CaseIterable {
    case foodPhotoScan
    case barcodeScan
    case fridgeScan
    case aiMessage

    var freeLimit: Int {
        switch self {
        case .aiMessage:
            return 2
        case .foodPhotoScan, .barcodeScan, .fridgeScan:
            return 1
        }
    }
}

/// Features that need Premium from the first use.
enum PremiumFeature: String {
    case mealPlan
    case recipeGeneration
    case analytics
    case insights
}

protocol FeatureAccessChecking: AnyObject {
    var isPremium: Bool { get }
    func remainingFreeUses(of feature: FreeUsageFeature) -> Int
    func recordUse(of feature: FreeUsageFeature)
}

extension FeatureAccessChecking {
    func canUse(_ feature: FreeUsageFeature) -> Bool {
        isPremium || remainingFreeUses(of: feature) > 0
    }
}

/// Counts free tries on the device. A try is spent only when it worked (a recognized photo, a found
/// barcode, an answered message), so a failed scan never costs the one free attempt.
final class FeatureAccessController: FeatureAccessChecking {
    private let subscriptionService: SubscriptionStatusProviding
    private let defaults: UserDefaults
    static let keyPrefix = "bity.freeUsage."

    init(subscriptionService: SubscriptionStatusProviding, defaults: UserDefaults = .standard) {
        self.subscriptionService = subscriptionService
        self.defaults = defaults
    }

    var isPremium: Bool {
        subscriptionService.currentStatus().isPremium
    }

    func remainingFreeUses(of feature: FreeUsageFeature) -> Int {
        max(0, feature.freeLimit - defaults.integer(forKey: Self.key(feature)))
    }

    func recordUse(of feature: FreeUsageFeature) {
        guard !isPremium else { return }
        let key = Self.key(feature)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    func resetFreeUses() {
        FreeUsageFeature.allCases.forEach { defaults.removeObject(forKey: Self.key($0)) }
    }

    func exhaustFreeUses() {
        FreeUsageFeature.allCases.forEach { defaults.set($0.freeLimit, forKey: Self.key($0)) }
    }

    private static func key(_ feature: FreeUsageFeature) -> String {
        keyPrefix + feature.rawValue
    }
}
