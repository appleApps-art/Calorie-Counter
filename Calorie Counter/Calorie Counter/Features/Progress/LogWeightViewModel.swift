import Foundation

enum WeightUnit: Int {
    case kilograms = 0
    case pounds = 1

    var titleKey: String {
        switch self {
        case .kilograms:
            return "onboarding.body.kg"
        case .pounds:
            return "logWeight.unit.lbs"
        }
    }

    var sliderMin: Double {
        switch self {
        case .kilograms:
            return 30
        case .pounds:
            return 66
        }
    }

    var sliderMax: Double {
        switch self {
        case .kilograms:
            return 200
        case .pounds:
            return 440
        }
    }
}

enum WeightConversion {
    static let poundsPerKilogram = 2.204_622_621_8

    static func pounds(fromKilograms kilograms: Double) -> Double {
        kilograms * poundsPerKilogram
    }

    static func kilograms(fromPounds pounds: Double) -> Double {
        pounds / poundsPerKilogram
    }
}

final class LogWeightViewModel {
    let titleText = Observable(L10n.tr("logWeight.title"))
    let sectionTitleText = Observable(L10n.tr("logWeight.enterWeight"))
    let unitIndex = Observable(WeightUnit.kilograms.rawValue)
    let displayValueText = Observable("")
    let unitLabelText = Observable(L10n.tr("onboarding.body.kg"))
    let sliderValue = Observable(Float(60))
    let sliderMinimum = Observable(Float(30))
    let sliderMaximum = Observable(Float(200))
    let dateText = Observable("")
    let errorText = Observable("")

    var onBack: (() -> Void)?
    var onChangeDate: ((Date) -> Void)?
    var onSaved: (() -> Void)?

    private let logWeightUseCase: LogWeightUseCase
    private var kilograms: Double
    private var date: Date
    private var unit: WeightUnit = .kilograms

    init(
        logWeightUseCase: LogWeightUseCase,
        initialKilograms: Double,
        date: Date = Date(),
        usesMetric: Bool = AppUnits.current.usesMetric
    ) {
        self.logWeightUseCase = logWeightUseCase
        kilograms = Self.clampedKilograms(initialKilograms)
        self.date = min(date, Date())
        unit = usesMetric ? .kilograms : .pounds
        unitIndex.value = unit.rawValue
        publish()
    }

    func backTapped() {
        onBack?()
    }

    func changeDateTapped() {
        onChangeDate?(date)
    }

    func updateDate(_ date: Date) {
        guard Calendar.current.compare(date, to: Date(), toGranularity: .day) != .orderedDescending else { return }
        self.date = date
        publishDate()
    }

    func selectUnit(index: Int) {
        unit = index == WeightUnit.pounds.rawValue ? .pounds : .kilograms
        unitIndex.value = unit.rawValue
        publishValue()
    }

    func sliderChanged(_ value: Float) {
        applyDisplayed(Double(value))
        publishValue(skipSlider: true)
    }

    func commitTypedValue(_ text: String) {
        let parsed = Self.parseNumber(text) ?? displayedValue
        applyDisplayed(parsed)
        publish()
    }

    func saveTapped() {
        guard Calendar.current.compare(date, to: Date(), toGranularity: .day) != .orderedDescending else {
            errorText.value = L10n.tr("logWeight.error.futureDate")
            return
        }
        do {
            _ = try logWeightUseCase.execute(
                weightKilograms: kilograms,
                date: date,
                source: "manual"
            )
            onSaved?()
        } catch {
            errorText.value = error.localizedDescription
        }
    }

    private var displayedValue: Double {
        unit == .pounds ? WeightConversion.pounds(fromKilograms: kilograms) : kilograms
    }

    private func applyDisplayed(_ value: Double) {
        let clamped = min(max(value, unit.sliderMin), unit.sliderMax)
        kilograms = unit == .pounds
            ? Self.clampedKilograms(WeightConversion.kilograms(fromPounds: clamped))
            : Self.clampedKilograms(clamped)
    }

    private func publish() {
        publishValue()
        publishDate()
    }

    private func publishValue(skipSlider: Bool = false) {
        unitLabelText.value = L10n.tr(unit.titleKey)
        displayValueText.value = Self.format(displayedValue)
        sliderMinimum.value = Float(unit.sliderMin)
        sliderMaximum.value = Float(unit.sliderMax)
        if !skipSlider {
            sliderValue.value = Float(displayedValue)
        }
    }

    private func publishDate() {
        dateText.value = "  \(Self.dateBadgeText(date))  "
    }

    private static func clampedKilograms(_ value: Double) -> Double {
        min(max(value, 30), 200)
    }

    private static func format(_ value: Double) -> String {
        let stepped = (value * 10).rounded() / 10
        let formatter = NumberFormatter()
        formatter.locale = .appFormatting
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: stepped)) ?? String(format: "%g", stepped)
    }

    private static func parseNumber(_ text: String) -> Double? {
        let filtered = text.replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        return Double(filtered)
    }

    private static func dateBadgeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .appFormatting
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        let day = formatter.string(from: date)
        if Calendar.current.isDateInToday(date) {
            return L10n.format("product.entry.todayDate", day)
        }
        return day
    }
}
