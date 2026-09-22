import UIKit

enum VoiceLogPhase: Equatable {
    case idle
    case listening
    case recorded
    case result
}

final class VoiceFoodLoggingViewModel {
    let phase = Observable(VoiceLogPhase.idle)
    let statusText = Observable(L10n.tr("voice.tapAndSpeak"))
    let transcriptText = Observable("")
    let isRecording = Observable(false)
    let isTranscribing = Observable(false)
    let isAnalyzing = Observable(false)
    let canAnalyze = Observable(false)
    let analysis = Observable<FoodPhotoAnalysis?>(nil)
    let showsFullDetails = Observable(false)
    /// A picture of the recognized dish; a spoken meal has no photo of its own. It is the same
    /// picture the details screen shows for it.
    let resultImage = Observable<UIImage?>(nil)
    let isResultImageLoading = Observable(false)

    var onClose: (() -> Void)?
    var onViewDetails: ((ProductDetailsDraft) -> Void)?
    var onAddEntry: ((ProductDetailsDraft) -> Void)?

    private let recorder: VoiceFoodAudioRecording
    private let transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase
    private let analyzeTextFoodUseCase: AnalyzeTextFoodUseCase
    private let selectedMealType: MealType
    private let diaryDate: Date
    private var activeTask: Task<Void, Never>?
    private var receivedLiveVoice = false
    private var silenceTimer: Timer?
    private var lastVoiceAt: Date?
    private var hasHeardVoice = false
    private let silenceTimeout: TimeInterval = 1.2
    private let voicePowerThreshold: CGFloat = 0.16
    private let imageLoader: RemoteImageLoader
    private let foodImageURL: (String) -> URL?
    private var imageTask: Task<Void, Never>?

    init(
        recorder: VoiceFoodAudioRecording,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase,
        analyzeTextFoodUseCase: AnalyzeTextFoodUseCase,
        mealType: MealType = .snacks,
        date: Date = Date(),
        imageLoader: RemoteImageLoader = .shared,
        foodImageURL: @escaping (String) -> URL? = { AIAssistantAPIConfiguration.production.foodImageURL(name: $0) }
    ) {
        self.recorder = recorder
        self.transcribeFoodVoiceUseCase = transcribeFoodVoiceUseCase
        self.analyzeTextFoodUseCase = analyzeTextFoodUseCase
        selectedMealType = mealType
        diaryDate = date
        self.imageLoader = imageLoader
        self.foodImageURL = foodImageURL
        analysis.bind { [weak self] result in
            self?.loadResultImage(for: result)
        }
    }

    deinit {
        silenceTimer?.invalidate()
        imageTask?.cancel()
    }

    var productSubtitleText: String {
        guard let result = analysis.value else { return "" }
        let portion: String?
        if let milliliters = result.portionMilliliters {
            portion = AppUnits.current.volumeText(milliliters)
        } else if let grams = result.portionGrams {
            portion = AppUnits.current.massText(grams)
        } else {
            portion = nil
        }
        if !result.notes.isEmpty, let portion {
            return "\(result.notes) (\(portion))"
        }
        if !result.notes.isEmpty {
            return result.notes
        }
        return portion ?? ""
    }

    var healthScoreTitleText: String {
        guard let result = analysis.value else { return "" }
        return L10n.format("photo.result.healthScore", result.nutritionFacts.score)
    }

    var caloriesValueText: String {
        guard let result = analysis.value else { return "" }
        // The tile is titled Calories, so the number stands alone and never truncates to "420кк…".
        return String(Int(result.calories.rounded()))
    }

    var proteinValueText: String {
        guard let result = analysis.value else { return "" }
        return L10n.format("editMeal.gramsValue", Int(result.protein.rounded()))
    }

    var carbsValueText: String {
        guard let result = analysis.value else { return "" }
        return L10n.format("editMeal.gramsValue", Int(result.carbs.rounded()))
    }

    var fatValueText: String {
        guard let result = analysis.value else { return "" }
        return L10n.format("editMeal.gramsValue", Int(result.fats.rounded()))
    }

    var fullDetailsText: String {
        guard let result = analysis.value else { return "" }
        var lines = details(for: result).split(separator: "\n").map(String.init)
        lines.append("\(L10n.tr("home.fiber")): \(L10n.format("editMeal.gramsValue", Int(result.fiber.rounded())))")
        lines.append("\(L10n.tr("home.sugar")): \(L10n.format("editMeal.gramsValue", Int(result.sugar.rounded())))")
        lines.append("\(L10n.tr("home.sodium")): \(L10n.format("photo.result.mgValue", Int(result.sodium.rounded())))")
        return lines.joined(separator: "\n")
    }

    func normalizedPower() -> CGFloat {
        recorder.normalizedPower()
    }

    func closeTapped() {
        activeTask?.cancel()
        stopSilenceWatch()
        recorder.onPartialTranscript = nil
        recorder.onUtteranceFinal = nil
        recorder.cancelRecording()
        onClose?()
    }

    func dismissResultTapped() {
        showsFullDetails.value = false
        phase.value = .recorded
        statusText.value = L10n.tr("voice.yourLog")
    }

    func viewDetailsTapped() {
        guard let draft = makeDraft() else { return }
        onViewDetails?(draft)
    }

    func confirmLogTapped() {
        guard let draft = makeDraft() else { return }
        onAddEntry?(draft)
    }

    func updateTranscript(_ text: String) {
        guard phase.value == .recorded || phase.value == .result else { return }
        transcriptText.value = text
        if phase.value == .recorded {
            statusText.value = L10n.tr("voice.yourLog")
        }
        refreshCanAnalyze()
    }

    func micTapped() {
        guard phase.value == .idle, !isRecording.value, !isAnalyzing.value else { return }
        Task { @MainActor in
            let granted = await recorder.requestPermission()
            guard granted else {
                transcriptText.value = VoiceFoodError.microphoneDenied.localizedDescription
                return
            }
            do {
                receivedLiveVoice = false
                transcriptText.value = ""
                recorder.onPartialTranscript = { [weak self] live in
                    guard let self else { return }
                    self.receivedLiveVoice = true
                    self.transcriptText.value = live
                    if !live.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.markHeardVoice()
                    }
                }
                recorder.onUtteranceFinal = { [weak self] in
                    self?.stopRecording(autoAnalyze: false)
                }
                try recorder.startRecording()
                analysis.value = nil
                showsFullDetails.value = false
                isRecording.value = true
                isTranscribing.value = false
                phase.value = .listening
                statusText.value = L10n.tr("voice.listeningTranscribing")
                refreshCanAnalyze()
                startSilenceWatch()
            } catch {
                recorder.onPartialTranscript = nil
                resetToIdle()
                transcriptText.value = error.localizedDescription
            }
        }
    }

    func stopTapped() {
        stopRecording(autoAnalyze: false)
    }

    func clearTapped() {
        activeTask?.cancel()
        stopSilenceWatch()
        recorder.onPartialTranscript = nil
        recorder.onUtteranceFinal = nil
        recorder.cancelRecording()
        resetToIdle()
    }

    func analyzeTapped() {
        let text = transcriptText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase.value == .recorded, !isAnalyzing.value, !text.isEmpty else { return }
        isAnalyzing.value = true
        canAnalyze.value = false
        analysis.value = nil
        showsFullDetails.value = false
        activeTask?.cancel()
        activeTask = Task { @MainActor in
            do {
                var result = try await analyzeTextFoodUseCase.execute(
                    text: text,
                    mealType: selectedMealType
                )
                guard !Task.isCancelled else { return }
                result.source = "voice"
                Analytics.tracker.track(.recognized("voice", confidence: result.confidence))
                analysis.value = result
                isAnalyzing.value = false
                refreshCanAnalyze()
                phase.value = .result
            } catch {
                guard !Task.isCancelled else { return }
                isAnalyzing.value = false
                refreshCanAnalyze()
                transcriptText.value = text
                statusText.value = error.localizedDescription
                Analytics.tracker.track(.foodLogFailed(method: "voice"))
                Analytics.tracker.track(.recognitionFailed("voice", error: error))
            }
        }
    }

    func makeDraft() -> ProductDetailsDraft? {
        guard var result = analysis.value else { return nil }
        result.source = "voice"
        // The dish picture shown on the result goes on with it, to the entry and into the diary.
        var draft = ProductDetailsMath.draft(
            from: result,
            imageData: resultImage.value?.jpegData(compressionQuality: 0.9),
            mealType: result.mealType,
            date: diaryDate
        )
        if draft.imageURL == nil {
            draft.imageURL = foodImageURL(result.name)
        }
        return draft
    }

    private func loadResultImage(for result: FoodPhotoAnalysis?) {
        imageTask?.cancel()
        resultImage.value = nil
        guard let result, let url = foodImageURL(result.name) else {
            isResultImageLoading.value = false
            return
        }
        isResultImageLoading.value = true
        imageTask = Task { @MainActor [weak self, imageLoader] in
            let image = await imageLoader.fetch(url)
            guard let self, !Task.isCancelled, self.analysis.value?.name == result.name else { return }
            self.resultImage.value = image
            self.isResultImageLoading.value = false
        }
    }

    private func startSilenceWatch() {
        stopSilenceWatch()
        hasHeardVoice = false
        lastVoiceAt = nil
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tickSilence()
        }
        RunLoop.main.add(timer, forMode: .common)
        silenceTimer = timer
    }

    private func stopSilenceWatch() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        lastVoiceAt = nil
        hasHeardVoice = false
    }

    private func tickSilence() {
        guard isRecording.value else {
            stopSilenceWatch()
            return
        }
        if recorder.normalizedPower() >= voicePowerThreshold {
            markHeardVoice()
            return
        }
        guard hasHeardVoice, let lastVoiceAt else { return }
        guard Date().timeIntervalSince(lastVoiceAt) >= silenceTimeout else { return }
        stopRecording(autoAnalyze: false)
    }

    private func markHeardVoice() {
        hasHeardVoice = true
        lastVoiceAt = Date()
    }

    private func stopRecording(autoAnalyze: Bool) {
        guard isRecording.value else { return }
        stopSilenceWatch()
        isRecording.value = false
        do {
            let audio = try recorder.stopRecording()
            recorder.onPartialTranscript = nil
            recorder.onUtteranceFinal = nil
            let live = transcriptText.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if receivedLiveVoice || !live.isEmpty || audio.isEmpty {
                isTranscribing.value = false
                phase.value = .recorded
                statusText.value = L10n.tr("voice.yourLog")
                refreshCanAnalyze()
                if autoAnalyze {
                    analyzeTapped()
                }
                return
            }
            isTranscribing.value = true
            statusText.value = L10n.tr("voice.listeningTranscribing")
            activeTask?.cancel()
            activeTask = Task { @MainActor in
                do {
                    let result = try await transcribeFoodVoiceUseCase.execute(audioData: audio)
                    guard !Task.isCancelled else { return }
                    transcriptText.value = result.text
                    isTranscribing.value = false
                    phase.value = .recorded
                    statusText.value = L10n.tr("voice.yourLog")
                    refreshCanAnalyze()
                    if autoAnalyze {
                        analyzeTapped()
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    isTranscribing.value = false
                    resetToIdle()
                    transcriptText.value = error.localizedDescription
                }
            }
        } catch {
            recorder.onPartialTranscript = nil
            recorder.onUtteranceFinal = nil
            isTranscribing.value = false
            resetToIdle()
            transcriptText.value = error.localizedDescription
        }
    }

    private func resetToIdle() {
        stopSilenceWatch()
        receivedLiveVoice = false
        isRecording.value = false
        isTranscribing.value = false
        isAnalyzing.value = false
        analysis.value = nil
        showsFullDetails.value = false
        transcriptText.value = ""
        phase.value = .idle
        statusText.value = L10n.tr("voice.tapAndSpeak")
        refreshCanAnalyze()
    }

    private func refreshCanAnalyze() {
        let text = transcriptText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        canAnalyze.value = phase.value == .recorded && !text.isEmpty && !isAnalyzing.value
    }

    private func details(for result: FoodPhotoAnalysis) -> String {
        var lines: [String] = []
        lines.append(L10n.format("textLog.mealLine", result.mealType.localizedTitle))
        lines.append(L10n.format("textLog.caloriesLine", Int(result.calories.rounded())))
        lines.append(L10n.format("textLog.proteinLine", Int(result.protein.rounded())))
        lines.append(L10n.format("textLog.carbsLine", Int(result.carbs.rounded())))
        lines.append(L10n.format("textLog.fatsLine", Int(result.fats.rounded())))
        if let grams = result.portionGrams {
            lines.append(L10n.format("textLog.portionGrams", grams))
        }
        if let ml = result.portionMilliliters {
            lines.append(L10n.format("textLog.portionMl", ml))
        }
        if !result.notes.isEmpty {
            lines.append(result.notes)
        }
        return lines.joined(separator: "\n")
    }
}
