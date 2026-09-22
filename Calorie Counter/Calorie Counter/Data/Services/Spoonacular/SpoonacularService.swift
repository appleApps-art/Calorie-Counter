import Foundation

struct SpoonacularRecipeSearch: Equatable {
    var query: String
    var number: Int = 10
    var minCalories: Int? = nil
    var maxCalories: Int? = nil
    var cuisine: String? = nil
    var diet: String? = nil
    var type: String? = nil
    var includeIngredients: String? = nil
    var maxReadyTime: Int? = nil
    /// Catalog ordering, e.g. "popularity". Without it a filter-only search comes back unranked.
    var sort: String? = nil
    /// Grams of protein per serving at least, so a plan's meals can actually feed the protein goal.
    var minProtein: Int? = nil
}

nonisolated protocol SpoonacularServiceProtocol {
    func searchRecipes(query: String, maxCalories: Int?, number: Int) async throws -> [Recipe]
    func searchRecipes(_ search: SpoonacularRecipeSearch) async throws -> [Recipe]
    func pantryRecipeMatches(ingredients: [String], number: Int) async throws -> [PantryRecipeMatch]
    func recipeDetails(id: String) async throws -> Recipe
    func searchIngredients(query: String, number: Int) async throws -> [FoodProduct]
    func ingredientDetails(id: String, amount: Double, unit: String) async throws -> FoodProduct
    func searchProducts(query: String, number: Int) async throws -> [FoodProduct]
    func productDetails(id: String) async throws -> FoodProduct
    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct
}

extension SpoonacularServiceProtocol {
    func pantryRecipeMatches(ingredients: [String], number: Int) async throws -> [PantryRecipeMatch] { [] }

    func searchRecipes(_ search: SpoonacularRecipeSearch) async throws -> [Recipe] {
        try await searchRecipes(query: search.query, maxCalories: search.maxCalories, number: search.number)
    }
}

nonisolated final class SpoonacularService: SpoonacularServiceProtocol, @unchecked Sendable {
    private let configuration: SpoonacularAPIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let scheduler: SpoonacularRequestScheduler
    private let maxAttempts = 6
    private let recipeDetailsCache = RecipeDetailsCache()

    init(
        configuration: SpoonacularAPIConfiguration = .production,
        session: URLSession = .shared,
        scheduler: SpoonacularRequestScheduler = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.decoder = JSONDecoder()
        self.scheduler = scheduler
    }

    func searchRecipes(query: String, maxCalories: Int?, number: Int = 10) async throws -> [Recipe] {
        try await searchRecipes(
            SpoonacularRecipeSearch(query: query, number: number, maxCalories: maxCalories)
        )
    }

    func searchRecipes(_ search: SpoonacularRecipeSearch) async throws -> [Recipe] {
        var items: [URLQueryItem] = [
            .init(name: "number", value: String(search.number)),
            .init(name: "locale", value: Locale.deviceIdentifier),
        ]
        if !search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(.init(name: "query", value: search.query))
        }
        if let minCalories = search.minCalories {
            items.append(.init(name: "minCalories", value: String(minCalories)))
        }
        if let maxCalories = search.maxCalories {
            items.append(.init(name: "maxCalories", value: String(maxCalories)))
        }
        if let cuisine = search.cuisine, !cuisine.isEmpty {
            items.append(.init(name: "cuisine", value: cuisine))
        }
        if let diet = search.diet, !diet.isEmpty {
            items.append(.init(name: "diet", value: diet))
        }
        if let type = search.type, !type.isEmpty {
            items.append(.init(name: "type", value: type))
        }
        if let includeIngredients = search.includeIngredients, !includeIngredients.isEmpty {
            items.append(.init(name: "includeIngredients", value: includeIngredients))
        }
        if let maxReadyTime = search.maxReadyTime {
            items.append(.init(name: "maxReadyTime", value: String(maxReadyTime)))
        }
        if let sort = search.sort, !sort.isEmpty {
            items.append(.init(name: "sort", value: sort))
        }
        if let minProtein = search.minProtein {
            items.append(.init(name: "minProtein", value: String(minProtein)))
        }
        let response: SpoonacularRecipeSearchResponse = try await get(
            path: "/v1/spoonacular/recipes/search",
            queryItems: items
        )
        return (response.results ?? []).map(SpoonacularMapper.mapSearchItem)
    }

    func pantryRecipeMatches(ingredients: [String], number: Int) async throws -> [PantryRecipeMatch] {
        let names = ingredients
            .map { $0.replacingOccurrences(of: ",", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return [] }
        let response: SpoonacularPantryMatchResponse = try await get(
            path: "/v1/spoonacular/pantry/search",
            queryItems: [
                .init(name: "ingredients", value: names.joined(separator: ",")),
                .init(name: "number", value: String(number)),
                .init(name: "locale", value: Locale.deviceIdentifier),
            ]
        )
        return (response.results ?? []).map {
            PantryRecipeMatch(id: String($0.id), missedIngredientCount: $0.missedIngredientCount ?? .max)
        }
    }

    func recipeDetails(id: String) async throws -> Recipe {
        let locale = Locale.deviceIdentifier
        return try await recipeDetailsCache.value(for: "7:\(locale):\(id)") { [self] in
            let response: SpoonacularRecipeInformation = try await get(
                path: "/v1/spoonacular/recipes/\(id)",
                queryItems: [
                    .init(name: "locale", value: locale),
                    .init(name: "localizationRevision", value: "7"),
                ],
                timeoutInterval: 60
            )
            return SpoonacularMapper.mapInformation(response)
        }
    }

    func searchIngredients(query: String, number: Int = 10) async throws -> [FoodProduct] {
        let response: SpoonacularIngredientSearchResponse = try await get(
            path: "/v1/spoonacular/ingredients/search",
            queryItems: [
                .init(name: "query", value: query),
                .init(name: "number", value: String(number)),
                .init(name: "locale", value: Locale.deviceIdentifier),
            ]
        )
        return (response.results ?? []).map(SpoonacularMapper.mapIngredientSearchItem)
    }

    func ingredientDetails(id: String, amount: Double = 100, unit: String = "grams") async throws -> FoodProduct {
        let response: SpoonacularIngredientInformation = try await get(
            path: "/v1/spoonacular/ingredients/\(id)",
            queryItems: [
                .init(name: "amount", value: String(amount)),
                .init(name: "unit", value: unit),
                .init(name: "locale", value: Locale.deviceIdentifier),
            ]
        )
        return SpoonacularMapper.mapIngredientInformation(response)
    }

    func searchProducts(query: String, number: Int = 10) async throws -> [FoodProduct] {
        let response: SpoonacularProductSearchResponse = try await get(
            path: "/v1/spoonacular/products/search",
            queryItems: [
                .init(name: "query", value: query),
                .init(name: "number", value: String(number)),
                .init(name: "locale", value: Locale.deviceIdentifier),
            ]
        )
        return (response.products ?? []).map(SpoonacularMapper.mapProductSearchItem)
    }

    func productDetails(id: String) async throws -> FoodProduct {
        let response: SpoonacularUpcProductResponse = try await get(
            path: "/v1/spoonacular/products/\(id)",
            queryItems: [
                .init(name: "locale", value: Locale.deviceIdentifier),
            ]
        )
        guard let mapped = SpoonacularMapper.mapGroceryProduct(response, fallbackId: id) else {
            throw SpoonacularServiceError.invalidResponse
        }
        return mapped
    }

    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct {
        guard let normalized = BarcodeNormalization.normalize(barcode) else {
            throw BarcodeLookupError.invalidBarcode
        }
        do {
            let response: SpoonacularUpcProductResponse = try await get(
                path: "/v1/spoonacular/products/upc/\(normalized)",
                queryItems: [
                    .init(name: "locale", value: Locale.deviceIdentifier),
                ]
            )
            guard let mapped = SpoonacularMapper.mapUpcProduct(response, barcode: normalized) else {
                throw BarcodeLookupError.notFound
            }
            return mapped
        } catch let error as SpoonacularServiceError {
            if isNotFound(error) {
                throw BarcodeLookupError.notFound
            }
            throw error
        }
    }

    private func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        timeoutInterval: TimeInterval = 30
    ) async throws -> T {
        let request = try makeRequest(path: path, queryItems: queryItems, timeoutInterval: timeoutInterval)
        let data = try await OfflineFallback.data(for: request) {
            try await self.dataWithRetries(for: request)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SpoonacularServiceError.decodingFailed
        }
    }

    private func dataWithRetries(for request: URLRequest) async throws -> Data {
        var delayNs: UInt64 = 250_000_000
        var lastError: Error = SpoonacularServiceError.invalidResponse
        for attempt in 0..<maxAttempts {
            do {
                return try await scheduler.run {
                    try await self.performGet(request)
                }
            } catch let error as SpoonacularServiceError where error.isRetryable {
                lastError = error
                // Retrying only helps a busy server, not a phone that lost its connection.
                guard attempt < maxAttempts - 1, NetworkMonitor.shared.isOnline else { break }
                let retryNs = retryNanoseconds(error.retryAfter, fallback: delayNs)
                try await Task.sleep(nanoseconds: retryNs)
                delayNs = min(delayNs * 2, 4_000_000_000)
            } catch let error as CancellationError {
                throw error
            } catch {
                throw error
            }
        }
        throw lastError
    }

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem],
        timeoutInterval: TimeInterval
    ) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw SpoonacularServiceError.invalidURL
        }
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw SpoonacularServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval
        request.setValue("BityiOS/1.0", forHTTPHeaderField: "User-Agent")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        return request
    }

    private func performGet(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SpoonacularServiceError.transport(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SpoonacularServiceError.invalidResponse
        }

        if !(200...299).contains(http.statusCode) {
            let message: String
            if let serverError = try? decoder.decode(SpoonacularErrorResponse.self, from: data),
               let errorMessage = serverError.error {
                message = errorMessage
            } else {
                message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            }
            throw SpoonacularServiceError.http(
                status: http.statusCode,
                message: message,
                retryAfter: retryAfterInterval(from: http)
            )
        }
        return data
    }

    private func isNotFound(_ error: SpoonacularServiceError) -> Bool {
        switch error {
        case .http(let status, let message, _):
            return status == 404 || message.lowercased().contains("not found")
        case .server(let message):
            let lower = message.lowercased()
            return lower.contains("not found") || lower.contains("404")
        default:
            return false
        }
    }

    private func retryAfterInterval(from response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return nil
        }
        if let seconds = TimeInterval(raw) {
            return seconds
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: raw) {
            return max(0, date.timeIntervalSinceNow)
        }
        return nil
    }

    private func retryNanoseconds(_ retryAfter: TimeInterval?, fallback: UInt64) -> UInt64 {
        if let retryAfter {
            let clamped = min(max(retryAfter, 0.2), 8)
            return UInt64(clamped * 1_000_000_000)
        }
        return fallback
    }
}

/// Keeps successful details and shares concurrent requests; failures are never cached.
private actor RecipeDetailsCache {
    private var values: [String: (recipe: Recipe, expires: Date)] = [:]
    private var pending: [String: Task<Recipe, Error>] = [:]

    func value(for key: String, load: @escaping @Sendable () async throws -> Recipe) async throws -> Recipe {
        if let value = values[key], value.expires > Date() { return value.recipe }
        if let task = pending[key] { return try await task.value }
        let task = Task { try await load() }
        pending[key] = task
        defer { pending[key] = nil }
        let recipe = try await task.value
        values = values.filter { $0.value.expires > Date() }
        if values.count >= 100, let oldest = values.min(by: { $0.value.expires < $1.value.expires })?.key {
            values.removeValue(forKey: oldest)
        }
        values[key] = (recipe, Date().addingTimeInterval(24 * 60 * 60))
        return recipe
    }
}
