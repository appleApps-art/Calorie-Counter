import Foundation

struct VoiceFoodTranscribeRequest: Encodable {
    let audioBase64: String
    let audioMimeType: String
}

struct VoiceFoodTranscribeAPIResponse: Decodable {
    let mode: String?
    let model: String?
    let text: String?
    let language: String?
    let error: String?
}

struct VoiceFoodAnalyzeRequest: Encodable {
    let audioBase64: String
    let audioMimeType: String
    let mealType: String?
    let userContext: AIAssistantUserContext?
}

struct VoiceFoodAnalyzeAPIResponse: Decodable {
    let mode: String?
    let model: String?
    let transcription: String?
    let transcriptionLanguage: String?
    let analysis: FoodPhotoAnalyzeAPIAnalysis?
    let message: String?
    let error: String?
}

protocol VoiceFoodTranscriptionServiceProtocol {
    func transcribe(
        audioData: Data,
        mimeType: String
    ) async throws -> VoiceFoodTranscription

    func analyze(
        audioData: Data,
        mimeType: String,
        mealType: MealType,
        userContext: AIAssistantUserContext?
    ) async throws -> VoiceFoodAnalysis
}

final class VoiceFoodTranscriptionService: VoiceFoodTranscriptionServiceProtocol {
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

    func transcribe(
        audioData: Data,
        mimeType: String = "audio/m4a"
    ) async throws -> VoiceFoodTranscription {
        guard !audioData.isEmpty else {
            throw VoiceFoodError.emptyAudio
        }

        let url = try makeURL(path: "/v1/food/transcribe")
        var request = makeJSONRequest(url: url)
        let body = VoiceFoodTranscribeRequest(
            audioBase64: audioData.base64EncodedString(),
            audioMimeType: mimeType
        )
        request.httpBody = try encode(body)

        let (data, http) = try await send(request)
        let decoded: VoiceFoodTranscribeAPIResponse = try decode(data, statusCode: http.statusCode)

        if !(200...299).contains(http.statusCode) {
            throw VoiceFoodError.transcriptionFailed(
                message: decoded.error ?? "HTTP \(http.statusCode)"
            )
        }

        let text = decoded.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw VoiceFoodError.transcriptionFailed(message: decoded.error ?? "Empty transcription")
        }

        return VoiceFoodTranscription(
            text: text,
            language: decoded.language,
            model: decoded.model
        )
    }

    func analyze(
        audioData: Data,
        mimeType: String = "audio/m4a",
        mealType: MealType = .snacks,
        userContext: AIAssistantUserContext? = nil
    ) async throws -> VoiceFoodAnalysis {
        guard !audioData.isEmpty else {
            throw VoiceFoodError.emptyAudio
        }

        let url = try makeURL(path: "/v1/food/analyze-voice")
        var request = makeJSONRequest(url: url)
        let body = VoiceFoodAnalyzeRequest(
            audioBase64: audioData.base64EncodedString(),
            audioMimeType: mimeType,
            mealType: mealType.rawValue,
            userContext: userContext
        )
        request.httpBody = try encode(body)

        let (data, http) = try await send(request)
        let decoded: VoiceFoodAnalyzeAPIResponse = try decode(data, statusCode: http.statusCode)

        if !(200...299).contains(http.statusCode) {
            throw VoiceFoodError.transcriptionFailed(
                message: decoded.error ?? "HTTP \(http.statusCode)"
            )
        }

        guard let analysis = decoded.analysis else {
            throw VoiceFoodError.transcriptionFailed(
                message: decoded.error ?? "No food analysis returned"
            )
        }

        let transcription = (decoded.transcription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcription.isEmpty else {
            throw VoiceFoodError.transcriptionFailed(message: "Empty transcription")
        }

        let resolvedMeal = MealType(rawValue: analysis.mealType ?? "") ?? mealType
        let food = FoodPhotoAnalysis(
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

        return VoiceFoodAnalysis(
            transcription: transcription,
            transcriptionLanguage: decoded.transcriptionLanguage,
            analysis: food
        )
    }

    private func makeURL(path: String) throws -> URL {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw VoiceFoodError.invalidResponse
        }
        components.path = path
        guard let url = components.url else {
            throw VoiceFoodError.invalidResponse
        }
        return url
    }

    private func makeJSONRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AvoiOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 90
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        return request
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw VoiceFoodError.transport(message: error.localizedDescription)
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw VoiceFoodError.transport(message: error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw VoiceFoodError.invalidResponse
        }
        return (data, http)
    }

    private func decode<T: Decodable>(_ data: Data, statusCode: Int) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"
            throw VoiceFoodError.transcriptionFailed(message: raw)
        }
    }
}
