import Foundation

struct OpenFoodFactsAPIConfiguration {
    let baseURL: URL

    static let production = OpenFoodFactsAPIConfiguration(
        baseURL: URL(string: "https://world.openfoodfacts.org")!
    )
}

enum OpenFoodFactsServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case decodingFailed
    case transport(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L10n.tr("common.errorGeneric")
        case .invalidResponse:
            return L10n.tr("common.errorGeneric")
        case .notFound:
            return L10n.tr("barcode.error.notFound")
        case .decodingFailed:
            return L10n.tr("common.errorGeneric")
        case .transport(let underlying):
            return underlying.localizedDescription
        }
    }
}

protocol OpenFoodFactsSearching {
    func searchProducts(query: String, number: Int) async throws -> [FoodProduct]
    func searchCategory(tag: String, number: Int) async throws -> [FoodProduct]
    func lookup(barcode: String) async throws -> BarcodeProduct
}

struct OpenFoodFactsProductResponse: Decodable {
    let status: Int?
    let code: String?
    let product: OpenFoodFactsProduct?
}

/// Open Food Facts keeps a name per language ("product_name_fr", "product_name_ja", ...).
struct OpenFoodFactsNameKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }

    static var appLanguage: OpenFoodFactsNameKey? {
        OpenFoodFactsNameKey(stringValue: "product_name_\(OpenFoodFactsLocalizedName.appLanguageCode)")
    }
}

struct OpenFoodFactsProduct: Decodable {
    let productName: String?
    let productNameEn: String?
    let productNameUk: String?
    /// The name in the app's own language, when the product has one.
    let productNameLocal: String?
    let brands: String?
    let quantity: String?
    let servingSize: String?
    let imageUrl: String?
    let imageFrontUrl: String?
    let nutriments: OpenFoodFactsNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNameEn = "product_name_en"
        case productNameUk = "product_name_uk"
        case brands
        case quantity
        case servingSize = "serving_size"
        case imageUrl = "image_url"
        case imageFrontUrl = "image_front_url"
        case nutriments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        productNameEn = try container.decodeIfPresent(String.self, forKey: .productNameEn)
        productNameUk = try container.decodeIfPresent(String.self, forKey: .productNameUk)
        brands = try container.decodeIfPresent(String.self, forKey: .brands)
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity)
        servingSize = try container.decodeIfPresent(String.self, forKey: .servingSize)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        imageFrontUrl = try container.decodeIfPresent(String.self, forKey: .imageFrontUrl)
        nutriments = try container.decodeIfPresent(OpenFoodFactsNutriments.self, forKey: .nutriments)
        let names = try decoder.container(keyedBy: OpenFoodFactsNameKey.self)
        productNameLocal = OpenFoodFactsNameKey.appLanguage.flatMap { try? names.decodeIfPresent(String.self, forKey: $0) }
    }
}

struct OpenFoodFactsSearchResponse: Decodable {
    let products: [OpenFoodFactsSearchItem]?
}

struct OpenFoodFactsSearchItem: Decodable {
    let code: String?
    let productName: String?
    let productNameEn: String?
    let productNameUk: String?
    let productNameLocal: String?
    let brands: String?
    let imageUrl: String?
    let imageFrontUrl: String?
    let nutriments: OpenFoodFactsNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case id = "_id"
        case productName = "product_name"
        case productNameEn = "product_name_en"
        case productNameUk = "product_name_uk"
        case brands
        case imageUrl = "image_url"
        case imageFrontUrl = "image_front_url"
        case nutriments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = Self.decodeFlexibleString(container, key: .code)
            ?? Self.decodeFlexibleString(container, key: .id)
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        productNameEn = try container.decodeIfPresent(String.self, forKey: .productNameEn)
        productNameUk = try container.decodeIfPresent(String.self, forKey: .productNameUk)
        brands = try container.decodeIfPresent(String.self, forKey: .brands)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        imageFrontUrl = try container.decodeIfPresent(String.self, forKey: .imageFrontUrl)
        nutriments = try container.decodeIfPresent(OpenFoodFactsNutriments.self, forKey: .nutriments)
        let names = try decoder.container(keyedBy: OpenFoodFactsNameKey.self)
        productNameLocal = OpenFoodFactsNameKey.appLanguage.flatMap { try? names.decodeIfPresent(String.self, forKey: $0) }
    }

    private static func decodeFlexibleString(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}

struct OpenFoodFactsNutriments: Decodable {
    let energyKcal100g: Double?
    let energyKcalServing: Double?
    let proteins100g: Double?
    let proteinsServing: Double?
    let carbohydrates100g: Double?
    let carbohydratesServing: Double?
    let fat100g: Double?
    let fatServing: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let sodium100g: Double?
    let fiberServing: Double?
    let sugarsServing: Double?
    let sodiumServing: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteins100g = "proteins_100g"
        case proteinsServing = "proteins_serving"
        case carbohydrates100g = "carbohydrates_100g"
        case carbohydratesServing = "carbohydrates_serving"
        case fat100g = "fat_100g"
        case fatServing = "fat_serving"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
        case fiberServing = "fiber_serving"
        case sugarsServing = "sugars_serving"
        case sodiumServing = "sodium_serving"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        energyKcal100g = Self.decodeFlexibleDouble(container, key: .energyKcal100g)
        energyKcalServing = Self.decodeFlexibleDouble(container, key: .energyKcalServing)
        proteins100g = Self.decodeFlexibleDouble(container, key: .proteins100g)
        proteinsServing = Self.decodeFlexibleDouble(container, key: .proteinsServing)
        carbohydrates100g = Self.decodeFlexibleDouble(container, key: .carbohydrates100g)
        carbohydratesServing = Self.decodeFlexibleDouble(container, key: .carbohydratesServing)
        fat100g = Self.decodeFlexibleDouble(container, key: .fat100g)
        fatServing = Self.decodeFlexibleDouble(container, key: .fatServing)
        fiber100g = Self.decodeFlexibleDouble(container, key: .fiber100g)
        sugars100g = Self.decodeFlexibleDouble(container, key: .sugars100g)
        sodium100g = Self.decodeFlexibleDouble(container, key: .sodium100g)
        fiberServing = Self.decodeFlexibleDouble(container, key: .fiberServing)
        sugarsServing = Self.decodeFlexibleDouble(container, key: .sugarsServing)
        sodiumServing = Self.decodeFlexibleDouble(container, key: .sodiumServing)
    }

    private static func decodeFlexibleDouble(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(value.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}

final class OpenFoodFactsService: BarcodeProductLookingUp, OpenFoodFactsSearching {
    private let configuration: OpenFoodFactsAPIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        configuration: OpenFoodFactsAPIConfiguration = .production,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.decoder = JSONDecoder()
    }

    func lookup(barcode: String) async throws -> BarcodeProduct {
        guard let normalized = BarcodeNormalization.normalize(barcode) else {
            throw BarcodeLookupError.invalidBarcode
        }
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw OpenFoodFactsServiceError.invalidURL
        }
        components.path = "/api/v2/product/\(normalized).json"
        components.queryItems = [
            URLQueryItem(
                name: "fields",
                value: "code,\(OpenFoodFactsLocalizedName.nameFields),brands,quantity,serving_size,image_url,image_front_url,nutriments"
            )
        ]
        guard let url = components.url else {
            throw OpenFoodFactsServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("BityCalorieCounter/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // A product scanned once is found again without a connection.
        let data = try await OfflineFallback.data(for: request) { [session] in
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw OpenFoodFactsServiceError.transport(underlying: error)
            }

            guard let http = response as? HTTPURLResponse else {
                throw OpenFoodFactsServiceError.invalidResponse
            }
            if http.statusCode == 404 {
                throw BarcodeLookupError.notFound
            }
            guard (200...299).contains(http.statusCode) else {
                throw OpenFoodFactsServiceError.invalidResponse
            }
            return data
        }

        let decoded: OpenFoodFactsProductResponse
        do {
            decoded = try decoder.decode(OpenFoodFactsProductResponse.self, from: data)
        } catch {
            throw OpenFoodFactsServiceError.decodingFailed
        }

        guard decoded.status == 1, let product = decoded.product else {
            throw BarcodeLookupError.notFound
        }

        let name = OpenFoodFactsLocalizedName.pick(
            productName: product.productName,
            productNameEn: product.productNameEn,
            productNameUk: product.productNameUk,
            productNameLocal: product.productNameLocal
        )
        guard let name else {
            throw BarcodeLookupError.notFound
        }

        let nutrients = product.nutriments
        let image = product.imageFrontUrl ?? product.imageUrl

        return BarcodeProduct(
            id: UUID(),
            barcode: normalized,
            name: name,
            brand: product.brands?.trimmingCharacters(in: .whitespacesAndNewlines),
            quantityLabel: product.quantity,
            servingSizeLabel: product.servingSize,
            imageURL: image.flatMap(URL.init(string:)),
            caloriesPer100g: nutrients?.energyKcal100g,
            proteinPer100g: nutrients?.proteins100g,
            carbsPer100g: nutrients?.carbohydrates100g,
            fatsPer100g: nutrients?.fat100g,
            caloriesPerServing: nutrients?.energyKcalServing,
            proteinPerServing: nutrients?.proteinsServing,
            carbsPerServing: nutrients?.carbohydratesServing,
            fatsPerServing: nutrients?.fatServing,
            source: .openFoodFacts,
            fiberPer100g: nutrients?.fiber100g,
            sugarPer100g: nutrients?.sugars100g,
            sodiumPer100g: nutrients?.sodium100g.map { $0 * 1000 },
            fiberPerServing: nutrients?.fiberServing,
            sugarPerServing: nutrients?.sugarsServing,
            sodiumPerServing: nutrients?.sodiumServing.map { $0 * 1000 }
        )
    }

    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw OpenFoodFactsServiceError.invalidURL
        }
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(min(max(number, 1), 20))),
            URLQueryItem(name: "fields", value: Self.searchFields),
        ]
        guard let url = components.url else {
            throw OpenFoodFactsServiceError.invalidURL
        }
        return try await fetchSearchProducts(url: url)
    }

    func searchCategory(tag: String, number: Int) async throws -> [FoodProduct] {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw OpenFoodFactsServiceError.invalidURL
        }
        components.path = "/api/v2/search"
        components.queryItems = [
            URLQueryItem(name: "categories_tags", value: trimmed),
            URLQueryItem(name: "fields", value: Self.searchFields),
            URLQueryItem(name: "page_size", value: String(min(max(number, 1), 24))),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
        ]
        guard let url = components.url else {
            throw OpenFoodFactsServiceError.invalidURL
        }
        return try await fetchSearchProducts(url: url)
    }

    private static var searchFields: String {
        "code,\(OpenFoodFactsLocalizedName.nameFields),brands,image_url,image_front_url,nutriments"
    }

    private func fetchSearchProducts(url: URL) async throws -> [FoodProduct] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("BityCalorieCounter/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data = try await OfflineFallback.data(for: request) { [session] in
            var lastError: OpenFoodFactsServiceError = .invalidResponse
            for _ in 0..<2 {
                let data: Data
                let response: URLResponse
                do {
                    (data, response) = try await session.data(for: request)
                } catch {
                    lastError = .transport(underlying: error)
                    continue
                }

                guard let http = response as? HTTPURLResponse else {
                    lastError = .invalidResponse
                    continue
                }
                if http.statusCode == 429 || http.statusCode == 503 {
                    lastError = .invalidResponse
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    continue
                }
                guard (200...299).contains(http.statusCode) else {
                    throw OpenFoodFactsServiceError.invalidResponse
                }
                return data
            }
            throw lastError
        }

        let decoded: OpenFoodFactsSearchResponse
        do {
            decoded = try decoder.decode(OpenFoodFactsSearchResponse.self, from: data)
        } catch {
            throw OpenFoodFactsServiceError.decodingFailed
        }
        return (decoded.products ?? []).compactMap(Self.mapSearchProduct)
    }

    private static func mapSearchProduct(_ item: OpenFoodFactsSearchItem) -> FoodProduct? {
        let name = OpenFoodFactsLocalizedName.pick(
            productName: item.productName,
            productNameEn: item.productNameEn,
            productNameUk: item.productNameUk,
            productNameLocal: item.productNameLocal
        ).flatMap(decodedText)
        guard let name else { return nil }
        let barcode = item.code?.filter(\.isNumber)
        guard let barcode, !barcode.isEmpty else { return nil }
        guard let calories = item.nutriments?.energyKcal100g else { return nil }
        let image = item.imageFrontUrl ?? item.imageUrl
        return FoodProduct(
            id: UUID(),
            externalId: barcode,
            name: name,
            brand: decodedText(item.brands),
            kind: .product,
            imageURL: image.flatMap { FoodImageURL.isPlaceholder($0) ? nil : URL(string: $0) },
            calories: calories,
            protein: item.nutriments?.proteins100g,
            carbs: item.nutriments?.carbohydrates100g,
            fats: item.nutriments?.fat100g,
            fiber: item.nutriments?.fiber100g,
            sugar: item.nutriments?.sugars100g,
            sodium: item.nutriments?.sodium100g.map { $0 * 1000 },
            amount: 100,
            unit: "g",
            source: .openFoodFacts,
            foodType: .product
        )
    }

    private static func decodedText(_ raw: String?) -> String? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        let replacements = [
            "&quot;": "\"",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&#39;": "'",
            "&apos;": "'",
            "&nbsp;": " ",
        ]
        for (from, to) in replacements {
            text = text.replacingOccurrences(of: from, with: to)
        }
        return text
    }
}

enum OpenFoodFactsLocalizedName {
    /// The language Open Food Facts should name products in: the one the app is shown in.
    static var appLanguageCode: String {
        let raw = Bundle.main.preferredLocalizations.first ?? "en"
        return raw.split(separator: "-").first.map { String($0).lowercased() } ?? "en"
    }

    static var nameFields: String {
        let local = appLanguageCode
        return ["product_name", "product_name_en", "product_name_uk", local == "en" || local == "uk" ? nil : "product_name_\(local)"]
            .compactMap { $0 }
            .joined(separator: ",")
    }

    static func pick(
        productName: String?,
        productNameEn: String?,
        productNameUk: String?,
        productNameLocal: String? = nil,
        locale: String = Locale.deviceIdentifier
    ) -> String? {
        let language = locale
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first
            .map(String.init)?
            .lowercased() ?? "en"
        let ranked: [String?]
        if language == "uk" {
            ranked = [productNameUk, productName, productNameEn]
        } else if language == "en" {
            ranked = [productNameEn, productName, productNameUk]
        } else {
            ranked = [productNameLocal, productName, productNameEn, productNameUk]
        }
        return ranked
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            .first
    }
}
