import AmplitudeSwift
import UserNotifications
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var analytics: AmplitudeAnalyticsService?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        NetworkMonitor.shared.start()
        UNUserNotificationCenter.current().delegate = NotificationAnalyticsDelegate.shared
        let analytics = AmplitudeAnalyticsService()
        self.analytics = analytics
        Analytics.hub.base = analytics
        AdaptyBootstrap.start(
            amplitudeDeviceId: analytics.deviceID,
            amplitudeUserId: analytics.userID
        )
        Haptics.install()
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
        UITableView.appearance().showsVerticalScrollIndicator = false
        UITableView.appearance().showsHorizontalScrollIndicator = false
        UITextView.appearance().showsVerticalScrollIndicator = false
        UITextView.appearance().showsHorizontalScrollIndicator = false
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
