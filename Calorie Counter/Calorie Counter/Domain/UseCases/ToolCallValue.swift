import Foundation

enum ToolCallValue {
    static func number(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    static func string(_ value: Any?) -> String? {
        value as? String
    }

    static func dictionary(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    static func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings
        }
        if let items = value as? [Any] {
            return items.compactMap { $0 as? String }
        }
        return []
    }

    static func uuid(_ value: Any?) -> UUID? {
        guard let raw = value as? String else { return nil }
        return UUID(uuidString: raw)
    }

    static func mealType(_ value: Any?, fallback: MealType = .snacks) -> MealType {
        MealType(rawValue: (value as? String) ?? "") ?? fallback
    }
}
