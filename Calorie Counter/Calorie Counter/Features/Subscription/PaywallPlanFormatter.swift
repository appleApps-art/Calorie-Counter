import Foundation

/// Which of the two designed paywalls to show.
enum PaywallStyle: Equatable {
    /// Right after onboarding: the waving mascot, a free-trial timeline.
    case onboarding
    /// Opening the app without Premium, or reaching a paid feature.
    case feature

    init(placement: SubscriptionPlacement) {
        self = placement == .onboarding ? .onboarding : .feature
    }
}

struct PaywallPlanDisplay: Equatable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String?
    let freeTrialDays: Int?
    let isPlaceholder: Bool
}

struct PaywallTimelineStep: Equatable {
    let symbol: String
    let title: String
    let detail: String
}

/// Paywall copy built from store products, so real prices, trials and savings replace the
/// design's sample numbers without touching the layout.
enum PaywallPlanFormatter {
    static func displays(for products: [SubscriptionProduct]) -> [PaywallPlanDisplay] {
        let savings = savingsPercent(products)
        return products.map { product in
            PaywallPlanDisplay(
                id: product.id,
                title: title(for: product),
                subtitle: subtitle(for: product, comparedWith: products),
                badge: savings[product.id].map { L10n.format("paywall.plan.save", $0) },
                freeTrialDays: trialDays(product),
                isPlaceholder: product.isPlaceholder
            )
        }
    }

    /// "7 Days Free, $49.99 / year" or "$9.99 / month".
    static func title(for product: SubscriptionProduct) -> String {
        let price = pricePerPeriod(product)
        guard let days = trialDays(product) else { return price }
        return L10n.format("paywall.plan.trialTitle", L10n.format("paywall.plan.trialDays", days), price)
    }

    /// A yearly plan shows its price per week next to a weekly plan and per month otherwise, so
    /// the two cards compare at a glance; shorter plans say how they are billed.
    static func subtitle(for product: SubscriptionProduct, comparedWith products: [SubscriptionProduct] = []) -> String {
        guard let period = product.period else { return L10n.tr("paywall.cancelAnytime") }
        switch (period.unit, period.count) {
        case (.year, _):
            guard let price = product.price else { return L10n.tr("paywall.plan.billedYearly") }
            let years = Decimal(max(period.count, 1))
            if products.contains(where: { $0.period?.unit == .week || $0.period?.unit == .day }) {
                let weekly = roundedDown(price / (52 * years))
                return L10n.format("paywall.plan.perWeek", formattedPrice(weekly, locale: product.priceLocale))
            }
            let monthly = roundedDown(price / (12 * years))
            return L10n.format("paywall.plan.perMonth", formattedPrice(monthly, locale: product.priceLocale))
        case (.month, 1):
            return L10n.tr("paywall.plan.billedMonthly")
        case (.week, 1):
            return L10n.tr("paywall.plan.billedWeekly")
        default:
            return L10n.tr("paywall.cancelAnytime")
        }
    }

    static func pricePerPeriod(_ product: SubscriptionProduct) -> String {
        let price = product.price.map { formattedPrice($0, locale: product.priceLocale) } ?? product.displayPrice
        guard let period = product.period else { return price }
        switch (period.unit, period.count) {
        case (.year, 1):
            return L10n.format("paywall.plan.perYear", price)
        case (.month, 1):
            return L10n.format("paywall.plan.perMonth", price)
        case (.week, 1):
            return L10n.format("paywall.plan.perWeek", price)
        default:
            return product.periodLabel.isEmpty ? price : L10n.format("paywall.plan.perPeriod", price, product.periodLabel)
        }
    }

    /// The cheapest plan per week gets "SAVE N%" against the most expensive one, rounded down so
    /// the badge never promises more than the prices give.
    static func savingsPercent(_ products: [SubscriptionProduct]) -> [String: Int] {
        let weekly: [(id: String, cost: Double)] = products.compactMap { product in
            guard let price = product.price, let period = product.period, period.weeks > 0 else { return nil }
            return (product.id, NSDecimalNumber(decimal: price).doubleValue / period.weeks)
        }
        guard weekly.count > 1,
              let highest = weekly.map(\.cost).max(), highest > 0,
              let best = weekly.min(by: { $0.cost < $1.cost })
        else { return [:] }
        let percent = Int(((1 - best.cost / highest) * 100).rounded(.down))
        return percent >= 5 ? [best.id: percent] : [:]
    }

    static func ctaTitle(for plan: PaywallPlanDisplay?) -> String {
        guard let days = plan?.freeTrialDays else { return L10n.tr("common.continue") }
        return days == 7 ? L10n.tr("paywall.cta.freeWeek") : L10n.tr("paywall.cta.freeTrial")
    }

    static func onboardingTitle(trialDays: Int?) -> String {
        guard let trialDays, trialDays > 0 else { return L10n.tr("paywall.onboarding.titleNoTrial") }
        return L10n.format("paywall.onboarding.title", trialDays)
    }

    /// Today nothing is charged, the reminder goes out the day before the trial ends, then the
    /// subscription starts.
    static func timeline(for product: SubscriptionProduct?) -> [PaywallTimelineStep] {
        guard let product, let days = trialDays(product) else { return [] }
        let zero = formattedPrice(0, locale: product.priceLocale)
        return [
            PaywallTimelineStep(
                symbol: "flag",
                title: L10n.tr("paywall.timeline.today"),
                detail: L10n.format("paywall.timeline.charged", zero)
            ),
            PaywallTimelineStep(
                symbol: "bell",
                title: L10n.format("paywall.timeline.day", max(1, days - 1)),
                detail: L10n.tr("paywall.timeline.reminder")
            ),
            PaywallTimelineStep(
                symbol: "creditcard",
                title: L10n.format("paywall.timeline.day", days),
                detail: L10n.tr("paywall.timeline.starts")
            )
        ]
    }

    static func formattedPrice(_ amount: Decimal, locale: Locale?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = (locale ?? .appFormatting).withLatinDigits()
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    private static func trialDays(_ product: SubscriptionProduct) -> Int? {
        guard let days = product.freeTrialDays, days > 0 else { return nil }
        return days
    }

    private static func roundedDown(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .down)
        return result
    }
}
