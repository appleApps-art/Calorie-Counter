import Foundation

@MainActor
protocol RecipeSectionsFetching {
    func fetchSections(locale: String) async throws -> [RecipeBrowseSection]
    func fetchSectionPage(id: RecipeBrowseSectionKind, locale: String, offset: Int, limit: Int) async throws -> RecipeSectionPage
}

struct RecipeSectionsResponse: Decodable {
    let sections: [RecipeSectionsPayload]?
    let recipes: [AIFoodSearchItem]?
    let hasMore: Bool?
    let offset: Int?
    let error: String?
}

struct RecipeSectionsPayload: Decodable {
    let id: String?
    let recipes: [AIFoodSearchItem]?
}

final class RecipeSectionsService: RecipeSectionsFetching {
    private let configuration: AIAssistantAPIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        configuration: AIAssistantAPIConfiguration = .production,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.decoder = JSONDecoder()
    }

    func fetchSections(locale: String) async throws -> [RecipeBrowseSection] {
        let data = try await get(
            path: "/v1/recipes/sections",
            queryItems: [
                URLQueryItem(name: "locale", value: locale),
                URLQueryItem(name: "rev", value: "26"),
            ],
            timeoutInterval: 90
        )
        return Self.decodeSections(from: data, decoder: decoder)
    }

    func fetchSectionPage(
        id: RecipeBrowseSectionKind,
        locale: String,
        offset: Int,
        limit: Int
    ) async throws -> RecipeSectionPage {
        let data = try await get(
            path: "/v1/recipes/sections/\(id.rawValue)",
            queryItems: [
                URLQueryItem(name: "locale", value: locale),
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "rev", value: "26"),
            ],
            timeoutInterval: 60
        )
        return Self.decodePage(from: data, offset: offset, decoder: decoder)
    }

    private func get(path: String, queryItems: [URLQueryItem], timeoutInterval: TimeInterval) async throws -> Data {
        guard let base = URL(string: path, relativeTo: configuration.baseURL)?.absoluteURL else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw FoodPhotoAnalysisError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeoutInterval)
        request.httpMethod = "GET"
        request.setValue("BityiOS/1.0", forHTTPHeaderField: "User-Agent")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FoodPhotoAnalysisError.transport(message: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        if !(200...299).contains(http.statusCode) {
            let message = (try? decoder.decode(RecipeSectionsResponse.self, from: data))?.error
            throw FoodPhotoAnalysisError.analysisFailed(
                message: message ?? "HTTP \(http.statusCode)"
            )
        }
        return data
    }

    static func decodeSections(
        from data: Data,
        decoder: JSONDecoder = JSONDecoder()
    ) -> [RecipeBrowseSection] {
        guard let decoded = try? decoder.decode(RecipeSectionsResponse.self, from: data) else {
            return []
        }
        var seen = Set<RecipeBrowseSectionKind>()
        return (decoded.sections ?? []).compactMap { payload in
            guard let kind = RecipeBrowseSectionKind(rawValue: payload.id ?? ""),
                  RecipeBrowseSectionKind.catalogSections.contains(kind) else { return nil }
            guard seen.insert(kind).inserted else { return nil }
            let recipes = mapRecipes(payload.recipes)
            guard !recipes.isEmpty else {
                seen.remove(kind)
                return nil
            }
            return RecipeBrowseSection(id: kind, recipes: recipes)
        }
    }

    static func decodePage(
        from data: Data,
        offset: Int,
        decoder: JSONDecoder = JSONDecoder()
    ) -> RecipeSectionPage {
        guard let decoded = try? decoder.decode(RecipeSectionsResponse.self, from: data),
              decoded.error == nil, decoded.recipes != nil else {
            return RecipeSectionPage(recipes: [], nextOffset: offset, hasMore: false, isRetryableFailure: true)
        }
        let recipes = mapRecipes(decoded.recipes)
        return RecipeSectionPage(
            recipes: recipes,
            nextOffset: offset + (decoded.recipes?.count ?? recipes.count),
            hasMore: decoded.hasMore ?? false
        )
    }

    private static func mapRecipes(_ items: [AIFoodSearchItem]?) -> [Recipe] {
        (items ?? [])
            .compactMap { AIFoodSearchService.mapRecipe($0) }
            .filter(\.hasPhoto)
            .filter { !$0.looksLikeListingPage }
    }
}
