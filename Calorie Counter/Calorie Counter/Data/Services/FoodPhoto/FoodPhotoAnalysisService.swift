import Foundation
import UIKit

struct FoodPhotoAnalyzeRequest: Encodable {
    let imageBase64: String
    let imageMimeType: String
    let mealType: String?
    let note: String?
    let userContext: AIAssistantUserContext?
}

struct FoodPhotoAnalyzeAPIResponse: Decodable {
    let mode: String?
    let model: String?
    let analysis: FoodPhotoAnalyzeAPIAnalysis?
    let message: String?
    let error: String?
    let hasActions: Bool?
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
}

protocol FoodPhotoAnalysisServiceProtocol {
    func analyze(
        imageData: Data,
        mealType: MealType,
        note: String?,
        userContext: AIAssistantUserContext?
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
        userContext: AIAssistantUserContext? = nil
    ) async throws -> FoodPhotoAnalysis {
        let prepared = try FoodPhotoImagePreprocessor.prepareJPEGBase64(from: imageData)
        return try await analyzePrepared(
            base64: prepared.base64,
            mimeType: prepared.mimeType,
            mealType: mealType,
            note: note,
            userContext: userContext
        )
    }

    func analyze(
        image: UIImage,
        mealType: MealType = .snacks,
        note: String? = nil,
        userContext: AIAssistantUserContext? = nil
    ) async throws -> FoodPhotoAnalysis {
        let prepared = try FoodPhotoImagePreprocessor.prepareJPEGBase64(from: image)
        return try await analyzePrepared(
            base64: prepared.base64,
            mimeType: prepared.mimeType,
            mealType: mealType,
            note: note,
            userContext: userContext
        )
    }

    private func analyzePrepared(
        base64: String,
        mimeType: String,
        mealType: MealType,
        note: String?,
        userContext: AIAssistantUserContext?
    ) async throws -> FoodPhotoAnalysis {
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
        request.setValue("AvoiOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 60
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let body = FoodPhotoAnalyzeRequest(
            imageBase64: base64,
            imageMimeType: mimeType,
            mealType: mealType.rawValue,
            note: note,
            userContext: userContext
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
            decoded = try decoder.decode(FoodPhotoAnalyzeAPIResponse.self, from: data)
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
                message: decoded.error ?? "No food analysis returned"
            )
        }

        let resolvedMeal = MealType(rawValue: analysis.mealType ?? "") ?? mealType
        return FoodPhotoAnalysis(
            name: analysis.name,
            mealType: resolvedMeal,
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
            assistantMessage: decoded.message ?? ""
        )
    }
}
