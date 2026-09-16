import UIKit

protocol AppRatingPrompting: AnyObject {
    func promptAfterCompletedAction(source: String)
}

final class AppRatingPromptController: AppRatingPrompting {
    private weak var host: UIViewController?
    private var pendingSource: String?
    private var isPresenting = false
    private var retryWorkItem: DispatchWorkItem?
    private let settingsStore: AppSettingsStoring
    private let analytics: AnalyticsTracking

    init(settingsStore: AppSettingsStoring, analytics: AnalyticsTracking) {
        self.settingsStore = settingsStore
        self.analytics = analytics
    }

    func attach(host: UIViewController) {
        self.host = host
        presentIfNeeded()
    }

    func promptAfterCompletedAction(source: String) {
        if Thread.isMainThread {
            enqueue(source: source)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.enqueue(source: source)
            }
        }
    }

    func presentIfNeeded() {
        retryWorkItem?.cancel()
        guard !settingsStore.settings.hasSeenAppRating, !isPresenting, pendingSource != nil else { return }
        guard let presenter = stablePresenter() else {
            scheduleRetry()
            return
        }
        guard let source = pendingSource else { return }
        pendingSource = nil
        var settings = settingsStore.settings
        settings.hasSeenAppRating = true
        settingsStore.settings = settings
        isPresenting = true
        analytics.track(.appRatingShown(source: source))
        analytics.setUserProperties(["app_rating_shown": true])
        Haptics.medium()
        let rating = AppRatingViewController()
        rating.onFinished = { [weak self, weak rating] in
            rating?.dismiss(animated: true) {
                self?.isPresenting = false
            }
        }
        presenter.present(rating, animated: true)
    }

    private func enqueue(source: String) {
        guard !settingsStore.settings.hasSeenAppRating else { return }
        if pendingSource == nil {
            pendingSource = source
        }
        schedulePresent()
    }

    private func stablePresenter() -> UIViewController? {
        guard let host, host.view.window != nil, !host.isBeingDismissed, !host.isBeingPresented else {
            return nil
        }
        if let presented = host.presentedViewController, !presented.isBeingDismissed {
            return nil
        }
        return host
    }

    private func schedulePresent() {
        retryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.presentIfNeeded()
        }
        retryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
    }

    private func scheduleRetry() {
        retryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.presentIfNeeded()
        }
        retryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}
