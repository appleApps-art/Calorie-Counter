import Adapty
import AdaptyLogger
import AdaptyUI
import Foundation

enum AdaptySDKConfiguration {
    static let publicSDKKey = "public_live_LjBhlAr1.Fx8DsRqWZ9gDkGn25zKI"
    static let premiumAccessLevelId = "premium"
}

enum AdaptyBootstrap {
    private static var task: Task<Void, Error>?

    static func start(amplitudeDeviceId: String? = nil, amplitudeUserId: String? = nil) {
        if task != nil { return }
        task = Task { @MainActor in
            var builder = AdaptyConfiguration.builder(withAPIKey: AdaptySDKConfiguration.publicSDKKey)
            #if DEBUG
            builder = builder.with(logLevel: .verbose)
            #endif
            try await Adapty.activate(with: builder.build())
            try await AdaptyUI.activate()
            if let amplitudeDeviceId {
                try await Adapty.setIntegrationIdentifier(.amplitudeDeviceId(amplitudeDeviceId))
            }
            if let amplitudeUserId {
                try await Adapty.setIntegrationIdentifier(.amplitudeUserId(amplitudeUserId))
            }
        }
    }

    static func waitUntilReady() async throws {
        if task == nil {
            start()
        }
        guard let task else {
            throw SubscriptionError.failed
        }
        try await task.value
    }
}
