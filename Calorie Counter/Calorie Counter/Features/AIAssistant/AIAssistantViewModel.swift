import Foundation

struct AIAssistantDisplayedMessage: Equatable {
    enum Role: Equatable {
        case user
        case assistant
        case system
    }

    let role: Role
    let text: String
}

final class AIAssistantViewModel {
    let titleText = Observable(L10n.tr("ai.title"))
    let conversationText = Observable(L10n.tr("ai.welcomeShort"))
    let inputText = Observable("")
    let statusText = Observable("")
    let isSending = Observable(false)
    let pendingWaterConfirmText = Observable<String?>(nil)
    let pendingActions = Observable<[AIAssistantAction]>([])

    var onRecipeIngredientSwapProposed: ((RecipeIngredientSwapProposal) -> Void)?

    private let aiAssistantService: AIAssistantServiceProtocol
    private let buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase
    private let parseAIAssistantActionsUseCase: ParseAIAssistantActionsUseCase
    private let confirmAIAssistantActionUseCase: ConfirmAIAssistantActionUseCase?
    private let persistChatHistoryUseCase: PersistChatHistoryUseCase?
    private let recipeContext: Recipe?
    private var history: [AIAssistantChatHistoryItem] = []
    private var displayedMessages: [AIAssistantDisplayedMessage]
    private var pendingWaterProposal: WaterLogProposal?

    init(
        aiAssistantService: AIAssistantServiceProtocol,
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        logWaterUseCase: LogWaterUseCase? = nil,
        recipeContext: Recipe? = nil,
        initialInput: String? = nil,
        buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase? = nil,
        parseAIAssistantActionsUseCase: ParseAIAssistantActionsUseCase = ParseAIAssistantActionsUseCase(),
        confirmAIAssistantActionUseCase: ConfirmAIAssistantActionUseCase? = nil,
        persistChatHistoryUseCase: PersistChatHistoryUseCase? = nil
    ) {
        self.aiAssistantService = aiAssistantService
        self.parseAIAssistantActionsUseCase = parseAIAssistantActionsUseCase
        self.confirmAIAssistantActionUseCase = confirmAIAssistantActionUseCase
        self.persistChatHistoryUseCase = persistChatHistoryUseCase
        self.recipeContext = recipeContext
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
            displayedMessages = [
                .init(role: .system, text: L10n.tr("ai.recipeMode"))
            ]
            titleText.value = L10n.tr("ai.replaceIngredientTitle")
            conversationText.value = displayedMessages[0].text
        } else {
            displayedMessages = [
                .init(role: .system, text: L10n.tr("ai.welcome"))
            ]
        }
        if let initialInput, !initialInput.isEmpty {
            inputText.value = initialInput
        }
        if let stored = try? persistChatHistoryUseCase?.load(), !stored.isEmpty {
            history = stored.suffix(20).map { AIAssistantChatHistoryItem(role: $0.role, content: $0.content) }
        }
        _ = logWaterUseCase
    }

    func updateInput(_ text: String) {
        inputText.value = text
    }

    func sendTapped() {
        let trimmed = inputText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending.value else { return }

        isSending.value = true
        statusText.value = L10n.tr("ai.sending")
        inputText.value = ""
        appendDisplayed(.init(role: .user, text: trimmed))

        Task { @MainActor in
            do {
                let context = try buildAIAssistantUserContextUseCase.execute(recipe: recipeContext)
                let response = try await aiAssistantService.chat(
                    AIAssistantChatRequest(
                        message: trimmed,
                        history: history,
                        userContext: context,
                        imageBase64: nil,
                        imageMimeType: nil
                    )
                )

                let content = response.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                let actions = parseAIAssistantActionsUseCase.execute(toolCalls: response.message.toolCalls)
                pendingActions.value = actions

                var assistantText = content
                if !actions.isEmpty {
                    let labels = actions.map(Self.label(for:)).joined(separator: ", ")
                    assistantText = assistantText.isEmpty
                        ? L10n.format("ai.actionsPrefix", labels)
                        : assistantText + "\n\n" + L10n.format("ai.actionsPrefix", labels)
                }

                if let swap = actions.compactMap({ action -> RecipeIngredientSwapProposal? in
                    if case .swapRecipeIngredient(let proposal) = action { return proposal }
                    return nil
                }).first {
                    onRecipeIngredientSwapProposed?(swap)
                    statusText.value = L10n.tr("ai.confirmSwapStatus")
                }

                if let water = actions.compactMap({ action -> WaterLogProposal? in
                    if case .logWater(let proposal) = action { return proposal }
                    return nil
                }).first {
                    pendingWaterProposal = water
                    let amount = Int(water.amountMilliliters.rounded())
                    let summary = L10n.format("ai.logWaterQuestion", amount)
                    pendingWaterConfirmText.value = summary
                    statusText.value = L10n.tr("ai.confirmWaterStatus")
                }

                if assistantText.isEmpty {
                    assistantText = L10n.tr("ai.noText")
                }

                history.append(.init(role: "user", content: trimmed))
                history.append(.init(role: "assistant", content: content.isEmpty ? assistantText : content))
                if history.count > 20 {
                    history = Array(history.suffix(20))
                }
                try? persistChatHistoryUseCase?.append(role: "user", content: trimmed)
                try? persistChatHistoryUseCase?.append(role: "assistant", content: content.isEmpty ? assistantText : content)

                appendDisplayed(.init(role: .assistant, text: assistantText))
                if statusText.value == L10n.tr("ai.sending") {
                    statusText.value = actions.isEmpty ? L10n.tr("common.done") : L10n.tr("ai.confirmToSave")
                }
            } catch {
                appendDisplayed(.init(role: .system, text: L10n.format("ai.errorPrefix", error.localizedDescription)))
                statusText.value = L10n.tr("ai.failed")
            }

            isSending.value = false
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
        appendDisplayed(.init(role: .system, text: L10n.tr("ai.waterCancelledMessage")))
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
        do {
            try confirmAIAssistantActionUseCase?.executeMealSuggestion(
                proposal.options[optionIndex],
                mealType: proposal.mealType
            )
            var remaining = pendingActions.value
            remaining.remove(at: actionIndex)
            pendingActions.value = remaining
            appendDisplayed(.init(role: .system, text: L10n.format("ai.savedPrefix", proposal.options[optionIndex].title)))
            statusText.value = L10n.tr("ai.saved")
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func confirmAllPendingActions() {
        let actions = pendingActions.value
        pendingActions.value = []
        for action in actions {
            if case .mealSuggestions = action {
                continue
            }
            confirm(action)
        }
    }

    func rejectPendingActions() {
        pendingActions.value = []
        pendingWaterProposal = nil
        pendingWaterConfirmText.value = nil
        statusText.value = L10n.tr("ai.actionsCancelled")
    }

    private func confirm(_ action: AIAssistantAction) {
        do {
            guard let confirmAIAssistantActionUseCase else {
                statusText.value = L10n.tr("ai.confirmUnavailable")
                return
            }
            try confirmAIAssistantActionUseCase.execute(action)
            appendDisplayed(.init(role: .system, text: L10n.format("ai.savedPrefix", Self.label(for: action))))
            statusText.value = L10n.tr("ai.saved")
        } catch {
            statusText.value = error.localizedDescription
            appendDisplayed(.init(role: .system, text: L10n.format("ai.saveFailed", error.localizedDescription)))
        }
    }

    private func appendDisplayed(_ message: AIAssistantDisplayedMessage) {
        displayedMessages.append(message)
        conversationText.value = displayedMessages.map { item in
            switch item.role {
            case .user:
                return L10n.format("ai.youPrefix", item.text)
            case .assistant:
                return L10n.format("ai.avoPrefix", item.text)
            case .system:
                return item.text
            }
        }.joined(separator: "\n\n")
    }

    private static func label(for action: AIAssistantAction) -> String {
        switch action {
        case .logFood(let proposal):
            return L10n.format("ai.action.logFood", proposal.name)
        case .replaceFood:
            return L10n.tr("ai.action.replaceFood")
        case .swapFood:
            return L10n.tr("ai.action.swapFood")
        case .mealSuggestions:
            return L10n.tr("ai.action.mealSuggestions")
        case .saveRecipe(let proposal):
            return L10n.format("ai.action.saveRecipe", proposal.title)
        case .swapRecipeIngredient:
            return L10n.tr("ai.action.swapIngredient")
        case .logWater(let proposal):
            return L10n.format("ai.action.logWater", Int(proposal.amountMilliliters.rounded()))
        case .savePreference(let proposal):
            return L10n.format("ai.action.savePreference", proposal.value)
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
