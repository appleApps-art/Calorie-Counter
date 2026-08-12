import Foundation

struct AIAssistantAPIConfiguration {
    let baseURL: URL
    let apiKey: String?

    static let production = AIAssistantAPIConfiguration(
        baseURL: URL(string: "https://assistant.chatte.workers.dev")!,
        apiKey: nil
    )
}
