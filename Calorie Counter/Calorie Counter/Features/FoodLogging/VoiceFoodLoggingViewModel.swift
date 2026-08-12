import Foundation

final class VoiceFoodLoggingViewModel {
    let statusText = Observable(L10n.tr("voice.status"))
    let transcriptText = Observable("")
    let resultTitleText = Observable("")
    let resultDetailsText = Observable("")
    let confidenceText = Observable("")
    let nutritionScoreText = Observable("")
    let isRecording = Observable(false)
    let isAnalyzing = Observable(false)
    let canConfirmLog = Observable(false)
    let showsResultCard = Observable(false)
    let mealTypeIndex = Observable(MealType.snacks.caseIndex)

    var onLogged: (() -> Void)?

    private let recorder: VoiceFoodAudioRecording
    private let transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase
    private let analyzeVoiceFoodUseCase: AnalyzeVoiceFoodUseCase
    private let logFoodUseCase: LogFoodUseCase
    private var analysis: FoodPhotoAnalysis?

    init(
        recorder: VoiceFoodAudioRecording,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase,
        analyzeVoiceFoodUseCase: AnalyzeVoiceFoodUseCase,
        logFoodUseCase: LogFoodUseCase
    ) {
        self.recorder = recorder
        self.transcribeFoodVoiceUseCase = transcribeFoodVoiceUseCase
        self.analyzeVoiceFoodUseCase = analyzeVoiceFoodUseCase
        self.logFoodUseCase = logFoodUseCase
    }

    func updateMealTypeIndex(_ index: Int) {
        mealTypeIndex.value = max(0, min(index, MealType.allCases.count - 1))
    }

    func startRecordingTapped() {
        guard !isRecording.value, !isAnalyzing.value else { return }
        Task { @MainActor in
            let granted = await recorder.requestPermission()
            guard granted else {
                statusText.value = VoiceFoodError.microphoneDenied.localizedDescription
                return
            }
            do {
                try recorder.startRecording()
                isRecording.value = true
                canConfirmLog.value = false
                showsResultCard.value = false
                analysis = nil
                statusText.value = L10n.tr("voice.listening")
            } catch {
                statusText.value = error.localizedDescription
            }
        }
    }

    func cancelRecordingTapped() {
        recorder.cancelRecording()
        isRecording.value = false
        statusText.value = L10n.tr("voice.cancelled")
    }

    func stopAndAnalyzeTapped() {
        guard isRecording.value else { return }
        isRecording.value = false
        isAnalyzing.value = true
        statusText.value = L10n.tr("voice.analyzing")

        let mealType = MealType.allCases[mealTypeIndex.value]
        do {
            let audio = try recorder.stopRecording()
            Task { @MainActor in
                do {
                    let result = try await analyzeVoiceFoodUseCase.execute(
                        audioData: audio,
                        mealType: mealType
                    )
                    transcriptText.value = result.transcription
                    applyAnalysis(result.analysis)
                } catch {
                    analysis = nil
                    canConfirmLog.value = false
                    showsResultCard.value = false
                    statusText.value = error.localizedDescription
                }
                isAnalyzing.value = false
            }
        } catch {
            isAnalyzing.value = false
            statusText.value = error.localizedDescription
        }
    }

    func confirmLogTapped() {
        guard let result = analysis else { return }
        do {
            try logFoodUseCase.execute(result.toFoodEntry(source: "voice"))
            statusText.value = L10n.tr("textLog.foodLogged")
            onLogged?()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    private func applyAnalysis(_ result: FoodPhotoAnalysis) {
        analysis = result
        if let index = MealType.allCases.firstIndex(of: result.mealType) {
            mealTypeIndex.value = index
        }
        resultTitleText.value = result.name
        resultDetailsText.value = details(for: result)
        confidenceText.value = L10n.format("textLog.confidence", Int((result.confidence * 100).rounded()))
        let facts = result.nutritionFacts
        nutritionScoreText.value = L10n.format("home.scoreFormat", facts.score, facts.grade.rawValue)
        showsResultCard.value = true
        canConfirmLog.value = true
        statusText.value = result.assistantMessage.isEmpty ? L10n.tr("textLog.readyToConfirm") : result.assistantMessage
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

private extension MealType {
    var caseIndex: Int {
        MealType.allCases.firstIndex(of: self) ?? 0
    }
}
