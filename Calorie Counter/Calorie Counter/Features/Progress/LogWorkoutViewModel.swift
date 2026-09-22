import Foundation

enum ExerciseType: Int, CaseIterable {
    case running
    case walking
    case cycling
    case swimming
    case strength
    case other

    var titleKey: String {
        switch self {
        case .running:
            return "logWorkout.type.running"
        case .walking:
            return "logWorkout.type.walking"
        case .cycling:
            return "logWorkout.type.cycling"
        case .swimming:
            return "logWorkout.type.swimming"
        case .strength:
            return "logWorkout.type.strength"
        case .other:
            return "logWorkout.type.other"
        }
    }

    // Representative activities from the 2024 Adult Compendium: pacompendium.com.
    // Without pace/intensity these are estimates. Other requires manual entry.
    var metabolicEquivalent: Double? {
        switch self {
        case .running: return 7.5 // 12020, general jogging
        case .walking: return 3.8 // 17190, moderate walking
        case .cycling: return 7.0 // 01014, general cycling
        case .swimming: return 5.8 // 18240, recreational freestyle
        case .strength: return 3.5 // 02054, varied resistance
        case .other: return nil
        }
    }

    var localizedTitle: String {
        L10n.tr(titleKey)
    }
}

final class LogWorkoutViewModel {
    let titleText = Observable(L10n.tr("logWorkout.title"))
    let selectedTypeIndex = Observable(ExerciseType.running.rawValue)
    let nameText = Observable(L10n.tr("logWorkout.type.running"))
    let dateText = Observable("")
    let durationSeconds = Observable(TimeInterval(30 * 60))
    let caloriesText = Observable("")
    let errorText = Observable("")

    var onBack: (() -> Void)?
    var onChangeDate: ((Date) -> Void)?
    var onSaved: (() -> Void)?

    private let bodyWeightKilograms: Double?
    private var hasManualCalories = false
    let isCaloriesEstimated = Observable(false)

    private let logWorkoutUseCase: LogWorkoutUseCase
    private var date: Date
    private var selectedType = ExerciseType.running
    private var lastChipName = L10n.tr("logWorkout.type.running")

    init(logWorkoutUseCase: LogWorkoutUseCase, date: Date = Date(), bodyWeightKilograms: Double? = nil) {
        self.bodyWeightKilograms = bodyWeightKilograms
        self.logWorkoutUseCase = logWorkoutUseCase
        self.date = min(date, Date())
        publishDate()
        refreshEstimatedCalories()
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

    func selectType(_ index: Int) {
        guard let type = ExerciseType(rawValue: index) else { return }
        let current = nameText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty || current == lastChipName {
            nameText.value = type.localizedTitle
        }
        selectedType = type
        selectedTypeIndex.value = type.rawValue
        lastChipName = type.localizedTitle
        refreshEstimatedCalories()
    }

    func updateName(_ text: String) {
        nameText.value = text
    }

    func updateDuration(_ seconds: TimeInterval) {
        durationSeconds.value = seconds.isFinite ? max(60, seconds) : 60
        refreshEstimatedCalories()
    }

    func updateCalories(_ text: String) {
        caloriesText.value = text
        hasManualCalories = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isCaloriesEstimated.value = false
    }

    func finishEditingCalories() {
        refreshEstimatedCalories()
    }

    private func refreshEstimatedCalories() {
        guard !hasManualCalories else { return }
        guard let weight = bodyWeightKilograms, weight.isFinite, weight > 0,
              let met = selectedType.metabolicEquivalent else {
            caloriesText.value = ""
            isCaloriesEstimated.value = false
            return
        }
        // Active kcal above rest; avoid counting resting energy twice in the diary.
        let kcal = (met - 1) * 3.5 * weight / 200 * (durationSeconds.value / 60)
        caloriesText.value = String(format: "%.0f", kcal.rounded())
        isCaloriesEstimated.value = true
    }

    func saveTapped() {
        refreshEstimatedCalories()
        guard Calendar.current.compare(date, to: Date(), toGranularity: .day) != .orderedDescending else {
            errorText.value = L10n.tr("logWorkout.error.futureDate")
            return
        }
        var name = nameText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            name = selectedType.localizedTitle
            nameText.value = name
        }
        let minutes = durationSeconds.value / 60
        do {
            _ = try logWorkoutUseCase.execute(
                name: name,
                durationMinutes: minutes,
                caloriesBurned: Self.parseCalories(caloriesText.value),
                date: date
            )
            onSaved?()
        } catch {
            errorText.value = error.localizedDescription
        }
    }

    private func publishDate() {
        dateText.value = "  \(Self.dateBadgeText(date))  "
    }

    private static func parseCalories(_ text: String) -> Double {
        let filtered = text.replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        return Double(filtered) ?? 0
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
