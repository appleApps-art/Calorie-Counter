import Foundation

final class PaywallViewModel {
    let style: PaywallStyle
    let placement: SubscriptionPlacement
    let titleText = Observable("")
    let plans = Observable<[PaywallPlanDisplay]>([])
    let selectedPlanID = Observable<String?>(nil)
    let ctaTitle = Observable("")
    let timeline = Observable<[PaywallTimelineStep]>([])
    let isBusy = Observable(false)

    /// Called once when the paywall is done; the view closes itself, then reports what happened.
    var onFinish: ((@escaping () -> Void) -> Void)?
    var onAlert: ((String) -> Void)?
    var onOpenURL: ((URL) -> Void)?

    private let subscription: RefreshSubscriptionStatusUseCase
    private let trialReminder: TrialReminderScheduling?
    private let events: SubscriptionPaywallEvents
    private var products: [SubscriptionProduct] = []
    private var didFinish = false
    private var loadTask: Task<Void, Never>?

    init(
        placement: SubscriptionPlacement,
        subscription: RefreshSubscriptionStatusUseCase,
        trialReminder: TrialReminderScheduling?,
        events: SubscriptionPaywallEvents
    ) {
        self.placement = placement
        self.style = PaywallStyle(placement: placement)
        self.subscription = subscription
        self.trialReminder = trialReminder
        self.events = events
        apply(SubscriptionProduct.placeholders)
    }

    deinit {
        loadTask?.cancel()
    }

    /// The design's plans show at once; real App Store prices replace them when they arrive.
    func viewDidLoad() {
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if let offer = try? await subscription.loadPlacement(placement),
               !offer.products.isEmpty, !Task.isCancelled {
                apply(offer.products)
            }
            await subscription.logShowPlacement(placement)
        }
    }

    func select(planID: String) {
        guard plans.value.contains(where: { $0.id == planID }) else { return }
        selectedPlanID.value = planID
        ctaTitle.value = PaywallPlanFormatter.ctaTitle(for: selectedPlan)
    }

    func purchaseTapped() {
        guard !isBusy.value, let product = products.first(where: { $0.id == selectedPlanID.value }) else { return }
        guard !product.isPlaceholder else {
            onAlert?(L10n.tr("subscription.unavailable"))
            return
        }
        isBusy.value = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let status = try await subscription.purchase(productID: product.id, placement: placement)
                isBusy.value = false
                guard status.isPremium else { return }
                if let days = product.freeTrialDays {
                    trialReminder?.scheduleTrialEndReminder(trialDays: days, startedAt: Date())
                }
                finish { [events] in events.onPurchased(status) }
            } catch SubscriptionError.cancelled {
                isBusy.value = false
                events.onCancelled()
            } catch {
                isBusy.value = false
                onAlert?(Self.message(for: error))
            }
        }
    }

    func restoreTapped() {
        guard !isBusy.value else { return }
        isBusy.value = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let status = try await subscription.restore()
                isBusy.value = false
                guard status.isPremium else {
                    onAlert?(L10n.tr("settings.noSubscription"))
                    return
                }
                finish { [events] in events.onRestored(status) }
            } catch {
                isBusy.value = false
                onAlert?(Self.message(for: error))
            }
        }
    }

    func closeTapped() {
        finish { [events] in events.onClosed() }
    }

    func termsTapped() {
        onOpenURL?(LegalLinks.termsOfUse)
    }

    func privacyTapped() {
        guard let url = LegalLinks.privacyPolicy else { return }
        onOpenURL?(url)
    }

    private var selectedPlan: PaywallPlanDisplay? {
        plans.value.first { $0.id == selectedPlanID.value }
    }

    private func apply(_ products: [SubscriptionProduct]) {
        self.products = products
        let displays = PaywallPlanFormatter.displays(for: products)
        plans.value = displays
        let trialProduct = products.first { ($0.freeTrialDays ?? 0) > 0 }
        let keep = displays.first { $0.id == selectedPlanID.value }?.id
        let preferred = displays.first { $0.id == trialProduct?.id }?.id ?? displays.first?.id
        if let id = keep ?? preferred {
            select(planID: id)
        }
        timeline.value = PaywallPlanFormatter.timeline(for: trialProduct)
        titleText.value = style == .onboarding
            ? PaywallPlanFormatter.onboardingTitle(trialDays: trialProduct?.freeTrialDays)
            : L10n.tr("paywall.feature.title")
    }

    private func finish(report: @escaping () -> Void) {
        guard !didFinish else { return }
        didFinish = true
        loadTask?.cancel()
        if let onFinish {
            onFinish(report)
        } else {
            report()
        }
    }

    private static func message(for error: Error) -> String {
        if error.isNoConnection { return L10n.tr("offline.message") }
        return (error as? LocalizedError)?.errorDescription ?? L10n.tr("subscription.failed")
    }
}

/// Links every subscription screen must offer.
enum LegalLinks {
    /// Apple's standard licence agreement, used until Bity publishes its own terms.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Bity's privacy policy page. App Review expects a working link here.
    static let privacyPolicy: URL? = nil
}
