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
                onError: { _ in
                    let alert = UIAlertController(
                        title: nil,
                        message: L10n.tr("subscription.paywallUnavailable"),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
                    presenter.present(alert, animated: true)
                }
            )
        )
    }
}
