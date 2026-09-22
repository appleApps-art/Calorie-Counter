import Foundation

struct EditMealItem: Equatable {
    let id: UUID
    let name: String
    let detailText: String
    let portionText: String
    let imageURL: URL?
    let imageData: Data?
    var fallbackImageURL: URL? = nil
}

enum EditMealAssistantScan {
    private static let ignoredNameTokens: Set<String> = ["with", "from", "and", "the", "for"]
    private static let addIntentPattern = #"\b(?:додай|додати|додайте|добав|добавте|add)\b"#
    private static let replaceIntentPattern =
        #"\b(?:заміни|замінити|замініть|замість|зміни|змінити|поміняй|поміняти|replace|swap|change|instead)\b"#

    static func targetItemIDs(for text: String, items: [EditMealItem]) -> Set<UUID> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if hasIntent(addIntentPattern, in: trimmed), !hasIntent(replaceIntentPattern, in: trimmed) {
            return []
        }
        let lowered = trimmed.lowercased()
        let matched = items.filter { item in
            let name = item.name.lowercased()
            if !name.isEmpty, lowered.contains(name) {
                return true
            }
            let nameTokens = name
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 && !ignoredNameTokens.contains($0) }
            return nameTokens.contains { lowered.contains($0) }
        }
        if matched.isEmpty {
            return hasIntent(replaceIntentPattern, in: trimmed) ? Set(items.map(\.id)) : []
        }
        return Set(matched.map(\.id))
    }

    private static func hasIntent(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

final class EditMealViewModel {
    let titleText = Observable("")
    let items = Observable<[EditMealItem]>([])
    let inputText = Observable("")
    let isSending = Observable(false)
    let isRecording = Observable(false)
    let canConfirmVoice = Observable(false)
    let scanningItemIDs = Observable<Set<UUID>>([])
    let assistantMessage = Observable<String?>(nil)

    var onAddFood: (() -> Void)?
    var onOpenFood: ((UUID) -> Void)?
    var onClose: (() -> Void)?
    var onSaved: (() -> Void)?
    /// Asked before a message goes to Bity; false keeps the text and calls `onLimitReached`.
    var allowsSending: () -> Bool = { true }
    var onLimitReached: ((_ retry: @escaping () -> Void) -> Void)?
    var onMessageAnswered: (() -> Void)?

    let mealType: MealType
    let date: Date

    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let deleteFoodEntryUseCase: DeleteFoodEntryUseCase
    private let updateFoodEntryUseCase: UpdateFoodEntryUseCase
    private let scaleFoodPortionUseCase: ScaleFoodPortionUseCase
    private let logFoodUseCase: LogFoodUseCase
    private let replaceFoodEntryUseCase: ReplaceFoodEntryUseCase
    private let aiAssistantService: AIAssistantServiceProtocol
    private let buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase
    private let parseAIAssistantActionsUseCase: ParseAIAssistantActionsUseCase
    private var entries: [FoodEntry] = []
    private var savedEntries: [UUID: FoodEntry]?
    private var extraAdditions: [FoodEntry] = []
    private var replacements: [UUID: FoodLogProposal] = [:]
    private var assistantTask: Task<Void, Never>?
    private var isFinished = false
    private var history: [AIAssistantChatHistoryItem] = []
    private var pendingImage: (base64: String, mimeType: String)?
    private let dictation: VoiceConfirmDictation
    private let imageConfiguration: AIAssistantAPIConfiguration

    init(
        mealType: MealType,
        date: Date,
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        deleteFoodEntryUseCase: DeleteFoodEntryUseCase,
        updateFoodEntryUseCase: UpdateFoodEntryUseCase,
        scaleFoodPortionUseCase: ScaleFoodPortionUseCase,
        logFoodUseCase: LogFoodUseCase,
        replaceFoodEntryUseCase: ReplaceFoodEntryUseCase,
        aiAssistantService: AIAssistantServiceProtocol,
        buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase,
        parseAIAssistantActionsUseCase: ParseAIAssistantActionsUseCase,
        voiceRecorder: VoiceFoodAudioRecording,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase,
        imageConfiguration: AIAssistantAPIConfiguration = .production
    ) {
        self.mealType = mealType
        self.date = date
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.deleteFoodEntryUseCase = deleteFoodEntryUseCase
        self.updateFoodEntryUseCase = updateFoodEntryUseCase
        self.scaleFoodPortionUseCase = scaleFoodPortionUseCase
        self.logFoodUseCase = logFoodUseCase
        self.replaceFoodEntryUseCase = replaceFoodEntryUseCase
        self.aiAssistantService = aiAssistantService
        self.buildAIAssistantUserContextUseCase = buildAIAssistantUserContextUseCase
        self.parseAIAssistantActionsUseCase = parseAIAssistantActionsUseCase
        self.imageConfiguration = imageConfiguration
        dictation = VoiceConfirmDictation(
            recorder: voiceRecorder,
            transcribeFoodVoiceUseCase: transcribeFoodVoiceUseCase,
            combineWithAnchor: true
        )
        dictation.onText = { [weak self] text in
            self?.inputText.value = text
        }
        dictation.isRecording.bind { [weak self] value in
            self?.isRecording.value = value
        }
        dictation.canConfirm.bind { [weak self] value in
            self?.canConfirmVoice.value = value
        }
        titleText.value = L10n.format("editMeal.title", mealType.localizedTitle)
    }

    func viewDidLoad() {
        reload()
    }

    func foodEntry(id: UUID) -> FoodEntry? {
        entries.first { $0.id == id }
    }

    func openFood(id: UUID) {
        onOpenFood?(id)
    }

    func reload() {
        guard !isFinished else { return }
        if savedEntries != nil {
            items.value = entries.map(makeItem)
            return
        }
        do {
            let summary = try fetchDailyDiaryUseCase.execute(for: date)
            entries = summary.entries(for: mealType)
            savedEntries = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
            items.value = entries.map(makeItem)
        } catch {
            entries = []
            items.value = []
            assistantMessage.value = error.localizedDescription
        }
    }

    func updateInput(_ text: String) {
        inputText.value = text
        dictation.clearConfirmIfEmpty(text)
    }

    func deleteFood(id: UUID) {
        guard !isFinished else { return }
        entries.removeAll { $0.id == id }
        replacements.removeValue(forKey: id)
        reload()
    }

    func commitPortion(id: UUID, text: String) {
        guard !isFinished else { return }
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        guard let parsed = Self.parsePortion(text) else { return }
        var updated: FoodEntry
        let hasKnownPortion = (entry.portionGrams ?? 0) > 0 || (entry.portionMilliliters ?? 0) > 0
        switch parsed.unit {
        case .grams:
            if hasKnownPortion {
                updated = scaleFoodPortionUseCase.execute(entry: entry, grams: parsed.value)
            } else {
                // The first measured weight describes the existing nutrition, not a 100 g baseline.
                updated = entry
                updated.portionGrams = parsed.value
            }
        case .milliliters:
            if hasKnownPortion {
                updated = scaleFoodPortionUseCase.execute(entry: entry, milliliters: parsed.value)
            } else {
                updated = entry
                updated.portionMilliliters = parsed.value
            }
        }
        if let index = entries.firstIndex(where: { $0.id == id }) { entries[index] = updated }
        if var replacement = replacements[id] {
            replacement.calories = updated.calories
            replacement.protein = updated.protein
            replacement.carbs = updated.carbs
            replacement.fats = updated.fats
            replacement.fiber = updated.fiber
            replacement.sugar = updated.sugar
            replacement.sodium = updated.sodium
            replacement.portionGrams = updated.portionGrams
            replacement.portionMilliliters = updated.portionMilliliters
            replacements[id] = replacement
        }
        reload()
    }

    func addTapped() {
        onAddFood?()
    }

    func closeTapped() {
        discardChanges()
        onClose?()
    }

    func discardChanges() {
        guard !isFinished else { return }
        isFinished = true
        assistantTask?.cancel()
        assistantTask = nil
        dictation.cancel()
        pendingImage = nil
        entries = []
        extraAdditions = []
        replacements = [:]
        scanningItemIDs.value = []
        isSending.value = false
    }

    func saveTapped() {
        guard !isFinished, !isSending.value else { return }
        reload()
        guard let baseline = savedEntries else { return }
        assistantMessage.value = nil
        do {
            let draft = entries + extraAdditions
            let draftIDs = Set(draft.map(\.id))
            for id in baseline.keys where !draftIDs.contains(id) {
                try deleteFoodEntryUseCase.execute(id: id)
                savedEntries?.removeValue(forKey: id)
            }
            for entry in draft where savedEntries?[entry.id] != entry {
                if savedEntries?[entry.id] == nil {
                    _ = try logFoodUseCase.execute(entry)
                } else if let proposal = replacements[entry.id] {
                    _ = try replaceFoodEntryUseCase.execute(targetId: entry.id, with: proposal, date: entry.date)
                } else {
                    try updateFoodEntryUseCase.execute(entry)
                }
                savedEntries?[entry.id] = entry
            }
            isFinished = true
            dictation.cancel()
            onSaved?()
        } catch {
            assistantMessage.value = error.localizedDescription
        }
    }

    func stageAdditions(_ additions: [FoodEntry]) throws {
        guard !isFinished else { throw AssistantError.closed }
        reload()
        guard savedEntries != nil else { throw AssistantError.closed }
        for entry in additions {
            if entry.mealType == mealType && Calendar.current.isDate(entry.date, inSameDayAs: date) {
                entries.append(entry)
            } else {
                extraAdditions.append(entry)
            }
        }
        reload()
    }

    func sendTapped() {
        send(text: inputText.value)
    }

    func attachPreparedImage(base64: String, mimeType: String) {
        pendingImage = (base64, mimeType)
        sendTapped()
    }

    func toggleVoiceTapped() {
        if canConfirmVoice.value {
            dictation.consumeConfirm()
            sendTapped()
            return
        }
        if isRecording.value {
            dictation.finish()
        } else {
            dictation.start(anchor: inputText.value)
        }
    }

    private func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = pendingImage
        pendingImage = nil
        guard (!trimmed.isEmpty || image != nil), !isSending.value, !isFinished else { return }
        guard allowsSending() else {
            onLimitReached? { [weak self] in
                self?.pendingImage = image
                self?.send(text: text)
            }
            return
        }
        reload()
        scanningItemIDs.value = EditMealAssistantScan.targetItemIDs(for: trimmed, items: items.value)
        assistantMessage.value = nil
        isSending.value = true
        inputText.value = ""
        let outbound = trimmed.isEmpty ? L10n.tr("ai.chat.photoMessage") : trimmed
        Analytics.tracker.track(.mealAISent(mealType: mealType.rawValue, hasImage: image != nil))
        assistantTask = Task { @MainActor in
            do {
                guard !Task.isCancelled, !isFinished else { return }
                var context = try buildAIAssistantUserContextUseCase.execute(date: date)
                let persistedToday = context.today
                let persistedMeal = try fetchDailyDiaryUseCase.execute(for: date).entries(for: mealType).filter(\.isEaten)
                let eatenDraft = entries.filter(\.isEaten)
                context.today?.meals?.removeAll { $0.mealType == mealType.rawValue }
                context.today?.meals?.append(contentsOf: entries.map {
                    .init(id: $0.id.uuidString, name: $0.name, mealType: $0.mealType.rawValue,
                          calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fats: $0.fats,
                          portionGrams: $0.portionGrams)
                })
                let calorieDelta = eatenDraft.reduce(0) { $0 + $1.calories } - persistedMeal.reduce(0) { $0 + $1.calories }
                context.today?.consumedCalories = (persistedToday?.consumedCalories ?? 0) + calorieDelta
                context.today?.remainingCalories = (persistedToday?.remainingCalories ?? 0) - calorieDelta
                context.today?.protein = (persistedToday?.protein ?? 0) + eatenDraft.reduce(0) { $0 + $1.protein } - persistedMeal.reduce(0) { $0 + $1.protein }
                context.today?.carbs = (persistedToday?.carbs ?? 0) + eatenDraft.reduce(0) { $0 + $1.carbs } - persistedMeal.reduce(0) { $0 + $1.carbs }
                context.today?.fats = (persistedToday?.fats ?? 0) + eatenDraft.reduce(0) { $0 + $1.fats } - persistedMeal.reduce(0) { $0 + $1.fats }
                context.mealEditing = .init(mealType: mealType.rawValue, entryIDs: entries.map { $0.id.uuidString })
                let response = try await aiAssistantService.chat(
                    AIAssistantChatRequest(
                        message: outbound,
                        history: history,
                        userContext: context,
                        imageBase64: image?.base64,
                        imageMimeType: image?.mimeType
                    )
                )
                guard !Task.isCancelled, !isFinished else { return }
                let actions = parseAIAssistantActionsUseCase.execute(toolCalls: response.message.toolCalls)
                reload()
                let appliedCount = try apply(actions)
                history.append(.init(role: "user", content: outbound))
                history.append(.init(role: "assistant", content: response.message.content))
                if history.count > 20 {
                    history = Array(history.suffix(20))
                }
                reload()
                let content = response.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if appliedCount == 0 || content.contains("?") || content.contains("？") {
                    assistantMessage.value = content.isEmpty ? L10n.tr("editMeal.ai.noChanges") : content
                }
                onMessageAnswered?()
                Analytics.tracker.track(.mealAICompleted(mealType: mealType.rawValue, success: true))
            } catch {
                guard !Task.isCancelled, !isFinished else { return }
                if inputText.value.isEmpty { inputText.value = trimmed }
                assistantMessage.value = error.localizedDescription
                Analytics.tracker.track(.mealAICompleted(mealType: mealType.rawValue, success: false))
            }
            scanningItemIDs.value = []
            isSending.value = false
        }
    }

    private func apply(_ actions: [AIAssistantAction]) throws -> Int {
        var appliedCount = 0
        for action in actions {
            switch action {
            case .replaceFood(let proposal):
                _ = try replacementTarget(id: proposal.targetEntryId, name: proposal.targetName)
            default:
                break
            }
        }
        for action in actions {
            switch action {
            case .logFood(var proposal):
                proposal.mealType = mealType
                entries.append(proposal.toFoodEntry(date: date))
                appliedCount += 1
            case .replaceFood(var proposal):
                proposal.newItem.mealType = mealType
                let targetId = try replacementTarget(id: proposal.targetEntryId, name: proposal.targetName)
                if let index = entries.firstIndex(where: { $0.id == targetId }) {
                    entries[index] = proposal.newItem.toFoodEntry(date: date, id: targetId)
                    replacements[targetId] = proposal.newItem
                }
                appliedCount += 1
            case .swapFood, .mealSuggestions, .logWater, .saveRecipe, .savePreference, .swapRecipeIngredient,
                 .swapMealPlanMeal:
                break
            }
        }
        return appliedCount
    }

    private func replacementTarget(id: UUID?, name: String?) throws -> UUID {
        if let id {
            guard entries.contains(where: { $0.id == id }) else { throw AssistantError.targetNotFound }
            return id
        }
        let targetName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let matches = entries.filter { $0.name.localizedCaseInsensitiveCompare(targetName) == .orderedSame }
        guard !targetName.isEmpty, matches.count == 1, let target = matches.first else {
            throw AssistantError.targetNotFound
        }
        return target.id
    }

    private enum AssistantError: LocalizedError {
        case targetNotFound
        case closed

        var errorDescription: String? {
            switch self {
            case .targetNotFound: return L10n.tr("editMeal.ai.targetNotFound")
            case .closed: return L10n.tr("editMeal.ai.noChanges")
            }
        }
    }

    private func makeItem(_ entry: FoodEntry) -> EditMealItem {
        EditMealItem(
            id: entry.id,
            name: entry.name,
            detailText: Self.detailText(entry),
            portionText: Self.portionText(entry),
            imageURL: entry.imageURL,
            imageData: entry.imageData,
            fallbackImageURL: imageConfiguration.foodImageURL(name: entry.name)
        )
    }

    private static func detailText(_ entry: FoodEntry) -> String {
        let kcal = Int(entry.calories.rounded())
        if let milliliters = entry.portionMilliliters {
            return "\(AppUnits.current.volumeText(milliliters)) • \(L10n.format("recipes.kcal", kcal))"
        }
        if let grams = entry.portionGrams {
            return "\(AppUnits.current.massText(grams)) • \(L10n.format("recipes.kcal", kcal))"
        }
        return L10n.format("recipes.kcal", kcal)
    }

    private static func portionText(_ entry: FoodEntry) -> String {
        if let milliliters = entry.portionMilliliters {
            return AppUnits.current.volumeText(milliliters)
        }
        if let grams = entry.portionGrams {
            return AppUnits.current.massText(grams)
        }
        return ""
    }

    private enum PortionUnit {
        case grams
        case milliliters
    }

    private static func parsePortion(_ text: String) -> (value: Double, unit: PortionUnit)? {
        let trimmed = AppUnits.metricInput(text).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return nil }
        let pattern = #"^\s*(\d+(?:\.\d+)?)\s*(g|gr|grams?|г|ml|мл)?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: trimmed),
              let value = Double(trimmed[valueRange]),
              value > 0
        else { return nil }
        let unitText: String
        if match.range(at: 2).location != NSNotFound, let unitRange = Range(match.range(at: 2), in: trimmed) {
            unitText = String(trimmed[unitRange]).lowercased()
        } else {
            unitText = "g"
        }
        if unitText == "ml" || unitText == "мл" {
            return (value, .milliliters)
        }
        return (value, .grams)
    }
}
