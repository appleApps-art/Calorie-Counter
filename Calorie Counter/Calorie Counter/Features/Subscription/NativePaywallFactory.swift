import UIKit

/// Builds Bity's own paywall screens; Adapty stays behind them for prices and purchases.
final class NativePaywallFactory: SubscriptionPaywallPresenting {
    private let subscription: RefreshSubscriptionStatusUseCase
    private let trialReminder: TrialReminderScheduling

    init(subscription: RefreshSubscriptionStatusUseCase, trialReminder: TrialReminderScheduling) {
        self.subscription = subscription
        self.trialReminder = trialReminder
    }

    func makePaywallViewController(
        placement: SubscriptionPlacement,
        events: SubscriptionPaywallEvents
    ) async throws -> UIViewController {
        makePaywall(placement: placement, events: events)
    }

    /// Available at once, so onboarding can swap to the paywall in the same frame.
    func makePaywall(placement: SubscriptionPlacement, events: SubscriptionPaywallEvents) -> PaywallViewController {
        PaywallViewController(
            viewModel: PaywallViewModel(
                placement: placement,
                subscription: subscription,
                trialReminder: trialReminder,
                events: events
            )
        )
    }
}
