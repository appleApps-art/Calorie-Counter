import Foundation

struct AIAssistantAPIConfiguration {
    let baseURL: URL
    let apiKey: String?
    let defaultFoodCatalogURL: URL

    func foodImageURL(name: String) -> URL? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else { return nil }
        components.path = "/v1/food/image"
        components.queryItems = [URLQueryItem(name: "name", value: String(trimmed.prefix(200)))]
        if Self.isPreparedBroth(trimmed) {
            components.queryItems?.append(URLQueryItem(name: "v", value: "broth-2"))
        }
        return components.url
    }

    static func isPreparedBroth(_ name: String) -> Bool {
        let text = name.lowercased()
        let broth = text.range(of: #"(?:^|[^\p{L}])(?:broth|bouillon|stock|бульйон\p{L}*|бульон\p{L}*)(?:[^\p{L}]|$)"#, options: .regularExpression) != nil
        let concentrate = text.range(of: #"cube|powder|concentrat|granul|instant|dehydrat|кубик|порош|концентрат|сух|сушен"#, options: .regularExpression) != nil
        return broth && !concentrate
    }

    static let production = AIAssistantAPIConfiguration(
        baseURL: URL(string: "https://assistant.chatte.workers.dev")!,
        apiKey: nil,
        defaultFoodCatalogURL: URL(string: "https://pub-33979f5afd5f4ecda68c61a6f014e2b5.r2.dev/food-search-catalog.json")!
    )
}
