import Foundation

struct AIAssistantChatHistoryItem: Codable, Equatable {
    let role: String
    let content: String
}

struct AIAssistantUserContext: Codable, Equatable {
    var locale: String?
    var timezone: String?
    var goals: Goals?
    var today: Today?
    var preferences: Preferences?
    var profile: Profile?
    var recipe: RecipeContext?

    struct Goals: Codable, Equatable {
        var calorieTarget: Double?
        var proteinTarget: Double?
        var carbsTarget: Double?
        var fatsTarget: Double?
        var fiberTarget: Double?
        var sugarTarget: Double?
        var sodiumTarget: Double?
        var waterTargetMilliliters: Double?
    }

    struct Today: Codable, Equatable {
        var date: String?
        var consumedCalories: Double?
        var remainingCalories: Double?
        var protein: Double?
        var carbs: Double?
        var fats: Double?
        var waterMilliliters: Double?
        var meals: [Meal]?
    }

    struct Meal: Codable, Equatable {
        var id: String?
        var name: String
        var mealType: String?
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fats: Double?
        var portionGrams: Double?
    }

    struct Preferences: Codable, Equatable {
        var allergies: [String]?
        var dislikes: [String]?
        var diet: String?
        var goalType: String?
    }

    struct Profile: Codable, Equatable {
        var sex: String?
        var age: Int?
        var heightCm: Double?
        var weightKg: Double?
    }

    struct RecipeContext: Codable, Equatable {
        var externalId: String?
        var title: String
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fats: Double?
        var ingredients: [Ingredient]?

        struct Ingredient: Codable, Equatable {
            var name: String
            var amount: Double?
            var unit: String?
        }
    }
}

struct AIAssistantChatRequest: Codable, Equatable {
    let message: String
    let history: [AIAssistantChatHistoryItem]
    let userContext: AIAssistantUserContext?
    let imageBase64: String?
    let imageMimeType: String?
}

struct AIAssistantToolCall: Codable, Equatable {
    let id: String
    let name: String
    let arguments: [String: AnyCodable]
}

struct AIAssistantChatMessage: Codable, Equatable {
    let role: String
    let content: String
    let toolCalls: [AIAssistantToolCall]

    init(role: String, content: String, toolCalls: [AIAssistantToolCall]) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "assistant"
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        toolCalls = try container.decodeIfPresent([AIAssistantToolCall].self, forKey: .toolCalls) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls
    }
}

struct AIAssistantChatResponse: Codable, Equatable {
    let mode: String?
    let model: String?
    let message: AIAssistantChatMessage
    let hasActions: Bool?
    let error: String?
}

enum AIAssistantServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(message: String)
    case decodingFailed
    case transport(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid AI assistant URL"
        case .invalidResponse:
            return "Invalid AI assistant response"
        case .server(let message):
            return message
        case .decodingFailed:
            return "Failed to decode AI assistant response"
        case .transport(let underlying):
            return underlying.localizedDescription
        }
    }
}

struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map(AnyCodable.init))
        case let dict as [String: Any]:
            try container.encode(dict.mapValues(AnyCodable.init))
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}
