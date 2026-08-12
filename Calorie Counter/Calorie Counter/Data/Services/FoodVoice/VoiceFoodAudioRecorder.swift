import AVFoundation
import Foundation

protocol VoiceFoodAudioRecording: AnyObject {
    var isRecording: Bool { get }
    func requestPermission() async -> Bool
    func startRecording() throws
    func stopRecording() throws -> Data
    func cancelRecording()
}

final class VoiceFoodAudioRecorder: NSObject, VoiceFoodAudioRecording {
    private let session: AVAudioSession
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?

    private(set) var isRecording = false

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws {
        guard !isRecording else { return }

        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw VoiceFoodError.microphoneDenied
        }

        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("avo-voice-\(UUID().uuidString).m4a")
        outputURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder.isMeteringEnabled = true
        guard audioRecorder.prepareToRecord(), audioRecorder.record() else {
            throw VoiceFoodError.recordingFailed(message: L10n.tr("voice.error.startFailed"))
        }

        recorder = audioRecorder
        isRecording = true
    }

    func stopRecording() throws -> Data {
        guard isRecording, let recorder else {
            throw VoiceFoodError.recordingFailed(message: "Recording is not active")
        }

        recorder.stop()
        isRecording = false
        self.recorder = nil

        defer {
            outputURL = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }

        guard let url = outputURL else {
            throw VoiceFoodError.emptyAudio
        }

        let data = try Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        guard !data.isEmpty else {
            throw VoiceFoodError.emptyAudio
        }
        return data
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }
        outputURL = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
