import UIKit

final class SubscriptionCoordinator {
    private let factory: SubscriptionPaywallPresenting

    init(factory: SubscriptionPaywallPresenting) {
        self.factory = factory
    }

    func presentPaywall(
        from presenter: UIViewController,
        placement: SubscriptionPlacement,
        animated: Bool = true,
        events: SubscriptionPaywallEvents = SubscriptionPaywallEvents()
    ) {
        // A purchase needs the store; offline the flow moves on at once instead of showing plans
        // that cannot be bought.
        guard NetworkMonitor.shared.isOnline else {
            events.onError(NoConnectionError())
            return
        }
        // Bity's own paywall is ready at once, so it is on screen in the frame it was asked for.
        if let paywall = makePaywall(placement: placement, events: events) {
            paywall.modalPresentationStyle = .fullScreen
            presenter.present(paywall, animated: animated)
            return
        }
        let tracked = Self.tracked(events, placement: placement)
        Task { @MainActor in
            do {
                let paywall = try await factory.makePaywallViewController(placement: placement, events: tracked)
                paywall.modalPresentationStyle = .fullScreen
                presenter.present(paywall, animated: animated)
            } catch {
                events.onError(error)
            }
        }
    }

    /// The paywall itself, for a flow that places it on screen on its own (onboarding shows it in
    /// the same frame its last step disappears). Nil offline, like `presentPaywall`.
    func makePaywall(
        placement: SubscriptionPlacement,
        events: SubscriptionPaywallEvents = SubscriptionPaywallEvents()
    ) -> UIViewController? {
        guard NetworkMonitor.shared.isOnline else { return nil }
        return (factory as? NativePaywallFactory)?.makePaywall(
            placement: placement,
            events: Self.tracked(events, placement: placement)
        )
    }

    func makePaywallViewController(
        placement: SubscriptionPlacement,
        events: SubscriptionPaywallEvents = SubscriptionPaywallEvents()
    ) async throws -> UIViewController {
        try await factory.makePaywallViewController(placement: placement, events: events)
    }

    private static func tracked(_ events: SubscriptionPaywallEvents, placement: SubscriptionPlacement) -> SubscriptionPaywallEvents {
        Analytics.tracker.track(.paywallShown(placement: placement.rawValue))
        return SubscriptionPaywallEvents(
            onPurchased: { status in
                Analytics.tracker.track(.purchaseCompleted(placement: placement.rawValue, isPremium: status.isPremium))
                Analytics.tracker.setUserProperties(["is_premium": status.isPremium])
                events.onPurchased(status)
            },
            onRestored: { status in
                Analytics.tracker.setUserProperties(["is_premium": status.isPremium])
                events.onRestored(status)
            },
            onCancelled: {
                Analytics.tracker.track(.paywallClosed(placement: placement.rawValue))
                events.onCancelled()
            },
            onClosed: {
                Analytics.tracker.track(.paywallClosed(placement: placement.rawValue))
                events.onClosed()
            },
            onError: { error in
                Analytics.tracker.track(.purchaseFailed(placement: placement.rawValue))
                events.onError(error)
            },
            onCustomAction: events.onCustomAction
        )
    }
}
