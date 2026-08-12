import Foundation

protocol SpoonacularServiceProtocol {
    func searchRecipes(query: String, maxCalories: Int?, number: Int) async throws -> [Recipe]
    func recipeDetails(id: String) async throws -> Recipe
    func searchIngredients(query: String, number: Int) async throws -> [FoodProduct]
    func ingredientDetails(id: String, amount: Double, unit: String) async throws -> FoodProduct
    func searchProducts(query: String, number: Int) async throws -> [FoodProduct]
    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct
}

final class SpoonacularService: SpoonacularServiceProtocol {
    private let configuration: SpoonacularAPIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        configuration: SpoonacularAPIConfiguration = .production,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.decoder = JSONDecoder()
    }

    func searchRecipes(query: String, maxCalories: Int?, number: Int = 12) async throws -> [Recipe] {
        var items: [URLQueryItem] = [
            .init(name: "query", value: query),
            .init(name: "number", value: String(number)),
        ]
        if let maxCalories {
            items.append(.init(name: "maxCalories", value: String(maxCalories)))
        }
        let response: SpoonacularRecipeSearchResponse = try await get(
            path: "/v1/spoonacular/recipes/search",
            queryItems: items
        )
        return (response.results ?? []).map(SpoonacularMapper.mapSearchItem)
    }

    func recipeDetails(id: String) async throws -> Recipe {
        let response: SpoonacularRecipeInformation = try await get(
            path: "/v1/spoonacular/recipes/\(id)",
            queryItems: []
        )
        return SpoonacularMapper.mapInformation(response)
    }

    func searchIngredients(query: String, number: Int = 12) async throws -> [FoodProduct] {
        let response: SpoonacularIngredientSearchResponse = try await get(
            path: "/v1/spoonacular/ingredients/search",
            queryItems: [
                .init(name: "query", value: query),
                .init(name: "number", value: String(number)),
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
            ]
        )
        return SpoonacularMapper.mapIngredientInformation(response)
    }

    func searchProducts(query: String, number: Int = 12) async throws -> [FoodProduct] {
        let response: SpoonacularProductSearchResponse = try await get(
            path: "/v1/spoonacular/products/search",
            queryItems: [
                .init(name: "query", value: query),
                .init(name: "number", value: String(number)),
            ]
        )
        return (response.products ?? []).map(SpoonacularMapper.mapProductSearchItem)
    }

    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct {
        guard let normalized = BarcodeNormalization.normalize(barcode) else {
            throw BarcodeLookupError.invalidBarcode
        }
        do {
            let response: SpoonacularUpcProductResponse = try await get(
                path: "/v1/spoonacular/products/upc/\(normalized)",
                queryItems: []
            )
            guard let mapped = SpoonacularMapper.mapUpcProduct(response, barcode: normalized) else {
                throw BarcodeLookupError.notFound
            }
            return mapped
        } catch SpoonacularServiceError.server(let message) {
            let lower = message.lowercased()
            if lower.contains("not found") || lower.contains("404") {
                throw BarcodeLookupError.notFound
            }
            throw SpoonacularServiceError.server(message: message)
        }
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
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
        request.setValue("AvoiOS/1.0", forHTTPHeaderField: "User-Agent")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

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
            if let serverError = try? decoder.decode(SpoonacularErrorResponse.self, from: data),
               let message = serverError.error {
                throw SpoonacularServiceError.server(message: message)
            }
            let raw = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw SpoonacularServiceError.server(message: raw)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SpoonacularServiceError.decodingFailed
        }
    }
}
