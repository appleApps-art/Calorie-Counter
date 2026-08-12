import Foundation

final class ProgressViewModel {
    let titleText = Observable(L10n.tr("progress.title"))
    let subtitleText = Observable(L10n.tr("progress.subtitle"))
    let streakText = Observable("")
    let rewardsText = Observable("")
    let weightText = Observable("")
    let statusText = Observable("")
    let summary = Observable<ProgressSummary?>(nil)
    let photos = Observable<[ProgressPhoto]>([])
    let baselinePhotos = Observable(ProgressPhotoPair.empty)
    let latestPhotos = Observable(ProgressPhotoPair.empty)

    private let fetchProgressSummaryUseCase: FetchProgressSummaryUseCase
    private let logWeightUseCase: LogWeightUseCase
    private let saveProgressPhotoUseCase: SaveProgressPhotoUseCase
    private let deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase
    private let fetchProgressPhotosUseCase: FetchProgressPhotosUseCase
    private let fetchRewardStateUseCase: FetchRewardStateUseCase

    init(
        fetchProgressSummaryUseCase: FetchProgressSummaryUseCase,
        logWeightUseCase: LogWeightUseCase,
        saveProgressPhotoUseCase: SaveProgressPhotoUseCase,
        deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase,
        fetchProgressPhotosUseCase: FetchProgressPhotosUseCase,
        fetchRewardStateUseCase: FetchRewardStateUseCase
    ) {
        self.fetchProgressSummaryUseCase = fetchProgressSummaryUseCase
        self.logWeightUseCase = logWeightUseCase
        self.saveProgressPhotoUseCase = saveProgressPhotoUseCase
        self.deleteProgressPhotoUseCase = deleteProgressPhotoUseCase
        self.fetchProgressPhotosUseCase = fetchProgressPhotosUseCase
        self.fetchRewardStateUseCase = fetchRewardStateUseCase
    }

    func viewDidLoad() {
        reload()
    }

    func reload() {
        do {
            let loaded = try fetchProgressSummaryUseCase.execute()
            summary.value = loaded
            photos.value = loaded.photos
            baselinePhotos.value = try fetchProgressPhotosUseCase.baselinePair()
            latestPhotos.value = try fetchProgressPhotosUseCase.latestPair()
            streakText.value = L10n.format("progress.streak", loaded.streak.current, loaded.streak.longest)
            rewardsText.value = L10n.format(
                "progress.rewards",
                loaded.rewards.level.localizedTitle,
                loaded.rewards.totalXP,
                loaded.rewards.unlockedBadgeIDs.count
            )
            if let latest = loaded.weightEntries.last {
                weightText.value = L10n.format("progress.weightFormat", latest.weightKilograms)
            } else {
                weightText.value = L10n.tr("progress.noWeight")
            }
            subtitleText.value = rewardsText.value
            statusText.value = ""
        } catch {
            statusText.value = error.localizedDescription
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
}
