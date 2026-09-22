import XCTest
@testable import Calorie_Counter

/// Every shipped language must carry the same keys and format arguments as English, so a missing
/// translation never shows a raw key and a translated format never crashes `String(format:)`.
final class LocalizationCompletenessTests: XCTestCase {
    private let languages = ["en", "uk", "ar", "zh-Hans", "zh-Hant", "fr", "de", "it", "ja", "ko", "pt-BR", "es", "tr", "vi"]

    func testTheAppShipsEveryLanguage() {
        let shipped = Set(Bundle.main.localizations.filter { $0 != "Base" })
        XCTAssertEqual(shipped, Set(languages))
        let declared = Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String] ?? []
        XCTAssertEqual(Set(declared), Set(languages), "Info.plist lists the same languages")
    }

    func testEveryLanguageHasEveryKeyWithTheSameFormatArguments() throws {
        let english = try strings("en")
        XCTAssertGreaterThan(english.count, 900)
        for language in languages where language != "en" {
            let translated = try strings(language)
            let missing = Set(english.keys).subtracting(translated.keys)
            XCTAssertTrue(missing.isEmpty, "\(language) misses \(missing.sorted().prefix(10))")
            for (key, value) in english {
                guard let text = translated[key] else { continue }
                XCTAssertEqual(Self.arguments(text), Self.arguments(value), "\(language) \(key): \(text)")
                XCTAssertFalse(text.trimmingCharacters(in: .whitespaces).isEmpty, "\(language) \(key) is empty")
            }
        }
    }

    func testNoTranslationUsesALongDash() throws {
        for language in languages {
            for (key, text) in try strings(language) {
                XCTAssertFalse(text.contains("—") || text.contains("–"), "\(language) \(key): \(text)")
            }
        }
    }

    func testPermissionPromptsAreTranslated() throws {
        let keys = ["NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription",
                    "NSPhotoLibraryUsageDescription", "NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"]
        let english = try strings("en", table: "InfoPlist")
        for language in languages {
            let prompts = try strings(language, table: "InfoPlist")
            for key in keys {
                let text = try XCTUnwrap(prompts[key], "\(language) \(key)")
                XCTAssertFalse(text.isEmpty)
                if language != "en" { XCTAssertNotEqual(text, english[key], "\(language) \(key) is translated") }
            }
        }
    }

    func testPluralsFollowEachLanguage() throws {
        XCTAssertEqual(try plural("rewards.swaps", 1, in: "en"), "1 swap")
        XCTAssertEqual(try plural("rewards.swaps", 5, in: "en"), "5 swaps")
        XCTAssertEqual(try plural("rewards.swaps", 1, in: "fr"), "1 remplacement")
        XCTAssertEqual(try plural("rewards.swaps", 3, in: "fr"), "3 remplacements")
        XCTAssertEqual(try plural("rewards.swaps", 2, in: "ar"), "2 استبدالين")
        XCTAssertEqual(try plural("rewards.swaps", 4, in: "ar"), "4 استبدالات")
        XCTAssertEqual(try plural("rewards.swaps", 12, in: "ar"), "12 استبدالًا")
        XCTAssertEqual(try plural("rewards.swaps", 3, in: "ja"), "置き換え3回")
        XCTAssertEqual(try plural("rewards.dayStreakPill", 7, in: "de"), "7-TAGE-SERIE")
        for language in languages {
            let text = try plural("rewards.swapsProgress", 2, 5, in: language)
            XCTAssertTrue(text.contains("2") && text.contains("5"), "\(language): \(text)")
        }
    }

    func testCatalogPicksTheRegionalChineseAndPortugueseNames() {
        XCTAssertEqual(AIFoodSearchService.catalogLanguageKeys(for: "zh-Hant-TW").first, "zh-hant")
        XCTAssertEqual(AIFoodSearchService.catalogLanguageKeys(for: "zh-Hans-CN").first, "zh")
        XCTAssertEqual(AIFoodSearchService.catalogLanguageKeys(for: "zh_TW").first, "zh-hant")
        XCTAssertEqual(AIFoodSearchService.catalogLanguageKeys(for: "pt-BR").first, "pt-br")
        XCTAssertEqual(AIFoodSearchService.catalogLanguageKeys(for: "fr-FR"), ["fr"])
        XCTAssertEqual(AIFoodSearchService.catalogLanguageKeys(for: ""), ["en"])

        let json = """
        {"sections":[{"id":"fruitsBerries","items":[{"id":"catalog.apple","name":{"en":"Apple","zh":"苹果","zh-hant":"蘋果","pt-br":"Maçã"},"serving":{"en":"1 medium (180 g)","zh-hant":"中等大小 1 個（180 g）"},"calories":94}]}]}
        """
        let data = Data(json.utf8)
        XCTAssertEqual(AIFoodSearchService.decodeCatalog(from: data, locale: "zh-Hant-TW")["fruitsBerries"]?.first?.name, "蘋果")
        XCTAssertEqual(AIFoodSearchService.decodeCatalog(from: data, locale: "zh-Hans-CN")["fruitsBerries"]?.first?.name, "苹果")
        XCTAssertEqual(AIFoodSearchService.decodeCatalog(from: data, locale: "pt-BR")["fruitsBerries"]?.first?.name, "Maçã")
        XCTAssertEqual(AIFoodSearchService.decodeCatalog(from: data, locale: "de-DE")["fruitsBerries"]?.first?.name, "Apple")
    }

    func testBundledCatalogNamesEveryFoodInEveryLanguage() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "food-search-catalog", withExtension: "json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let sections = try XCTUnwrap(root["sections"] as? [[String: Any]])
        let keys = ["en", "uk", "fr", "de", "it", "es", "pt-br", "tr", "ja", "ko", "zh", "zh-hant", "vi", "ar"]
        for item in sections.flatMap({ $0["items"] as? [[String: Any]] ?? [] }) {
            let names = try XCTUnwrap(item["name"] as? [String: String])
            let servings = try XCTUnwrap(item["serving"] as? [String: String])
            for key in keys {
                XCTAssertFalse(names[key]?.isEmpty ?? true, "\(item["id"] ?? "") name \(key)")
                XCTAssertFalse(servings[key]?.isEmpty ?? true, "\(item["id"] ?? "") serving \(key)")
            }
        }
    }

    func testDateRangesNeverShowALongDash() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let text = MealPlanDatesText.summary(for: [start, end])
        XCTAssertFalse(text.contains("—") || text.contains("–"), text)
        XCTAssertTrue(text.contains("24") && text.contains("26"), text)
    }

    // MARK: - Helpers

    private func strings(_ language: String, table: String = "Localizable") throws -> [String: String] {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: table, ofType: "strings", inDirectory: nil, forLocalization: language),
            "\(language) \(table).strings"
        )
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String], "\(language) \(table) parses")
    }

    private func plural(_ key: String, _ values: CVarArg..., in language: String) throws -> String {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let format = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        return String(format: format, locale: Locale(identifier: language), arguments: values)
    }

    /// Positional and sequential arguments, normalised to (position, kind), plus literal "%%".
    private static func arguments(_ text: String) -> [String] {
        let pattern = #"%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|L|z|t|j)?([@dDuUxXoOfeEgGcCsSpaAF%])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var next = 0
        var result: [String] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let kindRange = Range(match.range(at: 2), in: text) else { continue }
            var kind = String(text[kindRange])
            if kind == "%" { result.append("%%"); continue }
            if ["D", "u", "U", "i"].contains(kind) { kind = "d" }
            if ["e", "E", "g", "G", "f", "F"].contains(kind) { kind = "f" }
            let position: Int
            if let positionRange = Range(match.range(at: 1), in: text), let value = Int(text[positionRange]) {
                position = value
            } else {
                next += 1
                position = next
            }
            result.append("\(position)\(kind)")
        }
        return result.sorted()
    }
}
