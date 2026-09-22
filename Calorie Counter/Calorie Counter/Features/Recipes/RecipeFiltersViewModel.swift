import Foundation

final class RecipeFiltersViewModel {
    let mealTypeOptions = [
        "recipes.filters.breakfast",
        "recipes.filters.lunch",
        "recipes.filters.dinner",
        "recipes.filters.snack"
    ]
    let cuisineOptions = [
        "recipes.filters.any",
        "recipes.filters.italian",
        "recipes.filters.asian",
        "recipes.filters.mexican",
        "recipes.filters.greek"
    ]
    let dietOptions = [
        "recipes.filters.any",
        "recipes.filters.vegetarian",
        "recipes.filters.vegan",
        "recipes.filters.lean",
        "recipes.filters.weightGain",
        "recipes.filters.balance"
    ]
    let cookOptions: [(String, Int?)] = [
        ("recipes.filters.any", nil),
        ("recipes.filters.cook15", 15),
        ("recipes.filters.cook30", 30),
        ("recipes.filters.cook60", 60)
    ]
    let difficultyOptions = [
        "recipes.filters.any",
        "recipes.filters.easy",
        "recipes.filters.medium",
        "recipes.filters.hard"
    ]

    let filters = Observable(RecipeSearchFilters.empty)
    let excludedQuery = Observable("")
    let isRecording = Observable(false)
    let canConfirmExcluded = Observable(false)

    var onClose: (() -> Void)?
    var onApply: ((RecipeSearchFilters) -> Void)?

    private let voiceRecorder: VoiceFoodAudioRecording
    private let transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase
    private var receivedLiveVoice = false
    private var speechEndTask: Task<Void, Never>?

    init(
        filters: RecipeSearchFilters,
        voiceRecorder: VoiceFoodAudioRecording,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase
    ) {
        self.voiceRecorder = voiceRecorder
        self.transcribeFoodVoiceUseCase = transcribeFoodVoiceUseCase
        self.filters.value = Self.filtersWithDefaultMealType(filters)
    }

    func closeTapped() {
        cancelVoice()
        onClose?()
    }

    func resetTapped() {
        cancelVoice()
        filters.value = Self.filtersWithDefaultMealType(.empty)
        excludedQuery.value = ""
        canConfirmExcluded.value = false
    }

    func selectMealType(_ key: String) {
        var next = filters.value
        Self.toggle(L10n.tr(key), in: &next.mealTypes)
        filters.value = next
    }

    func selectCuisine(_ key: String) {
        var next = filters.value
        Self.toggleListed(key, in: &next.cuisines)
        filters.value = next
    }

    func selectDiet(_ key: String) {
        var next = filters.value
        Self.toggleListed(key, in: &next.diets)
        filters.value = next
    }

    func selectCookTime(_ minutes: Int?) {
        var next = filters.value
        next.maxReadyMinutes = minutes
        filters.value = next
    }

    func selectDifficulty(_ key: String) {
        var next = filters.value
        Self.toggleListed(key, in: &next.difficulties)
        filters.value = next
    }

    func updateCalories(_ value: Int) {
        guard filters.value.maxCalories != value else { return }
        var next = filters.value
        next.maxCalories = value
        filters.value = next
    }

    func updateExcludedQuery(_ text: String) {
        excludedQuery.value = text
        let canConfirm = text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        if canConfirmExcluded.value != canConfirm {
            canConfirmExcluded.value = canConfirm
        }
    }

    func addExcluded(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var next = filters.value
        if !next.excludedIngredients.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            next.excludedIngredients.append(trimmed)
        }
        filters.value = next
        resetExcludedInput()
    }

    func confirmExcludedTapped() {
        addExcluded(excludedQuery.value)
    }

    func removeExcluded(_ name: String) {
        var next = filters.value
        next.excludedIngredients.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        filters.value = next
    }

    func trailingActionTapped() {
        if canConfirmExcluded.value {
            confirmExcludedTapped()
        } else {
            toggleVoiceTapped()
        }
    }

    func toggleVoiceTapped() {
        if isRecording.value {
            finishVoiceForConfirm()
        } else {
            startVoice()
        }
    }

    func showResultsTapped() {
        cancelVoice()
        onApply?(filters.value)
    }

    private static let defaultMealTypeKey = "recipes.filters.breakfast"

    private static func filtersWithDefaultMealType(_ filters: RecipeSearchFilters) -> RecipeSearchFilters {
        guard filters.mealTypes.isEmpty else { return filters }
        var next = filters
        next.mealTypes = [L10n.tr(defaultMealTypeKey)]
        return next
    }

    private static func toggleListed(_ key: String, in values: inout [String]) {
        if key == "recipes.filters.any" {
            values = []
            return
        }
        toggle(L10n.tr(key), in: &values)
    }

    private static func toggle(_ title: String, in values: inout [String]) {
        if let index = values.firstIndex(where: { $0.caseInsensitiveCompare(title) == .orderedSame }) {
            values.remove(at: index)
        } else {
            values.append(title)
        }
    }

    private func resetExcludedInput() {
        excludedQuery.value = ""
        canConfirmExcluded.value = false
    }

    private func startVoice() {
        Task { @MainActor in
            let granted = await voiceRecorder.requestPermission()
            guard granted else { return }
            do {
                receivedLiveVoice = false
                canConfirmExcluded.value = false
                voiceRecorder.onPartialTranscript = { [weak self] live in
                    let text = live.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let self, !text.isEmpty else { return }
                    self.receivedLiveVoice = true
                    self.excludedQuery.value = text
                    self.scheduleSpeechEnd()
                }
                voiceRecorder.onUtteranceFinal = { [weak self] in
                    self?.finishVoiceForConfirm()
                }
                try voiceRecorder.startRecording()
                isRecording.value = true
            } catch {
                clearVoiceCallbacks()
            }
        }
    }

    private func scheduleSpeechEnd() {
        speechEndTask?.cancel()
        speechEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            self?.finishVoiceForConfirm()
        }
    }

    private func finishVoiceForConfirm() {
        guard isRecording.value else { return }
        speechEndTask?.cancel()
        speechEndTask = nil

        var audio = Data()
        do {
            audio = try voiceRecorder.stopRecording()
        } catch {}
        clearVoiceCallbacks()

        let live = excludedQuery.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty {
            canConfirmExcluded.value = true
            isRecording.value = false
            return
        }

        isRecording.value = false
        guard !audio.isEmpty else { return }
        Task { @MainActor in
            let result = try? await transcribeFoodVoiceUseCase.execute(audioData: audio)
            let text = result?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty {
                excludedQuery.value = text
                canConfirmExcluded.value = true
            }
        }
    }

    private func cancelVoice() {
        speechEndTask?.cancel()
        speechEndTask = nil
        if isRecording.value {
            voiceRecorder.cancelRecording()
            isRecording.value = false
        }
        clearVoiceCallbacks()
    }

    private func clearVoiceCallbacks() {
        voiceRecorder.onPartialTranscript = nil
        voiceRecorder.onUtteranceFinal = nil
    }
}
