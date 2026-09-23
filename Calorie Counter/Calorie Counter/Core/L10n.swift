import Foundation

enum L10n {
    static func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: Locale.appFormatting, arguments: arguments)
    }
}

extension Locale {
    nonisolated static var deviceIdentifier: String {
        if let language = (CFLocaleCopyPreferredLanguages() as NSArray).firstObject as? NSString {
            let value = language as String
            if !value.isEmpty { return value }
        }
        return "en"
    }
}

extension String {
    /// System formatters (date intervals) use "–" and "—"; Bity's copy never shows long dashes.
    var withShortDashes: String {
        replacingOccurrences(of: "—", with: "-").replacingOccurrences(of: "–", with: "-")
    }
}
