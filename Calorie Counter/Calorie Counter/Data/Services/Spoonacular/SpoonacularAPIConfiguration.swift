import Foundation

struct SpoonacularAPIConfiguration {
    let baseURL: URL
    let apiKey: String?

    static let production = SpoonacularAPIConfiguration(
        baseURL: URL(string: "https://assistant.chatte.workers.dev")!,
        apiKey: nil
    )
}
