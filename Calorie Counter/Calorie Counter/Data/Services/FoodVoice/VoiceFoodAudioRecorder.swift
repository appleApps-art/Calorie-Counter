import AVFoundation
import Foundation
import Speech

protocol VoiceFoodAudioRecording: AnyObject {
    var isRecording: Bool { get }
    var onPartialTranscript: ((String) -> Void)? { get set }
    var onUtteranceFinal: (() -> Void)? { get set }
    func requestPermission() async -> Bool
    func startRecording() throws
    func stopRecording() throws -> Data
    func cancelRecording()
    func normalizedPower() -> CGFloat
}

enum VoiceDictationText {
    static func combined(existing: String, live: String) -> String {
        let live = live.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        if existing.isEmpty { return live }
        if live.isEmpty { return existing }
        return existing + " " + live
    }
}

final class VoiceConfirmDictation {
    let isRecording = Observable(false)
    let canConfirm = Observable(false)

    var onText: ((String) -> Void)?

    private let recorder: VoiceFoodAudioRecording
    private let transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase
    private var speechEndTask: Task<Void, Never>?
    private var generation = UUID()
    private var lastLive = ""
    private var anchor = ""
    private let combineWithAnchor: Bool

    init(
        recorder: VoiceFoodAudioRecording,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase,
        combineWithAnchor: Bool = false
    ) {
        self.recorder = recorder
        self.transcribeFoodVoiceUseCase = transcribeFoodVoiceUseCase
        self.combineWithAnchor = combineWithAnchor
    }

    func start(anchor: String = "") {
        generation = UUID()
        let request = generation
        Task { @MainActor in
            let granted = await recorder.requestPermission()
            guard granted, request == generation else { return }
            do {
                lastLive = ""
                canConfirm.value = false
                self.anchor = anchor
                recorder.onPartialTranscript = { [weak self] live in
                    guard let self, self.generation == request else { return }
                    let text = live.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    let display = self.displayText(live: text)
                    self.lastLive = display
                    self.onText?(display)
                    self.scheduleSpeechEnd()
                }
                recorder.onUtteranceFinal = { [weak self] in
                    guard let self, self.generation == request else { return }
                    self.finish()
                }
                try recorder.startRecording()
                isRecording.value = true
            } catch {
                clearCallbacks()
            }
        }
    }

    func finish() {
        guard isRecording.value else { return }
        speechEndTask?.cancel()
        speechEndTask = nil

        var audio = Data()
        do {
            audio = try recorder.stopRecording()
        } catch {}
        clearCallbacks()

        let live = lastLive.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty {
            canConfirm.value = true
            isRecording.value = false
            return
        }

        isRecording.value = false
        guard !audio.isEmpty else { return }
        let request = generation
        Task { @MainActor in
            let result = try? await transcribeFoodVoiceUseCase.execute(audioData: audio)
            guard request == generation else { return }
            let text = result?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { return }
            let display = displayText(live: text)
            lastLive = display
            onText?(display)
            canConfirm.value = true
        }
    }

    func cancel() {
        generation = UUID()
        canConfirm.value = false
        speechEndTask?.cancel()
        speechEndTask = nil
        if isRecording.value {
            recorder.cancelRecording()
            isRecording.value = false
        }
        clearCallbacks()
    }

    func consumeConfirm() {
        canConfirm.value = false
    }

    func clearConfirmIfEmpty(_ text: String) {
        if canConfirm.value, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            canConfirm.value = false
        }
    }

    private func scheduleSpeechEnd() {
        speechEndTask?.cancel()
        speechEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func displayText(live: String) -> String {
        if combineWithAnchor {
            return VoiceDictationText.combined(existing: anchor, live: live)
        }
        return live
    }

    private func clearCallbacks() {
        recorder.onPartialTranscript = nil
        recorder.onUtteranceFinal = nil
    }
}

final class VoiceFoodAudioRecorder: NSObject, VoiceFoodAudioRecording {
    var onPartialTranscript: ((String) -> Void)?
    var onUtteranceFinal: (() -> Void)?

    private let session: AVAudioSession
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private var engine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var liveSink: LiveAudioSink?
    private var committedTranscript = ""

    private(set) var isRecording = false

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    func requestPermission() async -> Bool {
        let microphoneGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard microphoneGranted else { return false }
        _ = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        return true
    }

    func startRecording() throws {
        guard !isRecording else { return }

        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw VoiceFoodError.microphoneDenied
        }

        committedTranscript = ""

        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        if SFSpeechRecognizer.authorizationStatus() == .authorized,
           let recognizer = makeSpeechRecognizer() {
            do {
                try startLiveSpeech(recognizer: recognizer)
                isRecording = true
                return
            } catch {
                tearDownLiveSpeech()
            }
        }

        try startFileRecording()
        isRecording = true
    }

    func stopRecording() throws -> Data {
        guard isRecording else {
            throw VoiceFoodError.recordingFailed(message: "Recording is not active")
        }
        isRecording = false

        if recorder != nil {
            return try stopFileRecording()
        }

        tearDownLiveSpeech()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        return Data()
    }

    func cancelRecording() {
        isRecording = false
        if recorder != nil {
            recorder?.stop()
            recorder = nil
            if let url = outputURL {
                try? FileManager.default.removeItem(at: url)
            }
            outputURL = nil
        }
        tearDownLiveSpeech()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func normalizedPower() -> CGFloat {
        if isRecording, let recorder {
            recorder.updateMeters()
            let decibels = recorder.averagePower(forChannel: 0)
            return Self.normalizedPower(decibels: decibels)
        }
        return liveSink?.power() ?? 0
    }

    private func startLiveSpeech(recognizer: SFSpeechRecognizer) throws {
        speechRecognizer = recognizer

        let audioEngine = AVAudioEngine()
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceFoodError.recordingFailed(message: L10n.tr("voice.error.startFailed"))
        }

        let sink = LiveAudioSink()
        liveSink = sink
        beginRecognitionRequest(recognizer: recognizer)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            tearDownLiveSpeech()
            throw VoiceFoodError.recordingFailed(message: L10n.tr("voice.error.startFailed"))
        }
        engine = audioEngine
    }

    private func beginRecognitionRequest(recognizer: SFSpeechRecognizer) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        liveSink?.request = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            Task { @MainActor in
                self?.handleRecognition(result)
            }
        }
    }

    private func handleRecognition(_ result: SFSpeechRecognitionResult?) {
        guard let result else { return }
        let piece = result.bestTranscription.formattedString
        let text = VoiceDictationText.combined(existing: committedTranscript, live: piece)
        onPartialTranscript?(text)
        guard result.isFinal, isRecording else { return }
        committedTranscript = text
        onUtteranceFinal?()
        guard isRecording else { return }
        restartLiveRecognition()
    }

    private func restartLiveRecognition() {
        guard isRecording, let recognizer = speechRecognizer else { return }
        liveSink?.request?.endAudio()
        recognitionTask = nil
        liveSink?.request = nil
        beginRecognitionRequest(recognizer: recognizer)
    }

    private func tearDownLiveSpeech() {
        liveSink?.request?.endAudio()
        liveSink?.request = nil
        liveSink = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            if engine.isRunning {
                engine.stop()
            }
        }
        engine = nil
        speechRecognizer = nil
    }

    private nonisolated final class LiveAudioSink: @unchecked Sendable {
        var request: SFSpeechAudioBufferRecognitionRequest?
        private let lock = NSLock()
        private var currentPower: CGFloat = 0

        func append(_ buffer: AVAudioPCMBuffer) {
            request?.append(buffer)
            let sample = VoiceFoodAudioRecorder.normalizedPower(from: buffer)
            lock.lock()
            if sample > currentPower {
                currentPower = currentPower * 0.35 + sample * 0.65
            } else {
                currentPower = currentPower * 0.82 + sample * 0.18
            }
            lock.unlock()
        }

        func power() -> CGFloat {
            lock.lock()
            defer { lock.unlock() }
            return currentPower
        }
    }

    private func makeSpeechRecognizer() -> SFSpeechRecognizer? {
        var locales: [Locale] = [.autoupdatingCurrent]
        if let language = Locale.autoupdatingCurrent.language.languageCode?.identifier {
            locales.append(Locale(identifier: language))
        }
        locales.append(Locale(identifier: "en-US"))
        for locale in locales {
            if let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable {
                return recognizer
            }
        }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            return nil
        }
        return recognizer
    }

    private func startFileRecording() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bity-voice-\(UUID().uuidString).m4a")
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
    }

    private func stopFileRecording() throws -> Data {
        guard let recorder else {
            throw VoiceFoodError.recordingFailed(message: "Recording is not active")
        }

        recorder.stop()
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

    private static nonisolated func normalizedPower(from buffer: AVAudioPCMBuffer) -> CGFloat {
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        let rms: Float
        if let samples = buffer.floatChannelData?[0] {
            var sum: Float = 0
            for index in 0..<count {
                let sample = samples[index]
                sum += sample * sample
            }
            rms = sqrt(sum / Float(count))
        } else if let samples = buffer.int16ChannelData?[0] {
            var sum: Float = 0
            for index in 0..<count {
                let sample = Float(samples[index]) / Float(Int16.max)
                sum += sample * sample
            }
            rms = sqrt(sum / Float(count))
        } else {
            return 0
        }
        let decibels = 20 * log10(max(rms, 1e-7))
        return normalizedPower(decibels: decibels)
    }

    private static nonisolated func normalizedPower(decibels: Float) -> CGFloat {
        let floor: Float = -50
        let clamped = max(floor, min(0, decibels))
        return CGFloat((clamped - floor) / -floor)
    }
}
