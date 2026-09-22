import UIKit

final class BadgeUnlockPresenter {
    private weak var host: UIViewController?
    private var queue: [BadgeProgress] = []
    private var isPresenting = false
    private var presentingBadge: RewardBadge?
    private var retryWorkItem: DispatchWorkItem?
    private var presentWatchWorkItem: DispatchWorkItem?
    private var becameActiveObserver: NSObjectProtocol?
    private let inboxStore: NotificationInboxStoring
    private let markBadgeSeen: (RewardBadge) -> Void
    private let isBadgeSeen: (RewardBadge) -> Bool

    init(
        inboxStore: NotificationInboxStoring,
        markBadgeSeen: @escaping (RewardBadge) -> Void,
        isBadgeSeen: @escaping (RewardBadge) -> Bool
    ) {
        self.inboxStore = inboxStore
        self.markBadgeSeen = markBadgeSeen
        self.isBadgeSeen = isBadgeSeen
    }

    func attach(host: UIViewController) {
        self.host = host
        if becameActiveObserver == nil {
            becameActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.presentNextIfNeeded()
            }
        }
    }

    func present(_ badges: [BadgeProgress]) {
        let queued = Set(queue.map(\.badge))
        for progress in badges where progress.isComplete && !queued.contains(progress.badge) {
            guard progress.badge != presentingBadge else { continue }
            guard !isBadgeSeen(progress.badge) else { continue }
            queue.append(progress)
            inboxStore.upsert(
                InboxNotification(
                    id: "badge.\(progress.badge.rawValue)",
                    title: progress.badge.title,
                    body: progress.badge.celebrationTitle,
                    date: Date(),
                    symbolName: nil,
                    imageName: progress.badge.imageName
                )
            )
        }
        presentNextIfNeeded()
    }

    func presentPendingIfNeeded() {
        presentNextIfNeeded()
    }

    private func presentNextIfNeeded() {
        retryWorkItem?.cancel()
        guard !isPresenting else { return }
        queue.removeAll { isBadgeSeen($0.badge) }
        guard let next = queue.first else { return }
        guard let presenter = stablePresenter() else {
            scheduleRetry()
            return
        }
        queue.removeFirst()
        isPresenting = true
        presentingBadge = next.badge
        Analytics.tracker.track(.badgeCelebrationShown(badge: next.badge.rawValue))
        Haptics.success()
        var didConfirmSeen = false
        let detail = RewardDetailViewController(progress: next, playsCelebration: true)
        detail.modalPresentationStyle = .overFullScreen
        detail.modalTransitionStyle = .coverVertical
        detail.onViewed = { [weak self] in
            didConfirmSeen = true
            self?.markBadgeSeen(next.badge)
        }
        detail.onDismissed = { [weak self] in
            guard let self else { return }
            self.presentWatchWorkItem?.cancel()
            self.isPresenting = false
            self.presentingBadge = nil
            if !didConfirmSeen, !self.isBadgeSeen(next.badge),
               self.queue.contains(where: { $0.badge == next.badge }) == false {
                self.queue.insert(next, at: 0)
            }
            self.presentNextIfNeeded()
        }
        presenter.present(detail, animated: true)
        watchPresentation(detail, progress: next)
    }

    private func watchPresentation(_ detail: RewardDetailViewController, progress: BadgeProgress) {
        presentWatchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self, weak detail] in
            guard let self, let detail else { return }
            guard self.isPresenting else { return }
            guard detail.presentingViewController == nil, detail.view.window == nil else { return }
            self.isPresenting = false
            self.presentingBadge = nil
            if !self.isBadgeSeen(progress.badge),
               self.queue.contains(where: { $0.badge == progress.badge }) == false {
                self.queue.insert(progress, at: 0)
            }
            self.scheduleRetry()
        }
        presentWatchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func stablePresenter() -> UIViewController? {
        guard let host, host.view.window != nil, !host.isBeingDismissed, !host.isBeingPresented else {
            return nil
        }
        if host.transitionCoordinator != nil {
            return nil
        }
        if let presented = host.presentedViewController {
            if isTransitioning(presented) {
                return nil
            }
            var current = presented
            while let next = current.presentedViewController {
                if isTransitioning(next) {
                    return nil
                }
                current = next
            }
            // A celebration waits until the paywall is closed instead of landing on top of it.
            if current is RewardDetailViewController || current is PaywallViewController {
                return nil
            }
            if let navigation = current as? UINavigationController {
                if navigation.transitionCoordinator != nil {
                    return nil
                }
                if navigation.visibleViewController is RewardDetailViewController {
                    return nil
                }
                return navigation
            }
            return current
        }
        if let tab = host as? UITabBarController, isTransitioning(tab.selectedViewController) {
            return nil
        }
        return host
    }

    private func isTransitioning(_ viewController: UIViewController?) -> Bool {
        guard let viewController else { return false }
        if viewController.isBeingPresented || viewController.isBeingDismissed {
            return true
        }
        if viewController.transitionCoordinator != nil {
            return true
        }
        if let navigation = viewController as? UINavigationController {
            return navigation.transitionCoordinator != nil
                || navigation.visibleViewController?.isMovingFromParent == true
                || navigation.visibleViewController?.isMovingToParent == true
        }
        return viewController.isMovingFromParent || viewController.isMovingToParent
    }

    private func scheduleRetry() {
        retryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.presentNextIfNeeded()
        }
        retryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }
}
