import UIKit

final class FoodLoggingCoordinator {
    private let navigationController: UINavigationController
    private let container: DIContainer
    private var foodPhotoCapturer: FoodPhotoCapturing = UnconfiguredFoodPhotoCapturer()

    init(navigationController: UINavigationController, container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() {}

    func openBarcodeScanner(onLogged: (() -> Void)? = nil) {
        let viewModel = BarcodeFoodLoggingViewModel(
            lookupBarcodeProductUseCase: container.lookupBarcodeProductUseCase,
            logFoodUseCase: container.logFoodUseCase
        )
        viewModel.onLogged = { [weak self] in
            onLogged?()
            self?.navigationController.popViewController(animated: true)
        }
        let viewController = BarcodeScannerViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    func openTextFoodLogging(onLogged: (() -> Void)? = nil) {
        let viewModel = TextFoodLoggingViewModel(
            analyzeTextFoodUseCase: container.analyzeTextFoodUseCase,
            logFoodUseCase: container.logFoodUseCase
        )
        viewModel.onLogged = { [weak self] in
            onLogged?()
            self?.navigationController.popViewController(animated: true)
        }
        let viewController = TextFoodLoggingViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    func makeVoiceFoodLoggingViewModel(onLogged: (() -> Void)? = nil) -> VoiceFoodLoggingViewModel {
        let viewModel = container.makeVoiceFoodLoggingViewModel()
        viewModel.onLogged = onLogged
        return viewModel
    }

    func makeAnalyzeVoiceFoodUseCase() -> AnalyzeVoiceFoodUseCase {
        container.analyzeVoiceFoodUseCase
    }

    func makeVoiceFoodAudioRecorder() -> VoiceFoodAudioRecording {
        container.voiceFoodAudioRecorder
    }

    func makeFoodPhotoAnalysisViewModel(onLogged: (() -> Void)? = nil) -> FoodPhotoAnalysisViewModel {
        let viewModel = FoodPhotoAnalysisViewModel(
            analyzeFoodPhotoUseCase: container.analyzeFoodPhotoUseCase,
            logFoodUseCase: container.logFoodUseCase
        )
        viewModel.onLogged = onLogged
        return viewModel
    }

    func attachFoodPhotoCapturer(_ capturer: FoodPhotoCapturing, viewModel: FoodPhotoAnalysisViewModel) {
        foodPhotoCapturer.stopCapture()
        foodPhotoCapturer = capturer
        foodPhotoCapturer.onPhotoCaptured = { [weak viewModel] data in
            viewModel?.analyze(imageData: data)
        }
        foodPhotoCapturer.onCaptureFailed = { [weak viewModel] error in
            viewModel?.statusText.value = error.localizedDescription
        }
    }

    func startFoodPhotoCapture() {
        foodPhotoCapturer.startCapture()
    }

    func stopFoodPhotoCapture() {
        foodPhotoCapturer.stopCapture()
    }

    func analyzeFoodPhoto(imageData: Data, viewModel: FoodPhotoAnalysisViewModel) {
        viewModel.analyze(imageData: imageData)
    }
}
