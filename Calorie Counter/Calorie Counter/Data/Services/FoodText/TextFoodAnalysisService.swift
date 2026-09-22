import Foundation

struct TextFoodAnalyzeRequest: Encodable {
    let text: String
    let mealType: String?
    let userContext: AIAssistantUserContext?
}

protocol TextFoodAnalysisServiceProtocol {
    func analyze(
        text: String,
        mealType: MealType,
        userContext: AIAssistantUserContext?
    ) async throws -> FoodPhotoAnalysis
}

final class TextFoodAnalysisService: TextFoodAnalysisServiceProtocol {
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
        text: String,
        mealType: MealType = .snacks,
        userContext: AIAssistantUserContext? = nil
    ) async throws -> FoodPhotoAnalysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FoodPhotoAnalysisError.emptyText
        }
        try NetworkMonitor.shared.requireOnline()

        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw FoodPhotoAnalysisError.invalidResponse
        }
        components.path = "/v1/food/analyze-text"
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

        let body = TextFoodAnalyzeRequest(
            text: trimmed,
            mealType: mealType.rawValue,
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
        return FoodPhotoAnalysisService.mappedAnalysis(
            from: analysis,
            fallbackMealType: resolvedMeal,
            message: decoded.message ?? "",
            defaultSource: analysis.source ?? "text"
        )
    }
}
