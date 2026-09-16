import Foundation

final class ProgressPhotoCameraViewModel {
    let stepText = Observable("")
    let shutterHintText = Observable("")
    let isBusy = Observable(false)
    let errorText = Observable("")

    var onClose: (() -> Void)?
    var onFinished: (() -> Void)?

    private let saveProgressPhotoUseCase: SaveProgressPhotoUseCase
    private var pose: ProgressPhotoPose
    private let continuesToSide: Bool

    init(
        saveProgressPhotoUseCase: SaveProgressPhotoUseCase,
        startingPose: ProgressPhotoPose = .front
    ) {
        self.saveProgressPhotoUseCase = saveProgressPhotoUseCase
        pose = startingPose
        continuesToSide = startingPose == .front
        publishStep()
    }

    func closeTapped() {
        onClose?()
    }

    func captureFailed(_ error: Error) {
        isBusy.value = false
        errorText.value = error.localizedDescription
    }

    func saveCapturedData(_ data: Data) {
        guard !isBusy.value else { return }
        isBusy.value = true
        do {
            _ = try saveProgressPhotoUseCase.execute(
                imageData: data,
                kind: .progress,
                pose: pose
            )
            isBusy.value = false
            if pose == .front, continuesToSide {
                pose = .side
                publishStep()
            } else {
                onFinished?()
            }
        } catch {
            isBusy.value = false
            errorText.value = error.localizedDescription
        }
    }

    private func publishStep() {
        let step = pose == .front ? 1 : 2
        stepText.value = L10n.format("progressPhoto.step", step, 2, pose.title)
        shutterHintText.value = pose == .front
            ? L10n.tr("progressPhoto.hint.front")
            : L10n.tr("progressPhoto.hint.side")
    }
}
