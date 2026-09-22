import UIKit

enum PremiumGate {
    static func requirePremium(
        isPremium: Bool,
        coordinator: SubscriptionCoordinator,
        from presenter: UIViewController,
        placement: SubscriptionPlacement = .main,
        onUnlocked: @escaping () -> Void
    ) {
        if isPremium {
            onUnlocked()
            return
        }
        var didUnlock = false
        coordinator.presentPaywall(
            from: presenter,
            placement: placement,
            events: SubscriptionPaywallEvents(
                onPurchased: { status in
                    guard status.isPremium, !didUnlock else { return }
                    didUnlock = true
                    onUnlocked()
                },
                onRestored: { status in
                    guard status.isPremium, !didUnlock else { return }
                    didUnlock = true
                    onUnlocked()
                },
                onError: { error in
                    Analytics.tracker.track(.errorShown(
                        context: "paywall_\(placement.rawValue)",
                        reason: error.isNoConnection ? "offline" : "unavailable"
                    ))
                    let alert = UIAlertController(
                        title: nil,
                        message: error.isNoConnection
                            ? L10n.tr("offline.message")
                            : L10n.tr("subscription.paywallUnavailable"),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
                    presenter.present(alert, animated: true)
                }
            )
        )
    }
}

/// One place that knows how to reach the paywall, so a screen that runs out of free tries (a
/// scanner, the chat) can ask for it without a coordinator threaded through every initializer.
enum PremiumPrompt {
    static var makeCoordinator: (() -> SubscriptionCoordinator)?
    static var featureAccess: FeatureAccessChecking?

    static var isPremium: Bool {
        featureAccess?.isPremium ?? false
    }

    /// Runs `action` at once for Premium, otherwise opens the paywall and runs it after a purchase.
    static func requirePremium(from presenter: UIViewController?, then action: @escaping () -> Void) {
        guard let access = featureAccess, let makeCoordinator else {
            action()
            return
        }
        if access.isPremium {
            action()
            return
        }
        // Without a screen to show the paywall on, nothing runs: the action is what needs Premium.
        guard let presenter else { return }
        PremiumGate.requirePremium(
            isPremium: false,
            coordinator: makeCoordinator(),
            from: presenter.topPresented,
            onUnlocked: action
        )
    }

    /// Runs `action` while a free try is left (or for Premium), otherwise opens the paywall.
    static func requireFreeUse(
        _ feature: FreeUsageFeature,
        from presenter: UIViewController?,
        then action: @escaping () -> Void
    ) {
        guard let access = featureAccess, !access.canUse(feature) else {
            action()
            return
        }
        requirePremium(from: presenter, then: action)
    }

    static func canUse(_ feature: FreeUsageFeature) -> Bool {
        featureAccess?.canUse(feature) ?? true
    }

    static func remainingFreeUses(of feature: FreeUsageFeature) -> Int? {
        guard let access = featureAccess, !access.isPremium else { return nil }
        return access.remainingFreeUses(of: feature)
    }

    static func recordUse(of feature: FreeUsageFeature) {
        featureAccess?.recordUse(of: feature)
    }
}

private extension UIViewController {
    /// The screen actually on top, so a paywall asked for from a pushed or presented screen does
    /// not try to present from one that is already presenting.
    var topPresented: UIViewController {
        var current: UIViewController = self
        while let next = current.presentedViewController, !next.isBeingDismissed {
            current = next
        }
        return current
    }
}
