import Foundation

enum ChatHistoryVisualCodec {
    struct RecipePayload: Codable, Equatable {
        var mealType: MealType
        var option: MealSuggestionOption
    }

    struct LoggedMealPayload: Codable, Equatable {
        var entryID: UUID?
        var proposal: FoodLogProposal
    }

    static func encode(_ item: AIChatItem) -> (role: String, content: String)? {
        switch item.kind {
        case .user(let text):
            return ("user", text)
        case .assistant(let text):
            return ("assistant", text)
        case .system(let text):
            return ("system", text)
        case .recipe(let option, let mealType):
            return encode("recipe", RecipePayload(mealType: mealType, option: option))
        case .swap(let proposal):
            return encode("swap", proposal)
        case .loggedMeal(let entryID, let proposal):
            return encode("loggedMeal", LoggedMealPayload(entryID: entryID, proposal: proposal))
        case .typing, .mealPlan:
            // The plan card is context, not conversation: it travels in USER_CONTEXT_JSON.
            return nil
        }
    }

    static func chatItem(from message: ChatHistoryMessage) -> AIChatItem? {
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        switch message.role {
        case "user":
            return content.isEmpty ? nil : AIChatItem(id: message.id, kind: .user(content))
        case "assistant":
            return content.isEmpty ? nil : AIChatItem(id: message.id, kind: .assistant(content))
        case "system":
            return content.isEmpty ? nil : AIChatItem(id: message.id, kind: .system(content))
        case "recipe":
            guard let payload = decode(RecipePayload.self, from: message.content) else { return nil }
            return AIChatItem(id: message.id, kind: .recipe(payload.option, mealType: payload.mealType))
        case "swap":
            guard let proposal = decode(FoodSwapProposal.self, from: message.content) else { return nil }
            return AIChatItem(id: message.id, kind: .swap(proposal))
        case "loggedMeal":
            guard let payload = decode(LoggedMealPayload.self, from: message.content) else { return nil }
            return AIChatItem(id: message.id, kind: .loggedMeal(entryID: payload.entryID, proposal: payload.proposal))
        default:
            return content.isEmpty ? nil : AIChatItem(id: message.id, kind: .system(content))
        }
    }

    static func apiHistoryItem(from item: AIChatItem) -> AIAssistantChatHistoryItem? {
        guard let encoded = encode(item) else { return nil }
        return apiHistoryItem(from: ChatHistoryMessage(
            id: item.id,
            role: encoded.role,
            content: encoded.content,
            createdAt: Date()
        ))
    }

    static func apiHistoryItem(from message: ChatHistoryMessage) -> AIAssistantChatHistoryItem? {
        switch message.role {
        case "user":
            let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : AIAssistantChatHistoryItem(role: "user", content: text)
        case "assistant", "system":
            let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : AIAssistantChatHistoryItem(role: "assistant", content: text)
        case "recipe":
            guard let payload = decode(RecipePayload.self, from: message.content) else { return nil }
            let title = payload.option.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : AIAssistantChatHistoryItem(
                role: "assistant",
                content: "Suggested meal (not logged): \(message.content)"
            )
        case "swap":
            guard decode(FoodSwapProposal.self, from: message.content) != nil else { return nil }
            return AIAssistantChatHistoryItem(
                role: "assistant",
                content: "Suggested food swap (not applied): \(message.content)"
            )
        case "loggedMeal":
            guard decode(LoggedMealPayload.self, from: message.content) != nil else { return nil }
            return AIAssistantChatHistoryItem(
                role: "assistant",
                content: "Logged meal: \(message.content)"
            )
        default:
            return nil
        }
    }

    static func preview(role: String, content: String) -> String {
        let raw: String
        switch role {
        case "recipe":
            raw = decode(RecipePayload.self, from: content)?.option.title ?? ""
        case "swap":
            raw = decode(FoodSwapProposal.self, from: content)?.alternative.name ?? ""
        case "loggedMeal":
            raw = decode(LoggedMealPayload.self, from: content)?.proposal.name ?? ""
        default:
            // History rows show one plain line; the reply's Markdown stays in the chat itself.
            raw = ChatMarkdownRenderer.plainText(content)
        }
        return collapsedListText(raw)
    }

    static func collapsedListText(_ text: String) -> String {
        text.split { $0.isNewline || $0.isWhitespace }.joined(separator: " ")
    }

    static func isAssistantSide(_ role: String) -> Bool {
        switch role {
        case "assistant", "system", "recipe", "swap", "loggedMeal":
            return true
        default:
            return false
        }
    }

    private static func encode<T: Encodable>(_ role: String, _ value: T) -> (role: String, content: String)? {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return (role, json)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from content: String) -> T? {
        guard let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
