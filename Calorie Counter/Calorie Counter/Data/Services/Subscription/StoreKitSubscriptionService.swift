import Foundation
import StoreKit

protocol SubscriptionStatusProviding: AnyObject {
    func currentStatus() -> SubscriptionStatus
    func refresh() async -> SubscriptionStatus
    func availableProducts() async throws -> [SubscriptionProduct]
    func purchase(productID: String) async throws -> SubscriptionStatus
    func restorePurchases() async throws -> SubscriptionStatus
}

final class StoreKitSubscriptionService: SubscriptionStatusProviding {
    static let productIDs = [
        "avo.premium.monthly",
        "avo.premium.yearly",
    ]

    private let defaults: UserDefaults
    private let cacheKey = "avo.subscription.status"
    private var updatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    _ = await self?.refresh()
                }
            }
        }
    }

    func currentStatus() -> SubscriptionStatus {
        guard let data = defaults.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(Persisted.self, from: data)
        else {
            return .free
        }
        return decoded.status
    }

    func refresh() async -> SubscriptionStatus {
        var status = SubscriptionStatus.free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.productIDs.contains(transaction.productID) {
                status = SubscriptionStatus(
                    tier: transaction.offerType == .introductory ? .trial : .premium,
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    isEligibleForTrial: false
                )
                break
            }
        }
        persist(status)
        return status
    }

    func availableProducts() async throws -> [SubscriptionProduct] {
        let products = try await Product.products(for: Self.productIDs)
        return products
            .sorted { lhs, rhs in
                (lhs.subscription?.subscriptionPeriod.value ?? 0) < (rhs.subscription?.subscriptionPeriod.value ?? 0)
            }
            .map { product in
                SubscriptionProduct(
                    id: product.id,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    periodLabel: periodLabel(for: product)
                )
            }
    }

    func purchase(productID: String) async throws -> SubscriptionStatus {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw SubscriptionError.productUnavailable
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw SubscriptionError.unverified
            }
            await transaction.finish()
            return await refresh()
        case .userCancelled:
            throw SubscriptionError.cancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.failed
        }
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        try await AppStore.sync()
        return await refresh()
    }

    private func persist(_ status: SubscriptionStatus) {
        if let data = try? JSONEncoder().encode(Persisted(status: status)) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    private func periodLabel(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return ""
        }
        switch period.unit {
        case .day:
            return period.value == 1 ? L10n.tr("subscription.daily") : L10n.format("subscription.days", period.value)
        case .week:
            return period.value == 1 ? L10n.tr("subscription.weekly") : L10n.format("subscription.weeks", period.value)
        case .month:
            return period.value == 1 ? L10n.tr("subscription.monthly") : L10n.format("subscription.months", period.value)
        case .year:
            return period.value == 1 ? L10n.tr("subscription.yearly") : L10n.format("subscription.years", period.value)
        @unknown default:
            return ""
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
