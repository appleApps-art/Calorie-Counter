import Foundation

enum AIChatCategory: Int, CaseIterable {
    case nutrition
    case meals
    case swaps

    var titleKey: String {
        switch self {
        case .nutrition: return "ai.chat.chip.nutrition"
        case .meals: return "ai.chat.chip.meals"
        case .swaps: return "ai.chat.chip.swaps"
        }
    }

    var emoji: String {
        switch self {
        case .nutrition: return "💡"
        case .meals: return "🍽"
        case .swaps: return "🔄"
        }
    }

    var requestIntent: AIAssistantChatIntent {
        switch self {
        case .nutrition: return .nutrition
        case .meals: return .mealSuggestions
        case .swaps: return .foodSwap
        }
    }
}

struct AIChatItem: Equatable {
    enum Kind: Equatable {
        case user(String)
        case assistant(String)
        case recipe(MealSuggestionOption, mealType: MealType)
        case swap(FoodSwapProposal)
        case loggedMeal(entryID: UUID?, proposal: FoodLogProposal)
        case mealPlan(MealPlan)
        case system(String)
        case typing
    }

    let id: UUID
    let kind: Kind

    init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }
}

final class AIAssistantViewModel {
    let titleText = Observable(L10n.tr("ai.chat.title"))
    let inputText = Observable("")
    let statusText = Observable("")
    let isSending = Observable(false)
    let isRecording = Observable(false)
    let canConfirmVoice = Observable(false)
    let pendingWaterConfirmText = Observable<String?>(nil)
    let pendingActions = Observable<[AIAssistantAction]>([])
    let messages = Observable<[AIChatItem]>([])
    let selectedCategory = Observable<AIChatCategory?>(nil)

    var onRecipeIngredientSwapProposed: ((RecipeIngredientSwapProposal) -> Void)?
    /// Returns true when the plan screen actually applied the swap.
    var onMealPlanSwapProposed: ((MealPlanSwapProposal) -> Bool)?
    /// Asked before a message goes out; false keeps what was typed and calls `onLimitReached`.
    var allowsSending: () -> Bool = { true }
    /// Gets the held back message as a retry, to send once Premium unlocks.
    var onLimitReached: ((_ retry: @escaping () -> Void) -> Void)?
    /// A message that got its answer, so a free try is counted only when it was worth one.
    var onMessageAnswered: (() -> Void)?
    private(set) var currentConversationID = UUID()

    private let aiAssistantService: AIAssistantServiceProtocol
    private let buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase
    private let parseAIAssistantActionsUseCase: ParseAIAssistantActionsUseCase
    private let confirmAIAssistantActionUseCase: ConfirmAIAssistantActionUseCase?
    private let persistChatHistoryUseCase: PersistChatHistoryUseCase?
    private let deleteFoodEntryUseCase: DeleteFoodEntryUseCase?
    private let searchFoodProductsUseCase: SearchFoodProductsUseCase?
    private let dictation: VoiceConfirmDictation?
    private let recipeContext: Recipe?
    private let mealPlanContext: MealPlan?
    private var history: [AIAssistantChatHistoryItem] = []
    private var pendingWaterProposal: WaterLogProposal?
    private var pendingImage: (base64: String, mimeType: String)?
    private var typingItemID: UUID?
    private var hasPersistedConversation = false

    init(
        aiAssistantService: AIAssistantServiceProtocol,
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        logWaterUseCase: LogWaterUseCase? = nil,
        recipeContext: Recipe? = nil,
        mealPlanContext: MealPlan? = nil,
        initialInput: String? = nil,
        buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase? = nil,
        parseAIAssistantActionsUseCase: ParseAIAssistantActionsUseCase = ParseAIAssistantActionsUseCase(),
        confirmAIAssistantActionUseCase: ConfirmAIAssistantActionUseCase? = nil,
        persistChatHistoryUseCase: PersistChatHistoryUseCase? = nil,
        deleteFoodEntryUseCase: DeleteFoodEntryUseCase? = nil,
        searchFoodProductsUseCase: SearchFoodProductsUseCase? = nil,
        voiceRecorder: VoiceFoodAudioRecording? = nil,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase? = nil
    ) {
        self.aiAssistantService = aiAssistantService
        self.parseAIAssistantActionsUseCase = parseAIAssistantActionsUseCase
        self.confirmAIAssistantActionUseCase = confirmAIAssistantActionUseCase
        self.persistChatHistoryUseCase = persistChatHistoryUseCase
        self.deleteFoodEntryUseCase = deleteFoodEntryUseCase
        self.searchFoodProductsUseCase = searchFoodProductsUseCase
        if let voiceRecorder, let transcribeFoodVoiceUseCase {
            self.dictation = VoiceConfirmDictation(
                recorder: voiceRecorder,
                transcribeFoodVoiceUseCase: transcribeFoodVoiceUseCase,
                combineWithAnchor: true
            )
        } else {
            self.dictation = nil
        }
        self.recipeContext = recipeContext
        self.mealPlanContext = mealPlanContext
        if let buildAIAssistantUserContextUseCase {
            self.buildAIAssistantUserContextUseCase = buildAIAssistantUserContextUseCase
        } else {
            self.buildAIAssistantUserContextUseCase = BuildAIAssistantUserContextUseCase(
                fetchDailyDiaryUseCase: fetchDailyDiaryUseCase,
                userProfileRepository: MissingProfileRepository(),
                userPreferenceRepository: MissingPreferenceRepository()
            )
        }
        if recipeContext != nil {
            titleText.value = L10n.tr("ai.replaceIngredientTitle")
            messages.value = [.init(kind: .assistant(L10n.tr("ai.recipeMode")))]
        } else if let mealPlanContext {
            // The plan itself opens the conversation, the way the design shows it.
            messages.value = [
                .init(kind: .assistant(L10n.tr("ai.mealPlanMode"))),
                .init(kind: .mealPlan(mealPlanContext))
            ]
        } else {
            messages.value = [.init(kind: .assistant(L10n.tr("ai.chat.welcome")))]
        }
        if let initialInput, !initialInput.isEmpty {
            inputText.value = initialInput
        }
        _ = logWaterUseCase
        enrichDisplayedRecipes(messages.value)
        dictation?.onText = { [weak self] text in
            self?.inputText.value = text
        }
        dictation?.isRecording.bind { [weak self] value in
            self?.isRecording.value = value
        }
        dictation?.canConfirm.bind { [weak self] value in
            self?.canConfirmVoice.value = value
        }
    }

    func updateInput(_ text: String) {
        inputText.value = text
        dictation?.clearConfirmIfEmpty(text)
    }

    func selectCategory(_ category: AIChatCategory) {
        guard !isSending.value else { return }
        guard allowsSending() else {
            onLimitReached? { [weak self] in self?.selectCategory(category) }
            return
        }
        selectedCategory.value = category
        send(text: L10n.tr(category.titleKey))
    }

    func attachPreparedImage(base64: String, mimeType: String) {
        pendingImage = (base64, mimeType)
        sendTapped()
    }

    func sendTapped() {
        dictation?.cancel()
        canConfirmVoice.value = false
        send(text: inputText.value)
    }

    func toggleVoiceTapped() {
        if canConfirmVoice.value {
            dictation?.consumeConfirm()
            sendTapped()
            return
        }
        if isRecording.value {
            dictation?.finish()
        } else {
            dictation?.start(anchor: inputText.value)
        }
    }

    func logRecipe(_ option: MealSuggestionOption, mealType: MealType) {
        let mealType = option.mealType ?? mealType
        guard let confirmAIAssistantActionUseCase else {
            reportSaveFailure(L10n.tr("ai.confirmUnavailable"))
            return
        }
        do {
            let entry = try confirmAIAssistantActionUseCase.executeMealSuggestion(option, mealType: mealType)
            Analytics.tracker.track(.aiActionApplied(kind: "meal_suggestion", success: true))
            removePendingMealSuggestion(option, mealType: mealType)
            selectedCategory.value = .nutrition
            let loggedItem = AIChatItem(kind: .loggedMeal(
                entryID: entry.id,
                proposal: option.asFoodLogProposal(mealType: mealType)
            ))
            replaceRecipe(option, mealType: mealType, with: loggedItem)
            recordCardActionInHistory(loggedItem)
            statusText.value = L10n.tr("ai.saved")
        } catch {
            Analytics.tracker.track(.aiActionApplied(kind: "meal_suggestion", success: false))
            reportSaveFailure(error.localizedDescription)
        }
    }

    func applySwap(_ proposal: FoodSwapProposal) {
        guard let confirmAIAssistantActionUseCase else {
            reportSaveFailure(L10n.tr("ai.confirmUnavailable"))
            return
        }
        do {
            guard let entry = try confirmAIAssistantActionUseCase.execute(.swapFood(proposal)) else {
                Analytics.tracker.track(.aiActionApplied(kind: "swap_food", success: false))
                reportSaveFailure(L10n.tr("ai.confirmUnavailable"))
                return
            }
            Analytics.tracker.track(.aiActionApplied(kind: "swap_food", success: true))
            removePendingSwap(proposal)
            let logged = proposal.asFoodLogProposal(mealType: entry.mealType)
            let loggedItem = AIChatItem(kind: .loggedMeal(entryID: entry.id, proposal: logged))
            replaceSwap(proposal, with: loggedItem)
            recordCardActionInHistory(loggedItem)
            statusText.value = L10n.tr("ai.saved")
        } catch {
            reportSaveFailure(error.localizedDescription)
        }
    }

    func seeMoreSwapOptions() {
        guard !isSending.value else { return }
        selectedCategory.value = .swaps
        send(text: L10n.tr("ai.chat.seeMoreOptions"))
    }

    func undoLoggedMeal(id: UUID) {
        do {
            try deleteFoodEntryUseCase?.execute(id: id)
            messages.value.removeAll { item in
                if case .loggedMeal(let entryID, _) = item.kind {
                    return entryID == id
                }
                return false
            }
            removePersistedLoggedMeal(entryID: id)
            statusText.value = L10n.tr("ai.chat.undone")
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func confirmPendingWaterLog() {
        guard let proposal = pendingWaterProposal else { return }
        confirm(.logWater(proposal))
        pendingWaterProposal = nil
        pendingWaterConfirmText.value = nil
    }

    func rejectPendingWaterLog() {
        pendingWaterProposal = nil
        pendingWaterConfirmText.value = nil
        statusText.value = L10n.tr("ai.waterCancelled")
        append(.init(kind: .system(L10n.tr("ai.waterCancelledMessage"))))
    }

    func confirmPendingAction(at index: Int) {
        guard pendingActions.value.indices.contains(index) else { return }
        let action = pendingActions.value[index]
        if case .mealSuggestions = action {
            statusText.value = L10n.tr("ai.pickSuggestion")
            return
        }
        confirm(action)
        var remaining = pendingActions.value
        remaining.remove(at: index)
        pendingActions.value = remaining
    }

    func confirmMealSuggestion(at actionIndex: Int, optionIndex: Int) {
        guard pendingActions.value.indices.contains(actionIndex) else { return }
        guard case .mealSuggestions(let proposal) = pendingActions.value[actionIndex] else { return }
        guard proposal.options.indices.contains(optionIndex) else { return }
        let option = proposal.options[optionIndex]
        logRecipe(option, mealType: option.mealType ?? proposal.mealType)
    }

    func confirmAllPendingActions() {
        let actions = pendingActions.value
        pendingActions.value = []
        for action in actions {
            if case .mealSuggestions = action { continue }
            if case .swapFood = action { continue }
            confirm(action)
        }
    }

    func rejectPendingActions() {
        pendingActions.value = []
        pendingWaterProposal = nil
        pendingWaterConfirmText.value = nil
        statusText.value = L10n.tr("ai.actionsCancelled")
    }

    func resetIfHistoryCleared() {
        guard let persistChatHistoryUseCase, recipeContext == nil,
              hasPersistedConversation, !isSending.value else { return }
        guard let stored = try? persistChatHistoryUseCase.loadConversation(id: currentConversationID),
              stored.isEmpty else { return }
        startNewConversation()
    }

    func startNewConversation() {
        guard !isSending.value else { return }
        resetConversationState(id: UUID())
    }

    func restorePersistedConversation(id: UUID? = nil) {
        guard let persistChatHistoryUseCase, recipeContext == nil, !isSending.value else { return }
        let selectedID = id ?? (try? persistChatHistoryUseCase.conversations().first?.id)
        guard let selectedID,
              let stored = try? persistChatHistoryUseCase.loadConversation(id: selectedID),
              !stored.isEmpty else { return }
        resetConversationState(id: selectedID, showsWelcome: false)
        hasPersistedConversation = true
        history = Array(stored.compactMap(ChatHistoryVisualCodec.apiHistoryItem(from:)).suffix(20))
        messages.value = stored.compactMap(ChatHistoryVisualCodec.chatItem(from:))
        enrichDisplayedRecipes(messages.value)
    }

    private func resetConversationState(id: UUID, showsWelcome: Bool = true) {
        dictation?.cancel()
        currentConversationID = id
        hasPersistedConversation = false
        history = []
        inputText.value = ""
        statusText.value = ""
        canConfirmVoice.value = false
        selectedCategory.value = nil
        pendingActions.value = []
        pendingWaterProposal = nil
        pendingWaterConfirmText.value = nil
        pendingImage = nil
        typingItemID = nil
        if showsWelcome {
            if let mealPlanContext {
                messages.value = [
                    .init(kind: .assistant(L10n.tr("ai.mealPlanMode"))),
                    .init(kind: .mealPlan(mealPlanContext))
                ]
            } else {
                messages.value = [.init(kind: .assistant(L10n.tr(recipeContext == nil ? "ai.chat.welcome" : "ai.recipeMode")))]
            }
        }
    }

    private func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = pendingImage
        pendingImage = nil
        guard (!trimmed.isEmpty || image != nil), !isSending.value else { return }
        guard allowsSending() else {
            // The text stays in the field; a photo waits in the retry instead of riding along later.
            onLimitReached? { [weak self] in
                self?.pendingImage = image
                self?.send(text: text)
            }
            return
        }

        isSending.value = true
        statusText.value = L10n.tr("ai.sending")
        inputText.value = ""
        let outbound = trimmed.isEmpty ? L10n.tr("ai.chat.photoMessage") : trimmed
        let intent = selectedCategory.value?.requestIntent
        let conversationID = currentConversationID
        let userItem = AIChatItem(kind: .user(outbound))
        appendUserAndTyping(userItem)
        persist(userItem, conversationID: conversationID)
        Analytics.tracker.track(.aiMessageSent(hasImage: image != nil, source: recipeContext == nil ? "chat" : "recipe"))

        Task { @MainActor in
            do {
                let context = try buildAIAssistantUserContextUseCase.execute(
                    recipe: recipeContext,
                    mealPlan: mealPlanContext
                )
                let response = try await aiAssistantService.chat(
                    AIAssistantChatRequest(
                        message: outbound,
                        history: history,
                        userContext: context,
                        imageBase64: image?.base64,
                        imageMimeType: image?.mimeType,
                        intent: intent
                    )
                )

                let content = response.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                let actions = parseAIAssistantActionsUseCase.execute(toolCalls: response.message.toolCalls)
                guard !content.isEmpty || !actions.isEmpty else {
                    throw AIAssistantServiceError.emptyResponse
                }
                pendingActions.value = actions

                let assistantText = displayedAssistantText(content: content, actions: actions)
                var incoming: [AIChatItem] = []
                if let assistantText, !assistantText.isEmpty {
                    incoming.append(.init(kind: .assistant(assistantText)))
                }
                incoming.append(contentsOf: visualItems(for: actions))
                replaceTyping(with: incoming)
                let persistedIncoming = Array(messages.value.suffix(incoming.count))
                persistTurn(incoming: persistedIncoming, conversationID: conversationID)
                enrichDisplayedRecipes(persistedIncoming)

                let apiAssistant = incoming.compactMap(ChatHistoryVisualCodec.apiHistoryItem(from:))
                    .map(\.content)
                    .joined(separator: "\n")
                history.append(.init(role: "user", content: outbound))
                if !apiAssistant.isEmpty {
                    history.append(.init(role: "assistant", content: apiAssistant))
                }
                if history.count > 20 {
                    history = Array(history.suffix(20))
                }
                if statusText.value == L10n.tr("ai.sending") {
                    statusText.value = L10n.tr("common.done")
                }
                onMessageAnswered?()
                Analytics.tracker.track(.aiMessageCompleted(
                    success: true,
                    actionCount: actions.count,
                    source: recipeContext == nil ? "chat" : "recipe"
                ))
            } catch {
                Analytics.tracker.track(.errorShown(context: "ai_chat", reason: error.isNoConnection ? "offline" : "failed"))
                let errorText = error.isNoConnection
                    ? L10n.tr("offline.message")
                    : L10n.format("ai.errorPrefix", error.localizedDescription)
                let errorItem = AIChatItem(kind: .system(errorText))
                replaceTyping(with: [errorItem])
                persistTurn(incoming: Array(messages.value.suffix(1)), conversationID: conversationID)
                statusText.value = L10n.tr("ai.failed")
                Analytics.tracker.track(.aiMessageCompleted(
                    success: false,
                    actionCount: 0,
                    source: recipeContext == nil ? "chat" : "recipe"
                ))
            }

            isSending.value = false
        }
    }

    private func visualItems(for actions: [AIAssistantAction]) -> [AIChatItem] {
        var items: [AIChatItem] = []
        for action in actions {
            switch action {
            case .logFood(let proposal):
                selectedCategory.value = .nutrition
                guard let entry = confirm(action, appendsFailureMessage: false) else {
                    items.append(.init(kind: .system(L10n.format("ai.saveFailed", statusText.value))))
                    continue
                }
                items.append(.init(kind: .loggedMeal(entryID: entry.id, proposal: proposal)))
                removePending(action)
            case .replaceFood(let proposal):
                selectedCategory.value = .nutrition
                guard let entry = confirm(action, appendsFailureMessage: false) else {
                    items.append(.init(kind: .system(L10n.format("ai.saveFailed", statusText.value))))
                    continue
                }
                items.append(.init(kind: .loggedMeal(entryID: entry.id, proposal: proposal.newItem)))
                removePending(action)
            case .swapFood(let proposal):
                selectedCategory.value = .swaps
                items.append(.init(kind: .swap(proposal)))
            case .mealSuggestions(let proposal):
                selectedCategory.value = .meals
                proposal.options.forEach { option in
                    items.append(.init(kind: .recipe(option, mealType: option.mealType ?? proposal.mealType)))
                }
            case .saveRecipe, .savePreference:
                confirm(action)
                removePending(action)
            case .swapRecipeIngredient(let proposal):
                onRecipeIngredientSwapProposed?(proposal)
                statusText.value = L10n.tr("ai.confirmSwapStatus")
            case .swapMealPlanMeal(let proposal):
                if onMealPlanSwapProposed?(proposal) == true {
                    statusText.value = L10n.tr("ai.confirmSwapStatus")
                } else {
                    // Saying nothing here is what makes a chat feel broken.
                    items.append(.init(kind: .assistant(L10n.tr("ai.mealPlanSwapNotFound"))))
                }
            case .logWater(let proposal):
                pendingWaterProposal = proposal
                let amount = Int(proposal.amountMilliliters.rounded())
                pendingWaterConfirmText.value = L10n.format("ai.logWaterQuantityQuestion", AppUnits.current.volumeText(Double(amount)))
                statusText.value = L10n.tr("ai.confirmWaterStatus")
            }
        }
        return items
    }

    @discardableResult
    private func confirm(_ action: AIAssistantAction, appendsFailureMessage: Bool = true) -> FoodEntry? {
        do {
            guard let confirmAIAssistantActionUseCase else {
                reportSaveFailure(L10n.tr("ai.confirmUnavailable"), appendsMessage: appendsFailureMessage)
                return nil
            }
            let entry = try confirmAIAssistantActionUseCase.execute(action)
            Analytics.tracker.track(.aiActionApplied(kind: action.analyticsKind, success: true))
            statusText.value = L10n.tr("ai.saved")
            return entry
        } catch {
            Analytics.tracker.track(.aiActionApplied(kind: action.analyticsKind, success: false))
            reportSaveFailure(error.localizedDescription, appendsMessage: appendsFailureMessage)
            return nil
        }
    }

    private func reportSaveFailure(_ message: String, appendsMessage: Bool = true) {
        statusText.value = message
        if appendsMessage {
            append(.init(kind: .system(L10n.format("ai.saveFailed", message))))
        }
    }

    private func displayedAssistantText(content: String, actions: [AIAssistantAction]) -> String? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasVisualProposal(actions) {
            if trimmed.isEmpty || isRedundantRecipeTitleList(trimmed, actions: actions) {
                return nil
            }
            return trimmed
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isRedundantRecipeTitleList(_ text: String, actions: [AIAssistantAction]) -> Bool {
        let titles = actions.flatMap { action -> [String] in
            guard case .mealSuggestions(let proposal) = action else { return [] }
            return proposal.options.map(\.title).filter { !$0.isEmpty }
        }
        guard titles.isEmpty == false else { return false }
        if let generated = recipeTitlesText(actions), text == generated {
            return true
        }
        if titles.count == 1 && (text == titles[0] || text == "1. \(titles[0])") {
            return true
        }
        return false
    }

    private func recipeTitlesText(_ actions: [AIAssistantAction]) -> String? {
        let titles = actions.flatMap { action -> [String] in
            guard case .mealSuggestions(let proposal) = action else { return [] }
            return proposal.options.map(\.title).filter { !$0.isEmpty }
        }
        guard !titles.isEmpty else { return nil }
        return titles.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }

    private func hasVisualProposal(_ actions: [AIAssistantAction]) -> Bool {
        actions.contains { action in
            switch action {
            case .logFood, .replaceFood, .swapFood, .mealSuggestions:
                return true
            default:
                return false
            }
        }
    }

    private func append(_ item: AIChatItem) {
        messages.value.append(item)
    }

    private func appendUserAndTyping(_ user: AIChatItem) {
        let typing = AIChatItem(kind: .typing)
        typingItemID = typing.id
        messages.value.append(contentsOf: [user, typing])
    }

    private func replaceTyping(with newItems: [AIChatItem]) {
        var current = messages.value
        defer { typingItemID = nil }
        guard let typingID = typingItemID, let index = current.firstIndex(where: { $0.id == typingID }) else {
            current.append(contentsOf: newItems)
            messages.value = current
            return
        }
        guard let first = newItems.first else {
            current.remove(at: index)
            messages.value = current
            return
        }
        current[index] = AIChatItem(id: typingID, kind: first.kind)
        if newItems.count > 1 {
            current.insert(contentsOf: Array(newItems.dropFirst()), at: index + 1)
        }
        messages.value = current
    }

    private func persistTurn(incoming: [AIChatItem], conversationID: UUID) {
        incoming.forEach { persist($0, conversationID: conversationID) }
    }

    private func recordCardActionInHistory(_ item: AIChatItem) {
        guard let historyItem = ChatHistoryVisualCodec.apiHistoryItem(from: item) else { return }
        history.append(historyItem)
        history = Array(history.suffix(20))
    }

    private func enrichDisplayedRecipes(_ items: [AIChatItem]) {
        guard searchFoodProductsUseCase != nil else { return }
        let recipes = items.compactMap { item -> (UUID, MealSuggestionOption, MealType)? in
            guard case .recipe(let option, let mealType) = item.kind else { return nil }
            return (item.id, option, mealType)
        }
        guard !recipes.isEmpty else { return }
        let conversationID = currentConversationID
        Task { @MainActor [weak self] in
            guard let self else { return }
            for (id, option, mealType) in recipes {
                let enriched = await self.enrichedMealSuggestion(option)
                guard self.currentConversationID == conversationID else { return }
                guard enriched != option else { continue }
                self.replaceRecipeContents(id: id, option: enriched, mealType: mealType)
                self.replacePendingMealSuggestion(from: option, to: enriched)
            }
        }
    }

    private func enrichedMealSuggestion(_ option: MealSuggestionOption) async -> MealSuggestionOption {
        guard option.needsNutritionEnrichment, let searchFoodProductsUseCase else { return option }
        let product: FoodProduct?
        let catalogId = option.externalRecipeId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !catalogId.isEmpty, catalogId.allSatisfy(\.isNumber) {
            product = try? await searchFoodProductsUseCase.recipeDetails(id: catalogId)
        } else {
            product = try? await searchFoodProductsUseCase.enrichDetails(
                title: option.title,
                imageURL: option.imageURL,
                source: FoodProductSource.openAI.rawValue,
                kind: FoodProductKind.recipe.rawValue
            )
        }
        guard let product else { return option }
        return option.merging(product)
    }

    private func persist(_ item: AIChatItem, conversationID: UUID? = nil) {
        guard let persistChatHistoryUseCase else { return }
        guard let encoded = ChatHistoryVisualCodec.encode(item) else { return }
        let conversationID = conversationID ?? currentConversationID
        do {
            try persistChatHistoryUseCase.append(
                id: item.id,
                role: encoded.role,
                content: encoded.content,
                conversationID: conversationID
            )
            if currentConversationID == conversationID {
                hasPersistedConversation = true
            }
        } catch {}
    }

    private func persistReplacement(_ item: AIChatItem) {
        guard let encoded = ChatHistoryVisualCodec.encode(item) else { return }
        try? persistChatHistoryUseCase?.replace(
            ChatHistoryMessage(
                id: item.id,
                role: encoded.role,
                content: encoded.content,
                createdAt: Date(),
                conversationID: currentConversationID
            )
        )
    }

    private func removePersistedLoggedMeal(entryID: UUID) {
        guard var stored = try? persistChatHistoryUseCase?.loadAll() else { return }
        stored.removeAll { message in
            guard (message.conversationID ?? ChatConversation.legacyID) == currentConversationID else { return false }
            guard message.role == "loggedMeal" else { return false }
            guard let item = ChatHistoryVisualCodec.chatItem(from: message),
                  case .loggedMeal(let id, _) = item.kind
            else {
                return false
            }
            return id == entryID
        }
        try? persistChatHistoryUseCase?.replaceAll(stored)
    }

    private func replaceRecipe(_ option: MealSuggestionOption, mealType: MealType, with item: AIChatItem) {
        if let index = messages.value.firstIndex(where: {
            if case .recipe(let current, let currentMealType) = $0.kind {
                return currentMealType == mealType && (current == option || current.title == option.title)
            }
            return false
        }) {
            let updated = AIChatItem(id: messages.value[index].id, kind: item.kind)
            messages.value[index] = updated
            persistReplacement(updated)
        } else {
            append(item)
            persist(item)
        }
    }

    private func replaceRecipeContents(id: UUID, option: MealSuggestionOption, mealType: MealType) {
        guard let index = messages.value.firstIndex(where: { $0.id == id }) else { return }
        guard case .recipe = messages.value[index].kind else { return }
        let updated = AIChatItem(id: id, kind: .recipe(option, mealType: mealType))
        messages.value[index] = updated
        persistReplacement(updated)
    }

    private func replacePendingMealSuggestion(from old: MealSuggestionOption, to new: MealSuggestionOption) {
        pendingActions.value = pendingActions.value.map { action in
            guard case .mealSuggestions(var proposal) = action else { return action }
            if let index = proposal.options.firstIndex(of: old) {
                proposal.options[index] = new
            }
            return .mealSuggestions(proposal)
        }
    }

    private func replaceSwap(_ proposal: FoodSwapProposal, with item: AIChatItem) {
        if let index = messages.value.firstIndex(where: {
            if case .swap(let current) = $0.kind { return current == proposal }
            return false
        }) {
            let updated = AIChatItem(id: messages.value[index].id, kind: item.kind)
            messages.value[index] = updated
            persistReplacement(updated)
        } else {
            append(item)
            persist(item)
        }
    }

    private func removePending(_ action: AIAssistantAction) {
        pendingActions.value.removeAll { $0 == action }
    }

    private func removePendingMealSuggestion(_ option: MealSuggestionOption, mealType: MealType) {
        pendingActions.value = pendingActions.value.compactMap { action in
            guard case .mealSuggestions(var proposal) = action else { return action }
            let proposalMealType = proposal.mealType
            proposal.options.removeAll {
                ($0.mealType ?? proposalMealType) == mealType && ($0 == option || $0.title == option.title)
            }
            return proposal.options.isEmpty ? nil : .mealSuggestions(proposal)
        }
    }

    private func removePendingSwap(_ proposal: FoodSwapProposal) {
        pendingActions.value.removeAll {
            if case .swapFood(let current) = $0 { return current == proposal }
            return false
        }
    }
}

private final class MissingProfileRepository: UserProfileRepositoryProtocol {
    func fetchProfile() throws -> UserProfile { .empty }
    func save(_ profile: UserProfile) throws {}
}

private final class MissingPreferenceRepository: UserPreferenceRepositoryProtocol {
    func fetchAll() throws -> [UserPreference] { [] }
    func save(_ preference: UserPreference) throws {}
    func delete(id: UUID) throws {}
}
