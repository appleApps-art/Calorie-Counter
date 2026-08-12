import Foundation

final class AnalyzeVoiceFoodUseCase {
    private let voiceFoodTranscriptionService: VoiceFoodTranscriptionServiceProtocol
    private let buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase

    init(
        voiceFoodTranscriptionService: VoiceFoodTranscriptionServiceProtocol,
        buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase
    ) {
        self.voiceFoodTranscriptionService = voiceFoodTranscriptionService
        self.buildAIAssistantUserContextUseCase = buildAIAssistantUserContextUseCase
    }

    func execute(
        audioData: Data,
        mimeType: String = "audio/m4a",
        mealType: MealType = .snacks,
        includeDiaryContext: Bool = true
    ) async throws -> VoiceFoodAnalysis {
        let context = includeDiaryContext ? try buildAIAssistantUserContextUseCase.execute() : nil
        return try await voiceFoodTranscriptionService.analyze(
            audioData: audioData,
            mimeType: mimeType,
            mealType: mealType,
            userContext: context
        )
    }
}
