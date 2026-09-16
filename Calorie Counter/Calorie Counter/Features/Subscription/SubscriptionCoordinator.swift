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
        Analytics.tracker.track(.paywallShown(placement: placement.rawValue))
        let tracked = SubscriptionPaywallEvents(
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
        Task { @MainActor in
            do {
                let paywall = try await factory.makePaywallViewController(
                    placement: placement,
                    events: tracked
                )
                paywall.modalPresentationStyle = .fullScreen
                presenter.present(paywall, animated: animated)
            } catch {
                events.onError(error)
            }
        }
    }

    func makePaywallViewController(
        placement: SubscriptionPlacement,
        events: SubscriptionPaywallEvents = SubscriptionPaywallEvents()
    ) async throws -> UIViewController {
        try await factory.makePaywallViewController(placement: placement, events: events)
    }
}
