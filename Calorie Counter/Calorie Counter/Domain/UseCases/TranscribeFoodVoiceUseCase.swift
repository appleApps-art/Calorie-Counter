import Foundation

final class TranscribeFoodVoiceUseCase {
    private let voiceFoodTranscriptionService: VoiceFoodTranscriptionServiceProtocol

    init(voiceFoodTranscriptionService: VoiceFoodTranscriptionServiceProtocol) {
        self.voiceFoodTranscriptionService = voiceFoodTranscriptionService
    }

    func execute(audioData: Data, mimeType: String = "audio/m4a") async throws -> VoiceFoodTranscription {
        try await voiceFoodTranscriptionService.transcribe(
            audioData: audioData,
            mimeType: mimeType
        )
    }
}
