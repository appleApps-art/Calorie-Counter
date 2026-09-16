import Foundation

protocol AIFoodSearching {
    func searchFoods(query: String) async throws -> [FoodProduct]
    func classifyFoods(_ products: [FoodProduct]) async throws -> [FoodProduct]
    func matchingRecipe(title: String, candidates: [Recipe]) async throws -> Recipe?
    func searchRecipes(query: String) async throws -> [Recipe]
    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]]
    func fetchCatalogSection(id: String) async throws -> [FoodProduct]
    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage
    func enrichDetails(
        title: String,
        imageURL: URL?,
        source: String,
        kind: String
    ) async throws -> FoodProduct?
}

extension AIFoodSearching {
    func matchingRecipe(title: String, candidates: [Recipe]) async throws -> Recipe? { nil }

    func classifyFoods(_ products: [FoodProduct]) async throws -> [FoodProduct] {
        try products.map { product in
            guard let type = product.resolvedFoodType else { throw FoodPhotoAnalysisError.invalidResponse }
            var resolved = product
            resolved.foodType = type
            return resolved
        }
    }
}

private struct AIFoodClassificationRequest: Encodable {
    struct Item: Encodable {
        let source: String
        let kind: String
        let externalId: String
        let title: String
        let brand: String?
        let ingredients: [String]
        let steps: [String]
    }
    let items: [Item]
    let locale: String
}

private struct AIFoodClassificationResponse: Decodable {
    struct Item: Decodable {
        let source: String
        let kind: String
        let externalId: String
        let foodType: FoodType
    }
    let items: [Item]
}

private struct AIFoodRecipeMatchRequest: Encodable {
    struct Candidate: Encodable {
        let externalId: String
        let title: String
        let ingredients: [String]
        let steps: [String]
    }
    let title: String
    let locale: String
    let candidates: [Candidate]
}

private struct AIFoodRecipeMatchResponse: Decodable {
    let externalId: String?

    private enum CodingKeys: String, CodingKey { case externalId }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.contains(.externalId) else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        externalId = try container.decodeIfPresent(String.self, forKey: .externalId)
    }
}

struct AIFoodSearchCatalogPageResponse: Decodable {
    let items: [AIFoodSearchItem]?
    let sections: [AIFoodSearchCatalogSection]?
    let hasMore: Bool?
    let offset: Int?
    let nextOffset: Int?
    let limit: Int?
    let total: Int?
    let error: String?
}

struct AIFoodSearchCatalogResponse: Decodable {
    let sections: [AIFoodSearchCatalogSection]?
    let error: String?
}

struct AIFoodSearchCatalogSection: Decodable {
    let id: String?
    let items: [AIFoodSearchItem]?
}

struct AIFoodSearchRequest: Encodable {
    let query: String
    let locale: String
    let scope: String
}

struct AIFoodSearchResponse: Decodable {
    let items: [AIFoodSearchItem]?
    let error: String?
}

struct AIFoodDetailsRequest: Encodable {
    let title: String
    let locale: String
    let imageURL: String?
    let source: String
    let kind: String
}

struct AIFoodDetailsResponse: Decodable {
    let item: AIFoodSearchItem?
    let error: String?
}

struct AIFoodSearchItem: Decodable {
    let source: String?
    let kind: String?
    let foodType: FoodType?
    let externalId: String?
    let name: String?
    let title: String?
    let summary: String?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fats: Double?
    let fiber: Double?
    let sugar: Double?
    let sodium: Double?
    let amount: Double?
    let unit: String?
    let cookTimeMinutes: Double?
    let ingredients: [String]?
    let steps: [String]?
    let imageURL: String?
    let sourceURL: String?
    let serving: String?

    private enum CodingKeys: String, CodingKey {
        case source, kind, foodType, externalId, name, title, summary
        case calories, protein, carbs, fats, fiber, sugar, sodium, amount, unit, serving
        case cookTimeMinutes, ingredients, steps, instructions, imageURL, imageUrl, image
        case sourceURL, sourceUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        foodType = try container.decodeIfPresent(String.self, forKey: .foodType).flatMap(FoodType.init(rawValue:))
        externalId = try container.decodeIfPresent(String.self, forKey: .externalId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        calories = Self.decodeFlexibleDouble(container, forKey: .calories)
        protein = Self.decodeFlexibleDouble(container, forKey: .protein)
        carbs = Self.decodeFlexibleDouble(container, forKey: .carbs)
        fats = Self.decodeFlexibleDouble(container, forKey: .fats)
        fiber = Self.decodeFlexibleDouble(container, forKey: .fiber)
        sugar = Self.decodeFlexibleDouble(container, forKey: .sugar)
        sodium = Self.decodeFlexibleDouble(container, forKey: .sodium)
        amount = Self.decodeFlexibleDouble(container, forKey: .amount)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        serving = try container.decodeIfPresent(String.self, forKey: .serving)
        cookTimeMinutes = Self.decodeFlexibleDouble(container, forKey: .cookTimeMinutes)
        ingredients = Self.decodeStringList(container, forKey: .ingredients)
        steps =
            Self.decodeStringList(container, forKey: .steps)
            ?? Self.decodeStringList(container, forKey: .instructions)
        if let value = try container.decodeIfPresent(String.self, forKey: .imageURL) {
            imageURL = value
        } else if let value = try container.decodeIfPresent(String.self, forKey: .imageUrl) {
            imageURL = value
        } else {
            imageURL = try container.decodeIfPresent(String.self, forKey: .image)
        }
        if let value = try container.decodeIfPresent(String.self, forKey: .sourceURL) {
            sourceURL = value
        } else {
            sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        }
    }

    private static func decodeFlexibleDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let raw = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(raw.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    private static func decodeStringList(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [String]? {
        if let values = try? container.decodeIfPresent([String].self, forKey: key) {
            return values
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : [trimmed]
        }
        return nil
    }
}

final class AIFoodSearchService: AIFoodSearching {
    static let idPrefix = "ai-"

    private let configuration: AIAssistantAPIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let catalogCache: URLCache
    private let catalogRetryDelayNanoseconds: UInt64

    private struct TemporaryCatalogFailure: Error {
        let underlying: Error
        let retryAfter: TimeInterval?
    }

    init(
        configuration: AIAssistantAPIConfiguration = .production,
        session: URLSession = .shared,
        catalogCache: URLCache = .shared,
        catalogRetryDelayNanoseconds: UInt64 = 500_000_000
    ) {
        self.configuration = configuration
        self.session = session
        self.catalogCache = catalogCache
        self.catalogRetryDelayNanoseconds = catalogRetryDelayNanoseconds
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func searchFoods(query: String) async throws -> [FoodProduct] {
        try await fetchItems(query: query, scope: "foods").compactMap(Self.mapFood)
    }

    func searchRecipes(query: String) async throws -> [Recipe] {
        try await fetchItems(query: query, scope: "recipes").compactMap(Self.mapRecipe)
    }

    func matchingRecipe(title: String, candidates: [Recipe]) async throws -> Recipe? {
        guard !candidates.isEmpty else { return nil }
        guard let url = URL(string: "/v1/food/match-recipe", relativeTo: configuration.baseURL)?.absoluteURL else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        let mapped = candidates.compactMap { candidate -> AIFoodRecipeMatchRequest.Candidate? in
            guard let id = candidate.externalId, !id.isEmpty else { return nil }
            return AIFoodRecipeMatchRequest.Candidate(externalId: id, title: candidate.title,
                                                     ingredients: candidate.ingredients.map { $0.originalText ?? $0.name },
                                                     steps: candidate.steps)
        }
        guard mapped.count == candidates.count else { throw FoodPhotoAnalysisError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BityiOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        if let key = configuration.apiKey, !key.isEmpty { request.setValue(key, forHTTPHeaderField: "x-api-key") }
        request.httpBody = try encoder.encode(AIFoodRecipeMatchRequest(title: title, locale: Locale.deviceIdentifier, candidates: mapped))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FoodPhotoAnalysisError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? decoder.decode(AIFoodSearchResponse.self, from: data))?.error
            throw FoodPhotoAnalysisError.analysisFailed(message: message ?? "HTTP \(http.statusCode)")
        }
        let decoded = try decoder.decode(AIFoodRecipeMatchResponse.self, from: data)
        guard let matchedID = decoded.externalId else { return nil }
        let matches = candidates.filter { $0.externalId == matchedID }
        guard matches.count == 1, let match = matches.first else { throw FoodPhotoAnalysisError.invalidResponse }
        return match
    }

    func classifyFoods(_ products: [FoodProduct]) async throws -> [FoodProduct] {
        guard !products.isEmpty else { return [] }
        guard let url = URL(string: "/v1/food/classify", relativeTo: configuration.baseURL)?.absoluteURL else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BityiOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        if let key = configuration.apiKey, !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        }
        request.httpBody = try encoder.encode(AIFoodClassificationRequest(
            items: products.map { product in
                AIFoodClassificationRequest.Item(source: product.source.rawValue, kind: product.kind.rawValue,
                                                 externalId: product.externalId, title: product.name,
                                                 brand: product.brand, ingredients: product.ingredients, steps: product.steps)
            },
            locale: Locale.deviceIdentifier
        ))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FoodPhotoAnalysisError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? decoder.decode(AIFoodSearchResponse.self, from: data))?.error
            throw FoodPhotoAnalysisError.analysisFailed(message: message ?? "HTTP \(http.statusCode)")
        }
        let decoded = try decoder.decode(AIFoodClassificationResponse.self, from: data)
        guard decoded.items.count == products.count else { throw FoodPhotoAnalysisError.invalidResponse }
        return try products.map { product in
            let matches = decoded.items.filter {
                $0.source == product.source.rawValue && $0.kind == product.kind.rawValue && $0.externalId == product.externalId
            }
            guard let item = matches.first, matches.allSatisfy({ $0.foodType == item.foodType }) else {
                throw FoodPhotoAnalysisError.invalidResponse
            }
            var resolved = product
            resolved.foodType = item.foodType
            return resolved
        }
    }

    func enrichDetails(
        title: String,
        imageURL: URL?,
        source: String,
        kind: String
    ) async throws -> FoodProduct? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let url = URL(string: "/v1/food/details", relativeTo: configuration.baseURL)?.absoluteURL else {
            throw FoodPhotoAnalysisError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BityiOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let body = AIFoodDetailsRequest(
            title: trimmed,
            locale: Locale.deviceIdentifier,
            imageURL: imageURL?.absoluteString,
            source: source,
            kind: kind
        )
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw FoodPhotoAnalysisError.transport(message: error.localizedDescription)
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
        let decoded = try? decoder.decode(AIFoodDetailsResponse.self, from: data)
        if !(200...299).contains(http.statusCode) {
            throw FoodPhotoAnalysisError.analysisFailed(
                message: decoded?.error ?? "HTTP \(http.statusCode)"
            )
        }
        guard let item = decoded?.item else { return nil }
        return Self.mapFood(item)
    }

    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] {
        if let data = try? await getCatalog(path: "/v1/food/search/catalog") {
            let mapped = Self.decodeCatalog(from: data, locale: Locale.deviceIdentifier)
            if !mapped.isEmpty {
                return mapped
            }
        }
        return Self.decodeCatalog(from: await fallbackCatalogData(), locale: Locale.deviceIdentifier)
    }

    func fetchCatalogSection(id: String) async throws -> [FoodProduct] {
        try await fetchCatalogSectionPage(id: id, offset: 0, limit: 20).products
    }

    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return FoodSearchCatalogPage(products: [], nextOffset: offset, hasMore: false)
        }
        let data = try await getCatalog(
            path: "/v1/food/search/catalog/\(trimmed)",
            queryItems: [
                URLQueryItem(name: "offset", value: String(max(0, offset))),
                URLQueryItem(name: "limit", value: String(max(1, limit))),
            ]
        )
        return Self.decodeCatalogPage(from: data, id: trimmed, offset: offset, locale: Locale.deviceIdentifier)
    }

    private func fallbackCatalogData() async -> Data {
        if let bundled = Self.bundledCatalogData(), !bundled.isEmpty {
            return bundled
        }
        return (try? await getStaticRemoteCatalog()) ?? Data()
    }

    private func getStaticRemoteCatalog() async throws -> Data {
        var request = URLRequest(
            url: configuration.defaultFoodCatalogURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 18
        )
        request.httpMethod = "GET"
        request.setValue("BityiOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        return data
    }

    private static func bundledCatalogData() -> Data? {
        let url = Bundle.main.url(forResource: "food-search-catalog", withExtension: "json")
            ?? Bundle.main.url(forResource: "food-search-catalog", withExtension: "json", subdirectory: "Resources")
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }

    private func getCatalog(path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        guard let base = URL(string: path, relativeTo: configuration.baseURL)?.absoluteURL,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "locale", value: Locale.deviceIdentifier),
        ] + queryItems
        guard let url = components.url else {
            throw FoodPhotoAnalysisError.invalidResponse
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 60
        )
        request.httpMethod = "GET"
        request.setValue("BityiOS/1.0", forHTTPHeaderField: "User-Agent")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let cached = catalogCache.cachedResponse(for: request)
        if let cached, Self.isUsableCatalogCache(cached, allowStale: false) {
            return cached.data
        }
        var lastError: Error = FoodPhotoAnalysisError.invalidResponse
        let deadline = Date().addingTimeInterval(45)
        for attempt in 0..<3 {
            try Task.checkCancellation()
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { break }
            var attemptRequest = request
            attemptRequest.timeoutInterval = min(20, remaining)
            do {
                let (data, response) = try await session.data(for: attemptRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw FoodPhotoAnalysisError.invalidResponse
                }
                if [408, 425, 429].contains(http.statusCode) || (500...599).contains(http.statusCode) {
                    throw TemporaryCatalogFailure(
                        underlying: FoodPhotoAnalysisError.analysisFailed(message: "HTTP \(http.statusCode)"),
                        retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                    )
                }
                guard (200...299).contains(http.statusCode) else {
                    throw FoodPhotoAnalysisError.analysisFailed(message: "HTTP \(http.statusCode)")
                }
                guard Self.isCatalogPayload(data) else {
                    throw TemporaryCatalogFailure(underlying: FoodPhotoAnalysisError.invalidResponse, retryAfter: nil)
                }
                if http.value(forHTTPHeaderField: "Cache-Control")?.lowercased().contains("no-store") != true {
                    catalogCache.storeCachedResponse(CachedURLResponse(
                        response: http, data: data,
                        userInfo: ["bity.catalog.storedAt": Date().timeIntervalSince1970],
                        storagePolicy: .allowed
                    ), for: request)
                }
                return data
            } catch {
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    throw CancellationError()
                }
                let temporary = error as? TemporaryCatalogFailure
                let retryableNetwork = (error as? URLError).map {
                    [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost,
                     .cannotFindHost, .dnsLookupFailed, .resourceUnavailable].contains($0.code)
                } ?? false
                guard temporary != nil || retryableNetwork else { throw error }
                lastError = temporary?.underlying ?? error
                if attempt < 2 {
                    let delay = temporary?.retryAfter.map { min(max($0, 0), 2) }
                        ?? Double(catalogRetryDelayNanoseconds) / 1_000_000_000 * Double(attempt + 1)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        if let cached, Self.isUsableCatalogCache(cached, allowStale: true) {
            return cached.data
        }
        throw lastError
    }

    private static func isCatalogPayload(_ data: Data) -> Bool {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
        return object["items"] is [[String: Any]] || object["sections"] is [[String: Any]]
    }

    private static func isUsableCatalogCache(_ cached: CachedURLResponse, allowStale: Bool) -> Bool {
        guard let storedAt = cached.userInfo?["bity.catalog.storedAt"] as? TimeInterval,
              let http = cached.response as? HTTPURLResponse,
              (200...299).contains(http.statusCode), isCatalogPayload(cached.data) else { return false }
        let directives = http.value(forHTTPHeaderField: "Cache-Control")?.lowercased() ?? ""
        guard !directives.contains("no-store") else { return false }
        if !allowStale && directives.contains("no-cache") { return false }
        if allowStale && directives.contains("must-revalidate") { return false }
        let maxAge = directives.split(separator: ",").compactMap { directive -> TimeInterval? in
            let parts = directive.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1)
            guard parts.count == 2, parts[0] == "max-age" else { return nil }
            return TimeInterval(parts[1])
        }.first ?? 600
        let age = Date().timeIntervalSince1970 - storedAt
        return age >= 0 && age < (allowStale ? 86_400 : min(maxAge, 600))
    }

    private func fetchItems(query: String, scope: String) async throws -> [AIFoodSearchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        guard let url = URL(string: "/v1/food/search", relativeTo: configuration.baseURL)?.absoluteURL else {
            throw FoodPhotoAnalysisError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BityiOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 18
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let body = AIFoodSearchRequest(
            query: trimmed,
            locale: Locale.deviceIdentifier,
            scope: scope
        )
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw FoodPhotoAnalysisError.transport(message: error.localizedDescription)
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

        let items = Self.decodeItems(from: data, decoder: decoder)
        if !(200...299).contains(http.statusCode) {
            let message = (try? decoder.decode(AIFoodSearchResponse.self, from: data))?.error
            throw FoodPhotoAnalysisError.analysisFailed(
                message: message ?? "HTTP \(http.statusCode)"
            )
        }
        return items
    }

    static func decodeCatalogPage(
        from data: Data,
        id: String,
        offset: Int,
        decoder: JSONDecoder = JSONDecoder(),
        locale: String = Locale.deviceIdentifier
    ) -> FoodSearchCatalogPage {
        if let decoded = try? decoder.decode(AIFoodSearchCatalogPageResponse.self, from: data) {
            let mapped = (decoded.items ?? []).compactMap(mapFood)
            let fallback = decodeCatalog(from: data, decoder: decoder, locale: locale)
            let products = mapped.isEmpty ? (fallback[id] ?? fallback.values.first ?? []) : mapped
            let nextOffset = decoded.nextOffset ?? ((decoded.offset ?? offset) + (decoded.items?.count ?? products.count))
            let hasMore: Bool
            if let flag = decoded.hasMore {
                hasMore = flag
            } else if let total = decoded.total {
                hasMore = nextOffset < total
            } else {
                hasMore = products.count >= 20
            }
            return FoodSearchCatalogPage(products: products, nextOffset: nextOffset, hasMore: hasMore)
        }
        let products = decodeCatalog(from: data, decoder: decoder, locale: locale)[id] ?? []
        return FoodSearchCatalogPage(
            products: products,
            nextOffset: offset + products.count,
            hasMore: false
        )
    }

    static func decodeCatalog(
        from data: Data,
        decoder: JSONDecoder = JSONDecoder(),
        locale: String = Locale.deviceIdentifier
    ) -> [String: [FoodProduct]] {
        if let decoded = try? decoder.decode(AIFoodSearchCatalogResponse.self, from: data),
           let sections = decoded.sections {
            let mapped = Dictionary(
                uniqueKeysWithValues: sections.compactMap { section -> (String, [FoodProduct])? in
                    let id = section.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !id.isEmpty else { return nil }
                    let items = (section.items ?? []).compactMap(mapFood)
                    guard !items.isEmpty else { return nil }
                    return (id, items)
                }
            )
            if !mapped.isEmpty {
                return mapped
            }
        }
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sections = root["sections"] as? [[String: Any]]
        else {
            return [:]
        }
        var mapped: [String: [FoodProduct]] = [:]
        for section in sections {
            let id = (section["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !id.isEmpty else { continue }
            let rawItems = section["items"] as? [[String: Any]] ?? []
            let items = rawItems.compactMap { mapCatalogItem($0, locale: locale) }
            if !items.isEmpty {
                mapped[id] = items
            }
        }
        return mapped
    }

    static func decodeItems(from data: Data, decoder: JSONDecoder = JSONDecoder()) -> [AIFoodSearchItem] {
        if let decoded = try? decoder.decode(AIFoodSearchResponse.self, from: data),
           let items = decoded.items {
            return items
        }
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawItems = root["items"] as? [Any]
        else {
            return []
        }
        return rawItems.compactMap { item in
            guard JSONSerialization.isValidJSONObject(item),
                  let itemData = try? JSONSerialization.data(withJSONObject: item),
                  let decoded = try? decoder.decode(AIFoodSearchItem.self, from: itemData)
            else {
                return nil
            }
            return decoded
        }
    }

    private static func mapCatalogItem(_ raw: [String: Any], locale: String) -> FoodProduct? {
        let name = localizedCatalogText(raw["title"] ?? raw["name"], locale: locale)
        guard !name.isEmpty else { return nil }
        let externalId = stringValue(raw["externalId"]) ?? stringValue(raw["id"]) ?? "\(idPrefix)\(UUID().uuidString)"
        let source = FoodProductSource(apiValue: stringValue(raw["source"]) ?? "catalog")
        let unit = stringValue(raw["unit"]) ?? ""
        let serving = localizedCatalogText(raw["serving"], locale: locale)
        let summary = stringValue(raw["summary"])
        return FoodProduct(
            id: UUID(),
            externalId: externalId,
            name: name,
            brand: nil,
            kind: productKind(stringValue(raw["kind"]), source: source),
            imageURL: absoluteImageURL(stringValue(raw["imageURL"]) ?? stringValue(raw["imageUrl"]) ?? stringValue(raw["image"])),
            calories: doubleValue(raw["calories"]),
            protein: doubleValue(raw["protein"]),
            carbs: doubleValue(raw["carbs"]),
            fats: doubleValue(raw["fats"]),
            fiber: doubleValue(raw["fiber"]),
            sugar: doubleValue(raw["sugar"]),
            sodium: doubleValue(raw["sodium"]),
            amount: doubleValue(raw["amount"]),
            unit: unit.isEmpty ? nil : unit,
            source: source == .unknown ? .catalog : source,
            servingSizeLabel: serving.isEmpty ? summary : serving,
            foodType: stringValue(raw["foodType"]).flatMap(FoodType.init(rawValue:))
        )
    }

    private static func localizedCatalogText(_ value: Any?, locale: String) -> String {
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let map = value as? [String: Any] else { return "" }
        let language = locale
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
            .split(separator: "-")
            .first
            .map(String.init) ?? "en"
        let picked = map[language] ?? map["en"] ?? map.values.first
        return (picked as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let string = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else {
            return nil
        }
        return string
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? Double {
            return number
        }
        if let number = value as? Int {
            return Double(number)
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let raw = value as? String {
            return Double(raw.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    static func mapFood(_ item: AIFoodSearchItem) -> FoodProduct? {
        let name = displayName(item)
        guard let name else { return nil }
        let unit = item.unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var source = FoodProductSource(apiValue: item.source)
        let externalId = item.externalId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "\(idPrefix)\(UUID().uuidString)"
        if source == .unknown && externalId.hasPrefix(idPrefix) {
            source = .openAI
        }
        return FoodProduct(
            id: UUID(),
            externalId: externalId,
            name: name,
            brand: source == .openFoodFacts ? item.summary?.nilIfEmpty : nil,
            kind: productKind(item.kind, source: source),
            imageURL: absoluteImageURL(item.imageURL),
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fats: item.fats,
            fiber: item.fiber,
            sugar: item.sugar,
            sodium: item.sodium,
            amount: item.amount,
            unit: unit.isEmpty ? nil : unit,
            source: source,
            ingredients: (item.ingredients ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            steps: cleanedLines(item.steps),
            servingSizeLabel: servingSizeLabel(item, source: source),
            foodType: item.foodType ?? FoodType.inferred(kind: productKind(item.kind, source: source), source: source)
        )
    }

    private static func servingSizeLabel(_ item: AIFoodSearchItem, source: FoodProductSource) -> String? {
        if let serving = item.serving?.trimmingCharacters(in: .whitespacesAndNewlines), !serving.isEmpty {
            return serving
        }
        if source == .catalog {
            return item.summary?.nilIfEmpty
        }
        return nil
    }

    static func mapRecipe(_ item: AIFoodSearchItem) -> Recipe? {
        let kind = productKind(item.kind, source: FoodProductSource(apiValue: item.source))
        guard item.foodType != .product, item.foodType == .dish || kind == .recipe else { return nil }
        let title = displayName(item)
        guard let title else { return nil }
        let ingredients = (item.ingredients ?? []).enumerated().compactMap { index, text -> RecipeIngredient? in
            let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return RecipeIngredient(
                id: "ing-\(index)",
                name: name,
                amount: nil,
                unit: nil,
                originalText: name
            )
        }
        let origin = FoodProductSource(apiValue: item.source)
        let externalId = item.externalId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "\(idPrefix)\(UUID().uuidString)"
        let resolvedOrigin = origin == .unknown && externalId.hasPrefix(idPrefix) ? .openAI : origin
        let imageURL = absoluteImageURL(item.imageURL)
            ?? (resolvedOrigin == .spoonacular && kind == .recipe ? FoodImageURL.spoonacularRecipeURL(id: item.externalId) : nil)
        return Recipe(
            id: UUID(),
            externalId: kind == .recipe ? externalId : kind.rawValue + ":" + externalId,
            title: title,
            summary: item.summary,
            imageURL: imageURL,
            readyInMinutes: item.cookTimeMinutes.flatMap { minutes in
                let value = Int(minutes.rounded())
                return value > 0 ? value : nil
            },
            servings: 1,
            calories: item.calories.flatMap { $0 > 0 ? $0 : nil },
            protein: item.protein,
            carbs: item.carbs,
            fats: item.fats,
            ingredients: ingredients,
            steps: cleanedLines(item.steps),
            sourceName: item.sourceURL?.nilIfEmpty ?? resolvedOrigin.rawValue,
            origin: resolvedOrigin,
            weightGrams: recipeWeightGrams(item),
            foodType: item.foodType ?? .dish
        )
    }

    private static func recipeWeightGrams(_ item: AIFoodSearchItem) -> Double? {
        let unit = (item.unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let amount = item.amount, amount > 0,
           ["g", "gr", "gram", "grams", "г", "грам", "грами", "грамів"].contains(unit) {
            return amount
        }
        return ProductDetailsMath.gramsFromLabel(item.serving)
    }

    private static func productKind(_ raw: String?, source: FoodProductSource = .unknown) -> FoodProductKind {
        switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "recipe":
            return .recipe
        case "ingredient":
            return .ingredient
        case "product":
            return .product
        default:
            return .product
        }
    }

    private static func displayName(_ item: AIFoodSearchItem) -> String? {
        [item.title, item.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func cleanedLines(_ values: [String]?) -> [String] {
        (values ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func absoluteImageURL(_ raw: String?) -> URL? {
        var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("http://") {
            value = "https://" + value.dropFirst("http://".count)
        }
        guard value.hasPrefix("https://") else { return nil }
        if FoodImageURL.isPlaceholder(value) { return nil }
        if let url = URL(string: value), url.host != nil {
            return FoodImageURL.isPlaceholder(url) ? nil : url
        }
        let encoded = value.replacingOccurrences(of: " ", with: "%20")
        guard let url = URL(string: encoded), url.host != nil else { return nil }
        return FoodImageURL.isPlaceholder(url) ? nil : url
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
