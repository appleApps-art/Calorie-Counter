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
    /// The user's locale for numbers and dates, always with the digits 0-9. Translations write
    /// numbers too ("%d/100", "100 г"), and Arabic-Indic digits from an Arabic region would sit
    /// next to them on the same line.
    nonisolated static var appFormatting: Locale {
        Locale.current.withLatinDigits()
    }

    /// The same locale writing digits as 0-9 (store prices come in the storefront's locale).
    nonisolated func withLatinDigits() -> Locale {
        guard numberingSystem.identifier != "latn" else { return self }
        var components = Locale.Components(locale: self)
        components.numberingSystem = "latn"
        return Locale(components: components)
    }

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
