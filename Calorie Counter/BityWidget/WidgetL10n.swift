import Foundation

enum WidgetL10n {
    /// `Bundle.main` inside an extension is the extension's own bundle, which carries the widget's
    /// `.lproj` folders.
    static func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: Locale.appFormatting, arguments: arguments)
    }
}
