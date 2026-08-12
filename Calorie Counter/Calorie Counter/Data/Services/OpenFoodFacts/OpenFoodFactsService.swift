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
            return "Invalid Open Food Facts URL"
        case .invalidResponse:
            return "Invalid Open Food Facts response"
        case .notFound:
            return "Product not found"
        case .decodingFailed:
            return "Failed to decode Open Food Facts response"
        case .transport(let underlying):
            return underlying.localizedDescription
        }
    }
}

struct OpenFoodFactsProductResponse: Decodable {
    let status: Int?
    let code: String?
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Decodable {
    let productName: String?
    let productNameEn: String?
    let brands: String?
    let quantity: String?
    let servingSize: String?
    let imageUrl: String?
    let imageFrontUrl: String?
    let nutriments: OpenFoodFactsNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNameEn = "product_name_en"
        case brands
        case quantity
        case servingSize = "serving_size"
        case imageUrl = "image_url"
        case imageFrontUrl = "image_front_url"
        case nutriments
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

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteins100g = "proteins_100g"
        case proteinsServing = "proteins_serving"
        case carbohydrates100g = "carbohydrates_100g"
        case carbohydratesServing = "carbohydrates_serving"
        case fat100g = "fat_100g"
        case fatServing = "fat_serving"
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

final class OpenFoodFactsService: BarcodeProductLookingUp {
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
                value: "code,product_name,product_name_en,brands,quantity,serving_size,image_url,image_front_url,nutriments"
            )
        ]
        guard let url = components.url else {
            throw OpenFoodFactsServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("AvoCalorieCounter/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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

        let decoded: OpenFoodFactsProductResponse
        do {
            decoded = try decoder.decode(OpenFoodFactsProductResponse.self, from: data)
        } catch {
            throw OpenFoodFactsServiceError.decodingFailed
        }

        guard decoded.status == 1, let product = decoded.product else {
            throw BarcodeLookupError.notFound
        }

        let name = [product.productName, product.productNameEn]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
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
            source: .openFoodFacts
        )
    }
}
