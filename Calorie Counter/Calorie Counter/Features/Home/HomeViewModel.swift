import Foundation

final class HomeViewModel {
    let titleText = Observable(L10n.tr("common.today"))
    let summaryText = Observable(L10n.tr("home.loading"))
    let caloriesText = Observable("")
    let entriesCountText = Observable("")
    let remainingText = Observable("")
    let macrosText = Observable("")
    let waterText = Observable("")
    let workoutText = Observable("")
    let nutritionScoreText = Observable("")
    let selectedDate = Observable(Date())
    let diary = Observable<DailyDiarySummary?>(nil)

    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let logWaterUseCase: LogWaterUseCase
    private let deleteFoodEntryUseCase: DeleteFoodEntryUseCase
    private let updateFoodEntryUseCase: UpdateFoodEntryUseCase
    private let scaleFoodPortionUseCase: ScaleFoodPortionUseCase
    private let logWorkoutUseCase: LogWorkoutUseCase
    private let logWeightUseCase: LogWeightUseCase
    private let deleteWaterEntryUseCase: DeleteWaterEntryUseCase
    private let deleteWorkoutEntryUseCase: DeleteWorkoutEntryUseCase
    private var date = Date()

    init(
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        logWaterUseCase: LogWaterUseCase,
        deleteFoodEntryUseCase: DeleteFoodEntryUseCase,
        updateFoodEntryUseCase: UpdateFoodEntryUseCase,
        scaleFoodPortionUseCase: ScaleFoodPortionUseCase,
        logWorkoutUseCase: LogWorkoutUseCase,
        logWeightUseCase: LogWeightUseCase,
        deleteWaterEntryUseCase: DeleteWaterEntryUseCase,
        deleteWorkoutEntryUseCase: DeleteWorkoutEntryUseCase
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
    }

    func viewDidLoad() {
        reload()
    }

    func selectPreviousDay() {
        date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        reload()
    }

    func selectNextDay() {
        date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        reload()
    }

    func selectToday() {
        date = Date()
        reload()
    }

    func select(date: Date) {
        self.date = date
        reload()
    }

    func reload() {
        do {
            let summary = try fetchDailyDiaryUseCase.execute(for: date)
            diary.value = summary
            selectedDate.value = summary.date

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            titleText.value = formatter.string(from: summary.date)

            if summary.foodEntries.isEmpty {
                summaryText.value = L10n.tr("home.emptyMeals")
            } else {
                summaryText.value = L10n.tr("home.mealsLogged")
            }

            caloriesText.value = L10n.format(
                "home.caloriesFormat",
                Int(summary.totalCalories),
                Int(summary.goals.calorieTarget)
            )
            remainingText.value = L10n.format("home.remainingFormat", Int(summary.remainingCalories.rounded()))
            macrosText.value = L10n.format(
                "home.macrosFormat",
                Int(summary.totalProtein),
                Int(summary.goals.proteinTarget),
                Int(summary.totalCarbs),
                Int(summary.goals.carbsTarget),
                Int(summary.totalFats),
                Int(summary.goals.fatsTarget)
            )
            waterText.value = L10n.format(
                "home.waterFormat",
                Int(summary.waterMilliliters),
                Int(summary.goals.waterTargetMilliliters)
            )
            workoutText.value = summary.workouts.isEmpty
                ? L10n.tr("home.noWorkouts")
                : L10n.format(
                    "home.workoutsFormat",
                    summary.workouts.count,
                    Int(summary.burnedCalories.rounded())
                )
            nutritionScoreText.value = L10n.format(
                "home.scoreFormat",
                summary.nutritionFacts.score,
                summary.nutritionFacts.grade.rawValue
            )
            entriesCountText.value = L10n.format(
                "home.entriesFormat",
                summary.foodEntries.count,
                Int(summary.waterMilliliters)
            )
        } catch {
            diary.value = nil
            summaryText.value = L10n.tr("home.loadFailed")
            caloriesText.value = ""
            remainingText.value = ""
            macrosText.value = ""
            waterText.value = ""
            workoutText.value = ""
            nutritionScoreText.value = ""
            entriesCountText.value = error.localizedDescription
        }
    }

    func logWater(amountMilliliters: Double) {
        do {
            _ = try logWaterUseCase.execute(amountMilliliters: amountMilliliters, date: date)
            reload()
        } catch {
            entriesCountText.value = error.localizedDescription
        }
    }

    func deleteFood(id: UUID) {
        do {
            try deleteFoodEntryUseCase.execute(id: id)
            reload()
        } catch {
            entriesCountText.value = error.localizedDescription
        }
    }

    func updateFood(_ entry: FoodEntry) {
        do {
            try updateFoodEntryUseCase.execute(entry)
            reload()
        } catch {
            entriesCountText.value = error.localizedDescription
        }
    }

    func scaleFood(id: UUID, grams: Double) {
        guard let entry = diary.value?.foodEntries.first(where: { $0.id == id }) else { return }
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
            entriesCountText.value = error.localizedDescription
        }
    }

    func logWeight(kilograms: Double) {
        do {
            _ = try logWeightUseCase.execute(weightKilograms: kilograms, date: date)
            reload()
        } catch {
            entriesCountText.value = error.localizedDescription
        }
    }

    func deleteWater(id: UUID) {
        do {
            try deleteWaterEntryUseCase.execute(id: id)
            reload()
        } catch {
            entriesCountText.value = error.localizedDescription
        }
    }

    func deleteWorkout(id: UUID) {
        do {
            try deleteWorkoutEntryUseCase.execute(id: id)
            reload()
        } catch {
            entriesCountText.value = error.localizedDescription
        }
    }
}
