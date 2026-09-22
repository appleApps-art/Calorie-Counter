import Adapty
import Foundation

protocol SubscriptionStatusProviding: AnyObject {
    func currentStatus() -> SubscriptionStatus
    func refresh() async -> SubscriptionStatus
    func availableProducts() async throws -> [SubscriptionProduct]
    func loadPlacement(_ placement: SubscriptionPlacement) async throws -> SubscriptionOffer
    func purchase(productID: String) async throws -> SubscriptionStatus
    func purchase(productID: String, placement: SubscriptionPlacement) async throws -> SubscriptionStatus
    func restorePurchases() async throws -> SubscriptionStatus
    func logShowPlacement(_ placement: SubscriptionPlacement) async
}

final class AdaptySubscriptionService: SubscriptionStatusProviding {
    #if DEBUG
    private static let debugPremiumProductID = "debug.premium"

    private static var forcePremium: Bool {
        if QALaunchConfiguration.isActive, let override = QALaunchConfiguration.premium {
            return override
        }
        return !QALaunchConfiguration.usesRealSubscription
    }
    #endif

    private let defaults: UserDefaults
    private let cacheKey = "bity.subscription.status"
    private let profileListener: AdaptyProfileListener
    private var flows: [SubscriptionPlacement: AdaptyFlow] = [:]
    private var productsByPlacement: [SubscriptionPlacement: [AdaptyPaywallProduct]] = [:]
    private var lastLoadedPlacement: SubscriptionPlacement?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let listener = AdaptyProfileListener()
        profileListener = listener
        listener.onProfile = { [weak self] profile in
            Task { @MainActor [weak self] in
                self?.apply(profile)
            }
        }
        Adapty.delegate = listener
        Task { [weak self] in
            _ = await self?.refresh()
        }
    }

    func currentStatus() -> SubscriptionStatus {
        if let forced = forcedPremiumStatus {
            return forced
        }
        guard let data = defaults.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(Persisted.self, from: data)
        else {
            return .free
        }
        #if DEBUG
        // What the debug override saved is not a purchase.
        if decoded.status.productID == Self.debugPremiumProductID { return .free }
        #endif
        return decoded.status
    }

    func refresh() async -> SubscriptionStatus {
        if let forced = forcedPremiumStatus {
            persist(forced)
            return forced
        }
        do {
            try await AdaptyBootstrap.waitUntilReady()
            let profile = try await Adapty.getProfile()
            apply(profile)
            return currentStatus()
        } catch {
            return currentStatus()
        }
    }

    func availableProducts() async throws -> [SubscriptionProduct] {
        do {
            return try await loadPlacement(.settings).products
        } catch {
            return try await loadPlacement(.main).products
        }
    }

    func loadPlacement(_ placement: SubscriptionPlacement) async throws -> SubscriptionOffer {
        do {
            try await AdaptyBootstrap.waitUntilReady()
            let flow = try await Adapty.getFlow(placementId: placement.rawValue)
            let products: [AdaptyPaywallProduct]
            do {
                products = try await Adapty.getPaywallProducts(flow: flow)
            } catch {
                throw mapError(error)
            }
            cache(products: products, placement: placement, flow: flow)
            return SubscriptionOffer(
                placement: placement,
                products: products.map(makeDomainProduct),
                hasPaywallBuilder: flow.hasViewConfiguration
            )
        } catch let error as SubscriptionError {
            throw error
        } catch {
            throw SubscriptionError.placementFailed
        }
    }

    func purchase(productID: String) async throws -> SubscriptionStatus {
        try await purchase(productID: productID, placement: lastLoadedPlacement ?? .settings)
    }

    func purchase(productID: String, placement: SubscriptionPlacement) async throws -> SubscriptionStatus {
        try await AdaptyBootstrap.waitUntilReady()
        if cachedProduct(id: productID, placement: placement) == nil {
            _ = try await loadPlacement(placement)
        }
        guard let product = cachedProduct(id: productID, placement: placement) else {
            throw SubscriptionError.productUnavailable
        }
        do {
            let result = try await Adapty.makePurchase(product: product)
            switch result {
            case .userCancelled:
                throw SubscriptionError.cancelled
            case .pending:
                throw SubscriptionError.pending
            case .success(let profile, _):
                apply(profile)
                return currentStatus()
            }
        } catch let error as SubscriptionError {
            throw error
        } catch {
            throw mapError(error)
        }
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        do {
            try await AdaptyBootstrap.waitUntilReady()
            let profile = try await Adapty.restorePurchases()
            apply(profile)
            return currentStatus()
        } catch let error as SubscriptionError {
            throw error
        } catch {
            throw mapError(error)
        }
    }

    func logShowPlacement(_ placement: SubscriptionPlacement) async {
        do {
            try await AdaptyBootstrap.waitUntilReady()
            if flows[placement] == nil {
                _ = try await loadPlacement(placement)
            }
            guard let flow = flows[placement] else { return }
            try await Adapty.logShowFlow(flow)
        } catch {
        }
    }

    func cache(products: [AdaptyPaywallProduct], placement: SubscriptionPlacement, flow: AdaptyFlow? = nil) {
        productsByPlacement[placement] = products
        if let flow {
            flows[placement] = flow
        }
        lastLoadedPlacement = placement
    }

    func apply(_ profile: AdaptyProfile) {
        if let forced = forcedPremiumStatus {
            persist(forced)
            return
        }
        persist(status(from: profile))
    }

    private var forcedPremiumStatus: SubscriptionStatus? {
        #if DEBUG
        if QALaunchConfiguration.isActive, QALaunchConfiguration.premium == false {
            return .free
        }
        guard Self.forcePremium else { return nil }
        return SubscriptionStatus(
            tier: .premium,
            productID: Self.debugPremiumProductID,
            expirationDate: nil,
            isEligibleForTrial: false
        )
        #else
        return nil
        #endif
    }

    private func cachedProduct(id: String, placement: SubscriptionPlacement) -> AdaptyPaywallProduct? {
        if let match = productsByPlacement[placement]?.first(where: { $0.vendorProductId == id }) {
            return match
        }
        for products in productsByPlacement.values {
            if let match = products.first(where: { $0.vendorProductId == id }) {
                return match
            }
        }
        return nil
    }

    private func status(from profile: AdaptyProfile) -> SubscriptionStatus {
        guard let level = profile.accessLevels[AdaptySDKConfiguration.premiumAccessLevelId], level.isActive else {
            return .free
        }
        let isTrial = level.activeIntroductoryOfferType == "free_trial"
        return SubscriptionStatus(
            tier: isTrial ? .trial : .premium,
            productID: level.vendorProductId,
            expirationDate: level.expiresAt,
            isEligibleForTrial: false
        )
    }

    private func persist(_ status: SubscriptionStatus) {
        if let data = try? JSONEncoder().encode(Persisted(status: status)) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    private func makeDomainProduct(_ product: AdaptyPaywallProduct) -> SubscriptionProduct {
        SubscriptionProduct(
            id: product.vendorProductId,
            displayName: product.localizedTitle,
            displayPrice: product.localizedPrice ?? "",
            periodLabel: periodLabel(for: product),
            price: product.price,
            priceLocale: product.priceLocale,
            period: product.subscriptionPeriod.flatMap(Self.domainPeriod),
            freeTrialDays: Self.freeTrialDays(product.subscriptionOffer)
        )
    }

    private static func domainPeriod(_ period: AdaptySubscriptionPeriod) -> SubscriptionPeriod? {
        let unit: SubscriptionPeriod.Unit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        case .unknown: return nil
        }
        return SubscriptionPeriod(unit: unit, count: period.numberOfUnits)
    }

    /// Adapty only attaches the introductory offer the user is still eligible for.
    private static func freeTrialDays(_ offer: AdaptySubscriptionOffer?) -> Int? {
        guard let offer, offer.paymentMode == .freeTrial,
              let period = domainPeriod(offer.subscriptionPeriod)
        else { return nil }
        return period.days * max(offer.numberOfPeriods, 1)
    }

    private func periodLabel(for product: AdaptyPaywallProduct) -> String {
        if let localized = product.localizedSubscriptionPeriod, !localized.isEmpty {
            return localized
        }
        guard let period = product.subscriptionPeriod else {
            return ""
        }
        switch period.unit {
        case .day:
            return period.numberOfUnits == 1
                ? L10n.tr("subscription.daily")
                : L10n.format("subscription.days", period.numberOfUnits)
        case .week:
            return period.numberOfUnits == 1
                ? L10n.tr("subscription.weekly")
                : L10n.format("subscription.weeks", period.numberOfUnits)
        case .month:
            return period.numberOfUnits == 1
                ? L10n.tr("subscription.monthly")
                : L10n.format("subscription.months", period.numberOfUnits)
        case .year:
            return period.numberOfUnits == 1
                ? L10n.tr("subscription.yearly")
                : L10n.format("subscription.years", period.numberOfUnits)
        case .unknown:
            return ""
        }
    }

    private func mapError(_ error: Error) -> SubscriptionError {
        if let subscription = error as? SubscriptionError {
            return subscription
        }
        guard let adapty = error as? AdaptyError else {
            return .failed
        }
        switch adapty.adaptyErrorCode {
        case .paymentCancelled:
            return .cancelled
        case .paymentPendingError:
            return .pending
        case .noProductIDsFound, .storeProductNotAvailable, .productRequestFailed:
            return .productUnavailable
        default:
            return .failed
        }
    }

    private struct Persisted: Codable {
        var tier: SubscriptionTier
        var productID: String?
        var expirationDate: Date?
        var isEligibleForTrial: Bool

        var status: SubscriptionStatus {
            SubscriptionStatus(
                tier: tier,
                productID: productID,
                expirationDate: expirationDate,
                isEligibleForTrial: isEligibleForTrial
            )
        }

        init(status: SubscriptionStatus) {
            tier = status.tier
            productID = status.productID
            expirationDate = status.expirationDate
            isEligibleForTrial = status.isEligibleForTrial
        }
    }
}

private final class AdaptyProfileListener: AdaptyDelegate, @unchecked Sendable {
    var onProfile: (@Sendable (AdaptyProfile) -> Void)?

    func didLoadLatestProfile(_ profile: AdaptyProfile) {
        onProfile?(profile)
    }
}
