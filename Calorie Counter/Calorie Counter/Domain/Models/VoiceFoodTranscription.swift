import Foundation

struct VoiceFoodTranscription: Equatable {
    let text: String
    let language: String?
    let model: String?
}

struct VoiceFoodAnalysis: Equatable {
    let transcription: String
    let transcriptionLanguage: String?
    let analysis: FoodPhotoAnalysis
}

enum VoiceFoodError: LocalizedError, Equatable {
    case emptyAudio
    case recordingFailed(message: String)
    case microphoneDenied
    case invalidResponse
    case transcriptionFailed(message: String)
    case transport(message: String)

    var errorDescription: String? {
        switch self {
        case .emptyAudio:
            return L10n.tr("voice.error.empty")
        case .recordingFailed(let message):
            return message
        case .microphoneDenied:
            return L10n.tr("voice.error.denied")
        case .invalidResponse:
            return L10n.tr("voice.error.invalidResponse")
        case .transcriptionFailed(let message):
            return message
        case .transport(let message):
            return message
        }
    }
}
