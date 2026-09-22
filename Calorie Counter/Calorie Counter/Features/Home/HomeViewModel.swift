import Foundation

final class HomeViewModel {
    let screen = Observable(HomeDisplay.empty)
    let selectedDate = Observable(Date())
    let diary = Observable<DailyDiarySummary?>(nil)
    let streakCount = Observable(0)

    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let logWaterUseCase: LogWaterUseCase
    private let deleteFoodEntryUseCase: DeleteFoodEntryUseCase
    private let updateFoodEntryUseCase: UpdateFoodEntryUseCase
    private let scaleFoodPortionUseCase: ScaleFoodPortionUseCase
    private let logWorkoutUseCase: LogWorkoutUseCase
    private let logWeightUseCase: LogWeightUseCase
    private let deleteWaterEntryUseCase: DeleteWaterEntryUseCase
    private let deleteWorkoutEntryUseCase: DeleteWorkoutEntryUseCase
    private let appSettingsStore: AppSettingsStoring
    private let fetchOnboardingStateUseCase: FetchOnboardingStateUseCase
    private let calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase
    private let evaluateStreakUseCase: EvaluateStreakUseCase
    private var date = Date()
    private var activityBurnTarget: Double = 0
    private var diaryChangeObserver: NSObjectProtocol?

    init(
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        logWaterUseCase: LogWaterUseCase,
        deleteFoodEntryUseCase: DeleteFoodEntryUseCase,
        updateFoodEntryUseCase: UpdateFoodEntryUseCase,
        scaleFoodPortionUseCase: ScaleFoodPortionUseCase,
        logWorkoutUseCase: LogWorkoutUseCase,
        logWeightUseCase: LogWeightUseCase,
        deleteWaterEntryUseCase: DeleteWaterEntryUseCase,
        deleteWorkoutEntryUseCase: DeleteWorkoutEntryUseCase,
        appSettingsStore: AppSettingsStoring,
        fetchOnboardingStateUseCase: FetchOnboardingStateUseCase,
        calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase,
        evaluateStreakUseCase: EvaluateStreakUseCase
    ) {
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.logWaterUseCase = logWaterUseCase
        self.deleteFoodEntryUseCase = deleteFoodEntryUseCase
        self.updateFoodEntryUseCase = updateFoodEntryUseCase
        self.scaleFoodPortionUseCase = scaleFoodPortionUseCase
        self.logWorkoutUseCase = logWorkoutUseCase
        self.logWeightUseCase = logWeightUseCase
        self.deleteWaterEntryUseCase = deleteWaterEntryUseCase
        self.deleteWorkoutEntryUseCase = deleteWorkoutEntryUseCase
        self.appSettingsStore = appSettingsStore
        self.fetchOnboardingStateUseCase = fetchOnboardingStateUseCase
        self.calculateNutritionPlanUseCase = calculateNutritionPlanUseCase
        self.evaluateStreakUseCase = evaluateStreakUseCase
        diaryChangeObserver = NotificationCenter.default.addObserver(
            forName: .bityDiaryDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    deinit {
        if let diaryChangeObserver {
            NotificationCenter.default.removeObserver(diaryChangeObserver)
        }
    }

    func viewDidLoad() {
        reload()
    }

    func select(date: Date) {
        let calendar = Calendar.current
        if !calendar.isDate(date, inSameDayAs: self.date) {
            let days = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date)
            ).day ?? 0
            Analytics.tracker.track(.diaryDateChanged(daysFromToday: days))
        }
        self.date = date
        reload()
    }

    func selectPreviousDay() {
        select(date: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date)
    }

    func selectToday() {
        select(date: Date())
    }

    func reload() {
        refreshActivityBurnTarget()
        do {
            let streak = try evaluateStreakUseCase.execute()
            if streakCount.value != streak.current {
                streakCount.value = streak.current
            }
        } catch {
            if streakCount.value != 0 { streakCount.value = 0 }
        }
        do {
            let summary = try fetchDailyDiaryUseCase.execute(for: date)
            diary.value = summary
            selectedDate.value = summary.date
            let display = makeDisplay(from: summary)
            if screen.value != display { screen.value = display }
        } catch {
            diary.value = nil
            if screen.value != .empty { screen.value = .empty }
        }
    }

    func logWaterGlass() {
        logWater(amountMilliliters: appSettingsStore.settings.waterGlassMilliliters)
    }

    func removeLastWater() {
        guard let last = diary.value?.waterEntries.sorted(by: { $0.date < $1.date }).last else { return }
        Analytics.tracker.track(.waterRemoved)
        deleteWater(id: last.id)
    }

    func saveGlassVolume(_ milliliters: Double) {
        let value = max(1, milliliters)
        var settings = appSettingsStore.settings
        settings.waterGlassMilliliters = value
        appSettingsStore.settings = settings
        Analytics.tracker.track(.glassVolumeSaved(amountMilliliters: Int(value.rounded())))
        reload()
    }

    func foodEntry(id: UUID) -> FoodEntry? {
        diary.value?.foodEntries.first { $0.id == id }
    }

    func toggleEaten(id: UUID) {
        guard var entry = diary.value?.foodEntries.first(where: { $0.id == id }) else { return }
        entry.isEaten.toggle()
        Analytics.tracker.track(.foodMarkedEaten(eaten: entry.isEaten, mealType: entry.mealType.rawValue))
        updateFood(entry)
    }

    func markAllEaten() {
        let uneaten = diary.value?.foodEntries.filter { !$0.isEaten } ?? []
        guard !uneaten.isEmpty else { return }
        Analytics.tracker.track(.allFoodMarkedEaten(count: uneaten.count))
        do {
            for var entry in uneaten {
                entry.isEaten = true
                try updateFoodEntryUseCase.execute(entry)
            }
            reload()
        } catch {
        }
    }

    func logWater(amountMilliliters: Double) {
        do {
            _ = try logWaterUseCase.execute(amountMilliliters: amountMilliliters, date: date)
            reload()
        } catch {
        }
    }

    func deleteFood(id: UUID) {
        do {
            try deleteFoodEntryUseCase.execute(id: id)
            reload()
        } catch {
        }
    }

    func updateFood(_ entry: FoodEntry) {
        do {
            try updateFoodEntryUseCase.execute(entry)
            reload()
        } catch {
        }
    }

    func scaleFood(id: UUID, grams: Double) {
        guard let entry = diary.value?.foodEntries.first(where: { $0.id == id }) else { return }
        Analytics.tracker.track(.foodPortionChanged(mealType: entry.mealType.rawValue))
        updateFood(scaleFoodPortionUseCase.execute(entry: entry, grams: grams))
    }

    func logWorkout(name: String, durationMinutes: Double, caloriesBurned: Double) {
        do {
            _ = try logWorkoutUseCase.execute(
                name: name,
                durationMinutes: durationMinutes,
                caloriesBurned: caloriesBurned,
                date: date
            )
            reload()
        } catch {
        }
    }

    func logWeight(kilograms: Double) {
        do {
            _ = try logWeightUseCase.execute(weightKilograms: kilograms, date: date)
            reload()
        } catch {
        }
    }

    func deleteWater(id: UUID) {
        do {
            try deleteWaterEntryUseCase.execute(id: id)
            reload()
        } catch {
        }
    }

    func deleteWorkout(id: UUID) {
        do {
            try deleteWorkoutEntryUseCase.execute(id: id)
            reload()
        } catch {
        }
    }

    private func makeDisplay(from summary: DailyDiarySummary) -> HomeDisplay {
        let food = Int(summary.totalCalories.rounded())
        let goal = Int(summary.goals.calorieTarget.rounded())
        let remaining = max(0, Int(summary.remainingCalories.rounded()))
        let burned = Int(summary.burnedCalories.rounded())
        let burnTarget = Int(activityBurnTarget.rounded())
        let water = Int(summary.waterMilliliters.rounded())
        let waterTarget = Int(summary.goals.waterTargetMilliliters.rounded())
        let glass = max(1, Int(appSettingsStore.settings.waterGlassMilliliters.rounded()))
        let remainingWater = max(0, waterTarget - water)
        let remainingGlasses = Int(ceil(Double(remainingWater) / Double(glass)))
        let fiber = Int(summary.totalFiber.rounded())
        let sugar = Int(summary.totalSugar.rounded())
        let sodiumGrams = summary.totalSodium / 1000
        let sodiumTargetGrams = summary.goals.sodiumTarget / 1000
        return HomeDisplay(
            dateTitle: dateTitle(for: summary.date),
            caloriePercentText: percentText(summary.totalCalories, summary.goals.calorieTarget),
            calorieProgress: progress(summary.totalCalories, summary.goals.calorieTarget),
            foodValueText: L10n.format("home.kcalPairFormat", food, goal),
            remainingValueText: L10n.format("home.kcalValue", remaining),
            proteinPercentText: percentText(summary.totalProtein, summary.goals.proteinTarget),
            carbsPercentText: percentText(summary.totalCarbs, summary.goals.carbsTarget),
            fatPercentText: percentText(summary.totalFats, summary.goals.fatsTarget),
            proteinProgress: progress(summary.totalProtein, summary.goals.proteinTarget),
            carbsProgress: progress(summary.totalCarbs, summary.goals.carbsTarget),
            fatProgress: progress(summary.totalFats, summary.goals.fatsTarget),
            fiberValueText: L10n.format(
                "home.microPairFormat",
                "\(fiber)",
                "\(Int(summary.goals.fiberTarget.rounded()))"
            ),
            sugarValueText: L10n.format(
                "home.microPairFormat",
                "\(sugar)",
                "\(Int(summary.goals.sugarTarget.rounded()))"
            ),
            sodiumValueText: L10n.format(
                "home.microPairFormat",
                sodiumString(sodiumGrams),
                sodiumString(sodiumTargetGrams)
            ),
            exercisePercentText: percentText(summary.burnedCalories, activityBurnTarget),
            exerciseProgress: progress(summary.burnedCalories, activityBurnTarget),
            exerciseValueText: L10n.format("home.kcalPairFormat", burned, burnTarget),
            burnRemainingText: L10n.format("home.kcalValue", max(0, burnTarget - burned)),
            meals: [MealType.breakfast, .lunch, .snacks, .dinner].map { meal in
                let entries = summary.entries(for: meal)
                let kcal = Int(entries.filter(\.isEaten).reduce(0) { $0 + $1.calories }.rounded())
                return HomeMealSection(
                    mealType: meal,
                    emoji: meal.homeEmoji,
                    title: meal.localizedTitle,
                    caloriesText: L10n.format("home.kcalValue", kcal),
                    foods: entries.map { entry in
                        HomeFoodItem(
                            id: entry.id,
                            name: entry.name,
                            detailText: foodDetail(entry),
                            isEaten: entry.isEaten,
                            imageURL: entry.imageURL,
                            imageData: entry.imageData
                        )
                    }
                )
            },
            waterRangeText: "(\(AppUnits.current.number(AppUnits.current.volume(Double(water)))) / \(AppUnits.current.volumeText(Double(waterTarget))))",
            waterHintText: Self.waterHintText(
                remainingMilliliters: remainingWater,
                remainingGlasses: remainingGlasses
            ),
            waterFills: waterFills(consumed: water, target: waterTarget),
            glassMilliliters: glass
        )
    }

    private func refreshActivityBurnTarget() {
        guard let profile = try? fetchOnboardingStateUseCase.execute(),
              let plan = calculateNutritionPlanUseCase.execute(profile: profile)
        else {
            activityBurnTarget = 0
            return
        }
        activityBurnTarget = plan.activityBurnTarget.rounded()
    }

    private func foodDetail(_ entry: FoodEntry) -> String {
        let kcal = Int(entry.calories.rounded())
        if let milliliters = entry.portionMilliliters {
            return "\(AppUnits.current.volumeText(milliliters)) • \(L10n.format("recipes.kcal", kcal))"
        }
        if let grams = entry.portionGrams {
            return "\(AppUnits.current.massText(grams)) • \(L10n.format("recipes.kcal", kcal))"
        }
        return L10n.format("recipes.kcal", kcal)
    }

    private func dateTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = .appFormatting
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        let short = formatter.string(from: date)
        if calendar.isDateInToday(date) {
            return L10n.format("home.todayDateFormat", short)
        }
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return L10n.format("home.weekdayDateFormat", formatter.string(from: date), short)
    }

    private static func waterHintText(remainingMilliliters: Int, remainingGlasses: Int) -> String {
        guard remainingMilliliters > 0 else {
            return L10n.tr("home.waterHintComplete")
        }
        let key = remainingGlasses == 1 ? "home.waterHintOneFormat" : "home.waterHintFormat"
        if AppUnits.current.usesMetric { return L10n.format(key, remainingGlasses, remainingMilliliters) }
        return L10n.format(key + ".imperial", remainingGlasses, AppUnits.current.number(AppUnits.current.volume(Double(remainingMilliliters))))
    }

    private func waterFills(consumed: Int, target: Int) -> [Double] {
        let slot = Double(max(target, 0)) / 8
        guard slot > 0 else { return Array(repeating: 0, count: 8) }
        let value = Double(max(consumed, 0))
        return (0..<8).map { index in
            min(max((value - Double(index) * slot) / slot, 0), 1)
        }
    }

    private func progress(_ value: Double, _ target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }

    private func percentText(_ value: Double, _ target: Double) -> String {
        guard target > 0 else { return "0%" }
        return "\(Int((min(max(value / target, 0), 1) * 100).rounded()))%"
    }

    private func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .appFormatting
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func sodiumString(_ grams: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .appFormatting
        formatter.minimumFractionDigits = grams.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: grams)) ?? "0"
    }
}

private extension MealType {
    var homeEmoji: String {
        switch self {
        case .breakfast: return "🌅"
        case .lunch: return "☀️"
        case .snacks: return "🍪"
        case .dinner: return "🌙"
        }
    }
}
