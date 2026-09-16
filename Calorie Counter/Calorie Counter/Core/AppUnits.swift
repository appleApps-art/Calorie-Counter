import Foundation

/// Presentation units only. Persistence, nutrition calculations and HealthKit stay metric.
struct AppUnits {
    let usesMetric: Bool
    static var current: AppUnits { AppUnits(usesMetric: AppSettingsStore().settings.usesMetric) }
    static let gramsPerOunce = 28.349523125
    static let millilitersPerFluidOunce = 29.5735295625
    var weightSymbol: String { L10n.tr(usesMetric ? "onboarding.body.kg" : "onboarding.body.lb") }
    var volumeSymbol: String { usesMetric ? L10n.tr("search.unit.milliliters") : "fl oz" }
    var portionSymbol: String { usesMetric ? L10n.tr("search.unit.grams") : "oz" }
    func weight(_ kilograms: Double) -> Double { usesMetric ? kilograms : kilograms * WeightConversion.poundsPerKilogram }
    func volume(_ milliliters: Double) -> Double { usesMetric ? milliliters : milliliters / Self.millilitersPerFluidOunce }
    func mass(_ grams: Double) -> Double { usesMetric ? grams : grams / Self.gramsPerOunce }
    func milliliters(_ displayed: Double) -> Double { usesMetric ? displayed : displayed * Self.millilitersPerFluidOunce }
    func weightText(_ kilograms: Double, signed: Bool = false) -> String {
        String(format: signed ? "%+.1f %@" : "%.1f %@", locale: .current, weight(kilograms), weightSymbol)
    }
    func volumeText(_ milliliters: Double) -> String { "\(number(volume(milliliters))) \(volumeSymbol)" }
    func massText(_ grams: Double) -> String { "\(number(mass(grams))) \(portionSymbol)" }
    func quantity(_ amount: Double, unit: String) -> String? {
        switch unit.lowercased() {
        case "g", "gr", "gram", "grams", "г": return massText(amount)
        case "ml", "milliliter", "milliliters", "мл": return volumeText(amount)
        default: return nil
        }
    }
    func number(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = usesMetric ? 1 : 2
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
    /// Convert explicit imperial quantities before existing metric parsers consume them.
    static func metricInput(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+(?:[.,]\d+)?)\s*(fl\s*oz|oz|lbs?|фунт(?:и|ів)?)\b"#, options: .caseInsensitive) else { return text }
        var output = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: output), let numberRange = Range(match.range(at: 1), in: text), let unitRange = Range(match.range(at: 2), in: text), let value = Double(text[numberRange].replacingOccurrences(of: ",", with: ".")) else { continue }
            let unit = text[unitRange].lowercased()
            let liquid = unit.hasPrefix("fl")
            let factor = liquid ? millilitersPerFluidOunce : unit == "oz" ? gramsPerOunce : 453.59237
            output.replaceSubrange(range, with: "\(value * factor) \(liquid ? "ml" : "g")")
        }
        return output
    }
}
