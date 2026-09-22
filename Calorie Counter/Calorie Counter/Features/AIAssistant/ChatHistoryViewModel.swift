import Foundation

enum ChatHistoryFilter: Equatable {
    case all
    case category(AIChatCategory)
}

struct ChatHistoryRowItem: Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let timeText: String
    let date: Date
    let category: AIChatCategory?
}

struct ChatHistorySection: Equatable {
    let title: String
    let rows: [ChatHistoryRowItem]
}

final class ChatHistoryViewModel {
    let errorMessage = Observable<String?>(nil)
    var hasHistory: Bool { !conversations.isEmpty }

    let titleText = Observable(L10n.tr("ai.history.title"))
    let searchText = Observable("")
    let isRecording = Observable(false)
    let canConfirmVoice = Observable(false)
    let selectedFilter = Observable(ChatHistoryFilter.all)
    let sections = Observable<[ChatHistorySection]>([])

    private let persistChatHistoryUseCase: PersistChatHistoryUseCase
    private let dictation: VoiceConfirmDictation?
    private var conversations: [ChatHistoryRowItem] = []
    private var searchableText: [UUID: String] = [:]
    private var conversationCategories: [UUID: Set<AIChatCategory>] = [:]
    private var chipCategories: [String: AIChatCategory] = [:]
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .appFormatting
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    private let olderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .appFormatting
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    init(
        persistChatHistoryUseCase: PersistChatHistoryUseCase,
        voiceRecorder: VoiceFoodAudioRecording? = nil,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase? = nil
    ) {
        self.persistChatHistoryUseCase = persistChatHistoryUseCase
        if let voiceRecorder, let transcribeFoodVoiceUseCase {
            self.dictation = VoiceConfirmDictation(
                recorder: voiceRecorder,
                transcribeFoodVoiceUseCase: transcribeFoodVoiceUseCase,
                combineWithAnchor: true
            )
        } else {
            self.dictation = nil
        }
        dictation?.onText = { [weak self] text in
            self?.updateSearch(text)
        }
        dictation?.isRecording.bind { [weak self] value in
            self?.isRecording.value = value
        }
        dictation?.canConfirm.bind { [weak self] value in
            self?.canConfirmVoice.value = value
        }
        reload()
    }

    func reload() {
        let saved: [ChatConversation]
        do {
            saved = try persistChatHistoryUseCase.conversations()
        } catch {
            errorMessage.value = L10n.tr("ai.history.loadError")
            return
        }
        searchableText = [:]
        conversationCategories = [:]
        refreshChipCategories()
        conversations = saved.compactMap(makeRow)
        applyFilters()
    }

    func updateSearch(_ text: String) {
        searchText.value = text
        dictation?.clearConfirmIfEmpty(text)
        applyFilters()
    }

    func clearSearch() {
        dictation?.cancel()
        canConfirmVoice.value = false
        searchText.value = ""
        applyFilters()
    }

    func selectFilter(_ filter: ChatHistoryFilter) {
        selectedFilter.value = filter
        applyFilters()
    }

    func deleteAll() {
        do {
            try persistChatHistoryUseCase.deleteAll()
            clearSearch()
            selectedFilter.value = .all
            reload()
        } catch {
            errorMessage.value = L10n.tr("ai.history.clearError")
        }
    }

    func stopDictation() {
        dictation?.cancel()
        dictation?.consumeConfirm()
    }

    func toggleVoiceTapped() {
        if canConfirmVoice.value {
            dictation?.consumeConfirm()
            return
        }
        if isRecording.value {
            dictation?.finish()
        } else {
            dictation?.start(anchor: searchText.value)
        }
    }

    private func applyFilters() {
        let query = searchText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = conversations.filter { row in
            if case .category(let category) = selectedFilter.value,
               conversationCategories[row.id]?.contains(category) != true {
                return false
            }
            guard query.isEmpty == false else { return true }
            return row.title.localizedCaseInsensitiveContains(query)
                || searchableText[row.id]?.localizedCaseInsensitiveContains(query) == true
        }
        sections.value = group(filtered)
    }

    private func makeRow(_ conversation: ChatConversation) -> ChatHistoryRowItem? {
        let messages = conversation.messages
        let users = messages.filter { $0.role == "user" }
        // A chip often starts a conversation; a following concrete request makes a
        // more useful title than repeated rows named "Meal ideas".
        guard let user = users.first(where: { category(for: $0) == nil }) ?? users.first,
              let latest = messages.last else { return nil }
        let title = conversation.id == ChatConversation.legacyID
            ? L10n.tr("ai.history.legacyTitle")
            : ChatHistoryVisualCodec.collapsedListText(user.content)
        let categories = messages.compactMap(category)
        conversationCategories[conversation.id] = Set(categories)
        searchableText[conversation.id] = messages.map {
            ChatHistoryVisualCodec.preview(role: $0.role, content: $0.content)
        }.joined(separator: "\n")
        let preview = messages.reversed().lazy
            .filter { ChatHistoryVisualCodec.isAssistantSide($0.role) }
            .map { ChatHistoryVisualCodec.preview(role: $0.role, content: $0.content) }
            .first { !$0.isEmpty } ?? ""
        return ChatHistoryRowItem(
            id: conversation.id,
            title: title,
            subtitle: preview,
            timeText: timeFormatter.string(from: latest.createdAt),
            date: latest.createdAt,
            category: categories.last
        )
    }

    private func category(for message: ChatHistoryMessage) -> AIChatCategory? {
        switch message.role {
        case "recipe": return .meals
        case "swap": return .swaps
        case "loggedMeal": return .nutrition
        case "user":
            let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return chipCategories[text.lowercased()]
        default: return nil
        }
    }

    private func refreshChipCategories() {
        // Resolve translations once per reload, including old chats written in
        // the other supported language.
        let bundles = Bundle.main.localizations.filter { $0 != "Base" }.compactMap { language -> Bundle? in
            guard let path = Bundle.main.path(forResource: language, ofType: "lproj") else { return nil }
            return Bundle(path: path)
        }
        chipCategories = [:]
        for category in AIChatCategory.allCases {
            let titles = [L10n.tr(category.titleKey)] + bundles.map {
                $0.localizedString(forKey: category.titleKey, value: nil, table: nil)
            }
            for title in titles { chipCategories[title.lowercased()] = category }
        }
    }

    private func group(_ rows: [ChatHistoryRowItem]) -> [ChatHistorySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: rows) { row in
            calendar.startOfDay(for: row.date)
        }
        return grouped.keys.sorted(by: >).compactMap { day in
            let dayRows = (grouped[day] ?? []).sorted { $0.date > $1.date }
            guard dayRows.isEmpty == false else { return nil }
            return ChatHistorySection(title: dayTitle(for: day), rows: dayRows)
        }
    }

    private func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.tr("ai.history.today")
        }
        if calendar.isDateInYesterday(date) {
            return L10n.tr("ai.history.yesterday")
        }
        return olderDateFormatter.string(from: date)
    }
}
