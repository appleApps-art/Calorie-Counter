import Foundation

enum ProgressLogAction {
    case weight
    case workout
    case photo
}

final class ProgressViewModel {
    let titleText = Observable(L10n.tr("progress.title"))
    let insightText = Observable<String?>(nil)
    let isPremium = Observable(false)
    let caloriePeriod = Observable(ProgressChartPeriod.week)
    let calorieColumns = Observable<[ProgressMacroColumn]>([])
    let calorieTarget = Observable(0.0)
    let calorieTargetLegend = Observable("")
    let expenditurePeriod = Observable(ProgressChartPeriod.week)
    let expenditureColumns = Observable<[ProgressValueColumn]>([])
    let expenditureTarget = Observable(0.0)
    let expenditureTargetLegend = Observable("")
    let burnedText = Observable("")
    let dailyAvgText = Observable("")
    let bestDayText = Observable("")
    let showsExpenditureStats = Observable(false)
    let weightPeriod = Observable(ProgressChartPeriod.week)
    let weightColumns = Observable<[ProgressValueColumn]>([])
    let startWeightText = Observable("")
    let currentWeightText = Observable("")
    let changeWeightText = Observable("")
    let changeSymbolName = Observable<String?>(nil)
    let changeColorIsMint = Observable(false)
    let showsWeightStats = Observable(false)
    let photoPreviews = Observable<[ProgressPhotoPreview]>([])
    let photoSections = Observable<[ProgressPhotoDaySection]>([])
    let hasPhotos = Observable(false)
    let statusText = Observable("")

    var onLog: (() -> Void)?
    var onSeeAllPhotos: (() -> Void)?
    var onAddPhoto: (() -> Void)?
    var onUpgrade: (() -> Void)?
    var onLogWeight: (() -> Void)?
    var onLogExercise: (() -> Void)?
    var onCaptureProgressPhoto: (() -> Void)?

    private let fetchProgressSummaryUseCase: FetchProgressSummaryUseCase
    private let logWeightUseCase: LogWeightUseCase
    private let saveProgressPhotoUseCase: SaveProgressPhotoUseCase
    private let deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase
    private let refreshSubscriptionStatusUseCase: RefreshSubscriptionStatusUseCase
    private var summary: ProgressSummary?
    private let calendar = Calendar.current

    init(
        fetchProgressSummaryUseCase: FetchProgressSummaryUseCase,
        logWeightUseCase: LogWeightUseCase,
        saveProgressPhotoUseCase: SaveProgressPhotoUseCase,
        deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase,
        refreshSubscriptionStatusUseCase: RefreshSubscriptionStatusUseCase
    ) {
        self.fetchProgressSummaryUseCase = fetchProgressSummaryUseCase
        self.logWeightUseCase = logWeightUseCase
        self.saveProgressPhotoUseCase = saveProgressPhotoUseCase
        self.deleteProgressPhotoUseCase = deleteProgressPhotoUseCase
        self.refreshSubscriptionStatusUseCase = refreshSubscriptionStatusUseCase
    }

    func viewDidLoad() {
        isPremium.value = refreshSubscriptionStatusUseCase.cached().isPremium
        reload()
        Task { [weak self] in
            guard let self else { return }
            let status = await refreshSubscriptionStatusUseCase.execute()
            await MainActor.run {
                self.isPremium.value = status.isPremium
                self.publishInsight()
            }
        }
    }

    func reload() {
        do {
            summary = try fetchProgressSummaryUseCase.execute()
            publish()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func selectCaloriePeriod(_ period: ProgressChartPeriod) {
        caloriePeriod.value = period
        publishCalories()
    }

    func selectExpenditurePeriod(_ period: ProgressChartPeriod) {
        expenditurePeriod.value = period
        publishExpenditure()
    }

    func selectWeightPeriod(_ period: ProgressChartPeriod) {
        weightPeriod.value = period
        publishWeight()
    }

    func logTapped() {
        onLog?()
    }

    func seeAllPhotosTapped() {
        onSeeAllPhotos?()
    }

    func addPhotoTapped() {
        onAddPhoto?()
    }

    func upgradeTapped() {
        onUpgrade?()
    }

    func handleLog(_ action: ProgressLogAction) {
        switch action {
        case .weight: onLogWeight?()
        case .workout: onLogExercise?()
        case .photo: onCaptureProgressPhoto?()
        }
    }

    func logWeight(kilograms: Double) {
        do {
            _ = try logWeightUseCase.execute(weightKilograms: kilograms)
            reload()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func savePhoto(
        imageData: Data,
        pose: ProgressPhotoPose,
        kind: ProgressPhotoKind = .progress,
        note: String? = nil
    ) {
        do {
            _ = try saveProgressPhotoUseCase.execute(imageData: imageData, kind: kind, pose: pose, note: note)
            reload()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    func deletePhoto(_ photo: ProgressPhoto) {
        do {
            try deleteProgressPhotoUseCase.execute(photo)
            reload()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    private func publish() {
        publishCalories()
        publishExpenditure()
        publishWeight()
        publishPhotos()
        publishInsight()
    }

    private func publishInsight() {
        guard isPremium.value, let summary else {
            insightText.value = nil
            return
        }
        insightText.value = ProgressChartMath.insightText(
            points: summary.caloriePoints,
            fiberTarget: summary.goals.fiberTarget,
            now: Date(),
            calendar: calendar
        )
    }

    private func publishCalories() {
        guard let summary else { return }
        let columns = ProgressChartMath.calorieColumns(
            points: summary.caloriePoints,
            period: caloriePeriod.value,
            now: Date(),
            calendar: calendar
        )
        calorieColumns.value = columns
        calorieTarget.value = summary.goals.calorieTarget
        calorieTargetLegend.value = L10n.format(
            "progress.legend.target",
            ProgressChartMath.groupedNumber(summary.goals.calorieTarget)
        )
    }

    private func publishExpenditure() {
        guard let summary else { return }
        let columns = ProgressChartMath.expenditureColumns(
            workouts: summary.workouts,
            healthActivity: summary.healthActivity,
            period: expenditurePeriod.value,
            now: Date(),
            calendar: calendar
        )
        expenditureColumns.value = columns
        expenditureTarget.value = summary.activityBurnTarget
        if summary.activityBurnTarget > 0 {
            expenditureTargetLegend.value = L10n.format(
                "progress.legend.target",
                ProgressChartMath.groupedNumber(summary.activityBurnTarget)
            )
        } else {
            expenditureTargetLegend.value = ""
        }
        let values = ProgressChartMath.dailyExpenditure(
            workouts: summary.workouts,
            healthActivity: summary.healthActivity,
            period: expenditurePeriod.value,
            now: Date(),
            calendar: calendar
        ).map(\.value)
        let total = values.reduce(0, +)
        let hasData = values.contains { $0 > 0 }
        showsExpenditureStats.value = hasData
        burnedText.value = ProgressChartMath.kcalText(total)
        let days = Double(max(values.count, 1))
        dailyAvgText.value = ProgressChartMath.kcalText(total / days)
        bestDayText.value = ProgressChartMath.kcalText(values.max() ?? 0)
    }

    private func publishWeight() {
        guard let summary else { return }
        let columns = ProgressChartMath.weightColumns(
            entries: summary.weightEntries,
            period: weightPeriod.value,
            now: Date(),
            calendar: calendar
        )
        weightColumns.value = columns.map { ProgressValueColumn(date: $0.date, value: AppUnits.current.weight($0.value), aggregationDayCount: $0.aggregationDayCount) }
        showsWeightStats.value = !columns.isEmpty
        guard let first = columns.first, let last = columns.last else {
            startWeightText.value = ""
            currentWeightText.value = ""
            changeWeightText.value = ""
            changeSymbolName.value = nil
            return
        }
        startWeightText.value = AppUnits.current.weightText(first.value)
        currentWeightText.value = AppUnits.current.weightText(last.value)
        let delta = last.value - first.value
        changeWeightText.value = AppUnits.current.weightText(delta, signed: true)
        if delta < 0 {
            changeSymbolName.value = "arrow.down"
            changeColorIsMint.value = true
        } else if delta > 0 {
            changeSymbolName.value = "arrow.up"
            changeColorIsMint.value = false
        } else {
            changeSymbolName.value = nil
            changeColorIsMint.value = false
        }
    }

    private func publishPhotos() {
        guard let summary else { return }
        let photos = summary.photos.filter { photo in
            guard photo.kind == .progress else { return false }
            guard let url = photo.fileURL else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
        hasPhotos.value = !photos.isEmpty
        photoPreviews.value = ProgressChartMath.photoPreviews(photos, calendar: calendar)
        photoSections.value = ProgressChartMath.photoDaySections(photos, calendar: calendar)
    }
}
