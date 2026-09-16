import Adapty
import AdaptyUI
import UIKit

protocol SubscriptionPaywallPresenting: AnyObject {
    func makePaywallViewController(
        placement: SubscriptionPlacement,
        events: SubscriptionPaywallEvents
    ) async throws -> UIViewController
}

final class AdaptyPaywallFactory: SubscriptionPaywallPresenting {
    private weak var service: AdaptySubscriptionService?
    private var proxies: [ObjectIdentifier: AdaptyPaywallEventsProxy] = [:]

    init(service: AdaptySubscriptionService) {
        self.service = service
    }

    func makePaywallViewController(
        placement: SubscriptionPlacement,
        events: SubscriptionPaywallEvents
    ) async throws -> UIViewController {
        try await AdaptyBootstrap.waitUntilReady()
        let flow: AdaptyFlow
        do {
            flow = try await Adapty.getFlow(placementId: placement.rawValue)
        } catch {
            throw SubscriptionError.placementFailed
        }
        guard flow.hasViewConfiguration else {
            throw SubscriptionError.paywallUnavailable
        }
        let products = (try? await Adapty.getPaywallProducts(flow: flow)) ?? []
        service?.cache(products: products, placement: placement, flow: flow)
        let configuration: AdaptyUI.FlowConfiguration
        do {
            configuration = try await AdaptyUI.getFlowConfiguration(forFlow: flow, products: products)
        } catch {
            throw SubscriptionError.paywallUnavailable
        }
        let proxy = AdaptyPaywallEventsProxy(service: service, events: events)
        let controller: AdaptyFlowController
        do {
            controller = try AdaptyUI.flowController(with: configuration, delegate: proxy)
        } catch {
            throw SubscriptionError.paywallUnavailable
        }
        proxy.onDisappear = { [weak self] viewController in
            self?.proxies[ObjectIdentifier(viewController)] = nil
        }
        proxies[ObjectIdentifier(controller)] = proxy
        try? await Adapty.logShowFlow(flow)
        return controller
    }
}

@MainActor
private final class AdaptyPaywallEventsProxy: AdaptyFlowControllerDelegate {
    private weak var service: AdaptySubscriptionService?
    private let events: SubscriptionPaywallEvents
    var onDisappear: ((UIViewController) -> Void)?

    init(service: AdaptySubscriptionService?, events: SubscriptionPaywallEvents) {
        self.service = service
        self.events = events
    }

    func flowControllerDidDisappear(_ controller: AdaptyFlowController) {
        onDisappear?(controller)
    }

    func flowController(
        _ controller: AdaptyFlowController,
        didPerform action: AdaptyUI.Action
    ) {
        switch action {
        case .close:
            events.onClosed()
            controller.dismiss(animated: true)
        case let .openURL(url, _):
            UIApplication.shared.open(url)
        case let .custom(id):
            events.onCustomAction(id)
        }
    }

    func flowController(
        _ controller: AdaptyFlowController,
        didFinishPurchase _: AdaptyPaywallProduct,
        purchaseResult: AdaptyPurchaseResult
    ) {
        switch purchaseResult {
        case .userCancelled:
            events.onCancelled()
        case .pending:
            events.onError(SubscriptionError.pending)
        case .success(let profile, _):
            service?.apply(profile)
            events.onPurchased(service?.currentStatus() ?? .free)
            controller.dismiss(animated: true)
        }
    }

    func flowController(
        _ controller: AdaptyFlowController,
        didFailPurchase _: AdaptyPaywallProduct,
        error: AdaptyError
    ) {
        if error.adaptyErrorCode == .paymentCancelled {
            events.onCancelled()
            return
        }
        events.onError(error)
    }

    func flowController(
        _ controller: AdaptyFlowController,
        didFinishRestoreWith profile: AdaptyProfile
    ) {
        service?.apply(profile)
        let status = service?.currentStatus() ?? .free
        events.onRestored(status)
        if status.isPremium {
            controller.dismiss(animated: true)
        }
    }

    func flowController(
        _ controller: AdaptyFlowController,
        didFailRestoreWith error: AdaptyError
    ) {
        events.onError(error)
    }
}
