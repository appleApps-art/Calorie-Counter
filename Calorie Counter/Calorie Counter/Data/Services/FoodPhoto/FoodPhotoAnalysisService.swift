import Foundation
import UIKit

struct FoodPhotoAnalyzeRequest: Encodable {
    let imageBase64: String
    let imageMimeType: String
    let mealType: String?
    let note: String?
    let userContext: AIAssistantUserContext?
    let inventoryMode: Bool
}

struct FoodPhotoAnalyzeAPIResponse: Decodable {
    let mode: String?
    let model: String?
    let analysis: FoodPhotoAnalyzeAPIAnalysis?
    let message: String?
    let error: String?
    let hasActions: Bool?
}

struct FoodPhotoAnalyzeAPIIngredient: Decodable {
    let name: String
    let grams: Double?
    let milliliters: Double?
    let quantity: String?

    init(name: String, grams: Double?, milliliters: Double?, quantity: String? = nil) {
        self.name = name
        self.grams = grams
        self.milliliters = milliliters
        self.quantity = quantity
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
            name = text
            grams = nil
            milliliters = nil
            quantity = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        grams = decodeFlexibleDouble(container, forKey: .grams)
        milliliters = decodeFlexibleDouble(container, forKey: .milliliters)
        let label = (try? container.decodeIfPresent(String.self, forKey: .quantity))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        quantity = (label?.isEmpty ?? true) ? nil : label
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case grams
        case milliliters
        case quantity
    }
}

struct FoodPhotoAnalyzeAPIAlternative: Decodable {
    let name: String
    let summary: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double?
    let sugar: Double?
    let sodium: Double?
    let portionGrams: Double?
    let portionMilliliters: Double?
    let servingLabel: String?
    let tags: [String]?
    let ingredients: [FoodPhotoAnalyzeAPIIngredient]?
    let foodType: FoodType?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = (try container.decodeIfPresent(String.self, forKey: .name) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing alternative name")
            )
        }
        self.name = name
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        calories = decodeFlexibleDouble(container, forKey: .calories) ?? 0
        protein = decodeFlexibleDouble(container, forKey: .protein) ?? 0
        carbs = decodeFlexibleDouble(container, forKey: .carbs) ?? 0
        fats = decodeFlexibleDouble(container, forKey: .fats) ?? 0
        fiber = decodeFlexibleDouble(container, forKey: .fiber)
        sugar = decodeFlexibleDouble(container, forKey: .sugar)
        sodium = decodeFlexibleDouble(container, forKey: .sodium)
        portionGrams = decodeFlexibleDouble(container, forKey: .portionGrams)
        portionMilliliters = decodeFlexibleDouble(container, forKey: .portionMilliliters)
        servingLabel = try container.decodeIfPresent(String.self, forKey: .servingLabel)
        tags = decodeFlexibleStringList(container, forKey: .tags)
        ingredients = try? container.decodeIfPresent([FoodPhotoAnalyzeAPIIngredient].self, forKey: .ingredients)
        foodType = try container.decodeIfPresent(String.self, forKey: .foodType).flatMap(FoodType.init(rawValue:))
    }

    private enum CodingKeys: String, CodingKey {
        case name, summary, calories, protein, carbs, fats, fiber, sugar, sodium, foodType
        case portionGrams, portionMilliliters, servingLabel, tags, ingredients
    }
}

struct FoodPhotoAnalyzeAPIAnalysis: Decodable {
    let name: String
    let mealType: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fats: Double
    let fiber: Double?
    let sugar: Double?
    let sodium: Double?
    let portionGrams: Double?
    let portionMilliliters: Double?
    let confidence: Double?
    let notes: String?
    let source: String?
    let servingLabel: String?
    let tags: [String]?
    let ingredients: [FoodPhotoAnalyzeAPIIngredient]?
    let foodType: FoodType?
    let alternative: FoodPhotoAnalyzeAPIAlternative?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = (try container.decodeIfPresent(String.self, forKey: .name) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing food name")
            )
        }
        self.name = name
        mealType = try container.decodeIfPresent(String.self, forKey: .mealType)
        calories = decodeFlexibleDouble(container, forKey: .calories) ?? 0
        protein = decodeFlexibleDouble(container, forKey: .protein) ?? 0
        carbs = decodeFlexibleDouble(container, forKey: .carbs) ?? 0
        fats = decodeFlexibleDouble(container, forKey: .fats) ?? 0
        fiber = decodeFlexibleDouble(container, forKey: .fiber)
        sugar = decodeFlexibleDouble(container, forKey: .sugar)
        sodium = decodeFlexibleDouble(container, forKey: .sodium)
        portionGrams = decodeFlexibleDouble(container, forKey: .portionGrams)
        portionMilliliters = decodeFlexibleDouble(container, forKey: .portionMilliliters)
        confidence = decodeFlexibleDouble(container, forKey: .confidence)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        servingLabel = try container.decodeIfPresent(String.self, forKey: .servingLabel)
        tags = decodeFlexibleStringList(container, forKey: .tags)
        ingredients = try? container.decodeIfPresent([FoodPhotoAnalyzeAPIIngredient].self, forKey: .ingredients)
        foodType = try container.decodeIfPresent(String.self, forKey: .foodType).flatMap(FoodType.init(rawValue:))
        alternative = try? container.decodeIfPresent(FoodPhotoAnalyzeAPIAlternative.self, forKey: .alternative)
    }

    private enum CodingKeys: String, CodingKey {
        case name, mealType, calories, protein, carbs, fats, fiber, sugar, sodium
        case portionGrams, portionMilliliters, confidence, notes, source, servingLabel
        case tags, ingredients, alternative, foodType
    }
}

private func decodeFlexibleDouble<K: CodingKey>(
    _ container: KeyedDecodingContainer<K>,
    forKey key: K
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

private func decodeFlexibleStringList<K: CodingKey>(
    _ container: KeyedDecodingContainer<K>,
    forKey key: K
) -> [String]? {
    if let values = try? container.decodeIfPresent([String].self, forKey: key) {
        return values
    }
    if let value = try? container.decodeIfPresent(String.self, forKey: key) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
    }
    return []
}

protocol FoodPhotoAnalysisServiceProtocol {
    func analyze(
        imageData: Data,
        mealType: MealType,
        note: String?,
        userContext: AIAssistantUserContext?,
        inventoryMode: Bool
    ) async throws -> FoodPhotoAnalysis
}

final class FoodPhotoAnalysisService: FoodPhotoAnalysisServiceProtocol {
    private let configuration: AIAssistantAPIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        configuration: AIAssistantAPIConfiguration = .production,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func analyze(
        imageData: Data,
        mealType: MealType = .snacks,
        note: String? = nil,
        userContext: AIAssistantUserContext? = nil,
        inventoryMode: Bool = false
    ) async throws -> FoodPhotoAnalysis {
        let prepared = try FoodPhotoImagePreprocessor.prepareJPEGBase64(
            from: imageData,
            maxDimension: inventoryMode ? 1600 : 1280,
            compressionQuality: inventoryMode ? 0.82 : 0.72
        )
        return try await analyzePrepared(
            base64: prepared.base64,
            mimeType: prepared.mimeType,
            mealType: mealType,
            note: note,
            userContext: userContext,
            inventoryMode: inventoryMode
        )
    }

    func analyze(
        image: UIImage,
        mealType: MealType = .snacks,
        note: String? = nil,
        userContext: AIAssistantUserContext? = nil,
        inventoryMode: Bool = false
    ) async throws -> FoodPhotoAnalysis {
        let prepared = try FoodPhotoImagePreprocessor.prepareJPEGBase64(
            from: image,
            maxDimension: inventoryMode ? 1600 : 1280,
            compressionQuality: inventoryMode ? 0.82 : 0.72
        )
        return try await analyzePrepared(
            base64: prepared.base64,
            mimeType: prepared.mimeType,
            mealType: mealType,
            note: note,
            userContext: userContext,
            inventoryMode: inventoryMode
        )
    }

    private func analyzePrepared(
        base64: String,
        mimeType: String,
        mealType: MealType,
        note: String?,
        userContext: AIAssistantUserContext?,
        inventoryMode: Bool
    ) async throws -> FoodPhotoAnalysis {
        try NetworkMonitor.shared.requireOnline()
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        components.path = "/v1/food/analyze-photo"
        guard let url = components.url else {
            throw FoodPhotoAnalysisError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BityiOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let body = FoodPhotoAnalyzeRequest(
            imageBase64: base64,
            imageMimeType: mimeType,
            mealType: mealType.rawValue,
            note: note,
            userContext: userContext,
            inventoryMode: inventoryMode
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

        let decoded: FoodPhotoAnalyzeAPIResponse
        do {
            decoded = try FoodPhotoAnalyzeAPIResponse.decode(from: data, using: decoder)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw FoodPhotoAnalysisError.analysisFailed(message: raw)
        }

        if !(200...299).contains(http.statusCode) {
            throw FoodPhotoAnalysisError.analysisFailed(
                message: decoded.error ?? "HTTP \(http.statusCode)"
            )
        }

        guard let analysis = decoded.analysis else {
            throw FoodPhotoAnalysisError.analysisFailed(
                message: L10n.tr("photo.error.analysisFailed")
            )
        }

        let resolvedMeal = MealType(rawValue: analysis.mealType ?? "") ?? mealType
        return Self.mappedAnalysis(
            from: analysis,
            fallbackMealType: resolvedMeal,
            message: decoded.message ?? "",
            defaultSource: analysis.source ?? "photo"
        )
    }

    static func mappedAnalysis(
        from analysis: FoodPhotoAnalyzeAPIAnalysis,
        fallbackMealType: MealType,
        message: String,
        defaultSource: String
    ) -> FoodPhotoAnalysis {
        FoodPhotoAnalysis(
            name: analysis.name,
            mealType: fallbackMealType,
            calories: analysis.calories,
            protein: analysis.protein,
            carbs: analysis.carbs,
            fats: analysis.fats,
            fiber: analysis.fiber ?? 0,
            sugar: analysis.sugar ?? 0,
            sodium: analysis.sodium ?? 0,
            portionGrams: analysis.portionGrams,
            portionMilliliters: analysis.portionMilliliters,
            confidence: analysis.confidence ?? 0.5,
            notes: analysis.notes ?? "",
            assistantMessage: message,
            servingLabel: analysis.servingLabel ?? "",
            ingredients: ingredients(from: analysis.ingredients),
            tags: analysis.tags ?? [],
            suggestion: suggestion(from: analysis.alternative),
            source: analysis.source ?? defaultSource,
            foodType: analysis.foodType
        )
    }

    static func ingredients(from items: [FoodPhotoAnalyzeAPIIngredient]?) -> [FoodIngredient] {
        (items ?? []).compactMap { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            if let parsed = ProductDetailsMath.parseIngredientLine(name), parsed.grams != nil || parsed.milliliters != nil {
                return FoodIngredient(
                    name: parsed.name,
                    grams: item.grams ?? parsed.grams,
                    milliliters: item.milliliters ?? parsed.milliliters,
                    quantityText: item.quantity
                )
            }
            return FoodIngredient(name: name, grams: item.grams, milliliters: item.milliliters, quantityText: item.quantity)
        }
    }

    private static func suggestion(from alternative: FoodPhotoAnalyzeAPIAlternative?) -> FoodHealthSuggestion? {
        guard let alternative else { return nil }
        return FoodHealthSuggestion(
            name: alternative.name,
            summary: alternative.summary ?? "",
            calories: alternative.calories,
            protein: alternative.protein,
            carbs: alternative.carbs,
            fats: alternative.fats,
            fiber: alternative.fiber ?? 0,
            sugar: alternative.sugar ?? 0,
            sodium: alternative.sodium ?? 0,
            portionGrams: alternative.portionGrams,
            portionMilliliters: alternative.portionMilliliters,
            servingLabel: alternative.servingLabel ?? "",
            ingredients: ingredients(from: alternative.ingredients),
            tags: alternative.tags ?? [],
            foodType: alternative.foodType
        )
    }
}

extension FoodPhotoAnalyzeAPIResponse {
    static func decode(from data: Data, using decoder: JSONDecoder) throws -> FoodPhotoAnalyzeAPIResponse {
        if let decoded = try? decoder.decode(FoodPhotoAnalyzeAPIResponse.self, from: data) {
            return decoded
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        if let analysis = decodeAnalysis(root["analysis"], decoder: decoder) {
            return FoodPhotoAnalyzeAPIResponse(
                mode: root["mode"] as? String,
                model: root["model"] as? String,
                analysis: analysis,
                message: root["message"] as? String,
                error: root["error"] as? String,
                hasActions: root["hasActions"] as? Bool
            )
        }
        return try decoder.decode(FoodPhotoAnalyzeAPIResponse.self, from: data)
    }

    private static func decodeAnalysis(_ raw: Any?, decoder: JSONDecoder) -> FoodPhotoAnalyzeAPIAnalysis? {
        guard let raw else { return nil }
        if let text = raw as? String, let nested = text.data(using: .utf8) {
            return try? decoder.decode(FoodPhotoAnalyzeAPIAnalysis.self, from: nested)
        }
        guard let dict = raw as? [String: Any] else { return nil }
        if JSONSerialization.isValidJSONObject(dict),
           let encoded = try? JSONSerialization.data(withJSONObject: dict),
           let decoded = try? decoder.decode(FoodPhotoAnalyzeAPIAnalysis.self, from: encoded) {
            return decoded
        }
        let name = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return nil }
        let slim: [String: Any] = [
            "name": name,
            "mealType": dict["mealType"] as? String ?? "",
            "calories": dict["calories"] ?? 0,
            "protein": dict["protein"] ?? 0,
            "carbs": dict["carbs"] ?? 0,
            "fats": dict["fats"] ?? dict["fat"] ?? 0,
            "fiber": dict["fiber"] ?? 0,
            "sugar": dict["sugar"] ?? 0,
            "sodium": dict["sodium"] ?? 0,
            "portionGrams": dict["portionGrams"] ?? NSNull(),
            "portionMilliliters": dict["portionMilliliters"] ?? NSNull(),
            "confidence": dict["confidence"] ?? 0.5,
            "notes": dict["notes"] as? String ?? "",
            "source": dict["source"] as? String ?? "photo",
            "servingLabel": dict["servingLabel"] as? String ?? ""
        ]
        guard JSONSerialization.isValidJSONObject(slim),
              let encoded = try? JSONSerialization.data(withJSONObject: slim) else {
            return nil
        }
        return try? decoder.decode(FoodPhotoAnalyzeAPIAnalysis.self, from: encoded)
    }
}
