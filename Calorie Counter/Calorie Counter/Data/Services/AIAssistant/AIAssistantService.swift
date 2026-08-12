import Foundation

protocol AIAssistantServiceProtocol {
    func chat(_ request: AIAssistantChatRequest) async throws -> AIAssistantChatResponse
}

final class AIAssistantService: AIAssistantServiceProtocol {
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

    func chat(_ request: AIAssistantChatRequest) async throws -> AIAssistantChatResponse {
        guard let url = URL(string: "/v1/chat", relativeTo: configuration.baseURL)?.absoluteURL else {
            throw AIAssistantServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("AvoiOS/1.0", forHTTPHeaderField: "User-Agent")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AIAssistantServiceError.transport(underlying: error)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw AIAssistantServiceError.transport(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIAssistantServiceError.invalidResponse
        }

        if !(200...299).contains(http.statusCode) {
            if let serverError = try? decoder.decode(AIAssistantChatResponse.self, from: data),
               let message = serverError.error {
                throw AIAssistantServiceError.server(message: message)
            }
            let raw = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw AIAssistantServiceError.server(message: raw)
        }

        do {
            let decoded = try decoder.decode(AIAssistantChatResponse.self, from: data)
            if let error = decoded.error, !error.isEmpty {
                throw AIAssistantServiceError.server(message: error)
            }
            return decoded
        } catch let error as AIAssistantServiceError {
            throw error
        } catch {
            throw AIAssistantServiceError.decodingFailed
        }
    }
}
