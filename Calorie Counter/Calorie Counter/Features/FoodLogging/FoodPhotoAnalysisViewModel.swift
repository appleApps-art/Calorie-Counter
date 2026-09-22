import Foundation
import UIKit

enum AIPhotoPhase: Equatable {
    case idle
    case identifying
    case recognized
    case result
}

final class FoodPhotoAnalysisViewModel {
    let statusText = Observable(L10n.tr("photo.status"))
    /// Why the shutter press or the picked photo gave no result. The camera goes back to idle,
    /// where the hint bar is hidden, so without this the user only sees the photo vanish.
    let errorText = Observable("")
    let resultTitleText = Observable("")
    let resultDetailsText = Observable("")
    let confidenceText = Observable("")
    let nutritionScoreText = Observable("")
    let isAnalyzing = Observable(false)
    let canConfirmLog = Observable(false)
    let analysis = Observable<FoodPhotoAnalysis?>(nil)
    let phase = Observable(AIPhotoPhase.idle)
    let capturedImage = Observable<UIImage?>(nil)
    let showsFullDetails = Observable(false)

    var onLogged: (() -> Void)?
    var onClose: (() -> Void)?
    var onSwitchMode: ((HomeQuickLogAction) -> Void)?
    var onViewDetails: ((ProductDetailsDraft) -> Void)?
    var onAddEntry: ((ProductDetailsDraft) -> Void)?
    var onFridgeItemsReady: (([PantryItem]) -> Void)?

    let inventoryMode: Bool

    private let analyzeFoodPhotoUseCase: AnalyzeFoodPhotoUseCase
    private let searchFoodProductsUseCase: SearchFoodProductsUseCase?
    private var selectedMealType: MealType
    private let diaryDate: Date
    private var note: String?
    private var recognizedTask: Task<Void, Never>?
    private var captureWatchdog: Task<Void, Never>?
    /// How long a shutter press may wait for the camera before the screen gives the shutter back.
    var captureTimeoutNanoseconds: UInt64 = 10_000_000_000

    init(
        analyzeFoodPhotoUseCase: AnalyzeFoodPhotoUseCase,
        searchFoodProductsUseCase: SearchFoodProductsUseCase? = nil,
        mealType: MealType = .snacks,
        date: Date = Date(),
        inventoryMode: Bool = false
    ) {
        self.analyzeFoodPhotoUseCase = analyzeFoodPhotoUseCase
        self.searchFoodProductsUseCase = searchFoodProductsUseCase
        selectedMealType = mealType
        diaryDate = date
        self.inventoryMode = inventoryMode
    }

    var productSubtitleText: String {
        guard let result = analysis.value else { return "" }
        let portion: String?
        if let milliliters = result.portionMilliliters {
            portion = AppUnits.current.volumeText(milliliters)
        } else if let grams = result.portionGrams {
            portion = AppUnits.current.massText(grams)
        } else {
            portion = nil
        }
        if !result.notes.isEmpty, let portion {
            return "\(result.notes) (\(portion))"
        }
        if !result.notes.isEmpty {
            return result.notes
        }
        return portion ?? ""
    }

    var healthScoreTitleText: String {
        guard let result = analysis.value else { return "" }
        return L10n.format("photo.result.healthScore", result.nutritionFacts.score)
    }

    var caloriesValueText: String {
        guard let result = analysis.value else { return "" }
        // The tile is titled Calories, so the number stands alone and never truncates to "380кк…".
        return String(Int(result.calories.rounded()))
    }

    var proteinValueText: String {
        guard let result = analysis.value else { return "" }
        return L10n.format("editMeal.gramsValue", Int(result.protein.rounded()))
    }

    var carbsValueText: String {
        guard let result = analysis.value else { return "" }
        return L10n.format("editMeal.gramsValue", Int(result.carbs.rounded()))
    }

    var fatValueText: String {
        guard let result = analysis.value else { return "" }
        return L10n.format("editMeal.gramsValue", Int(result.fats.rounded()))
    }

    var fullDetailsText: String {
        guard let result = analysis.value else { return "" }
        var lines = details(for: result).split(separator: "\n").map(String.init)
        lines.append("\(L10n.tr("home.fiber")): \(L10n.format("editMeal.gramsValue", Int(result.fiber.rounded())))")
        lines.append("\(L10n.tr("home.sugar")): \(L10n.format("editMeal.gramsValue", Int(result.sugar.rounded())))")
        lines.append("\(L10n.tr("home.sodium")): \(L10n.format("photo.result.mgValue", Int(result.sodium.rounded())))")
        if !confidenceText.value.isEmpty {
            lines.append(confidenceText.value)
        }
        return lines.joined(separator: "\n")
    }

    func updateMealType(_ mealType: MealType) {
        selectedMealType = mealType
    }

    func updateNote(_ text: String?) {
        note = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if note?.isEmpty == true {
            note = nil
        }
    }

    func closeTapped() {
        recognizedTask?.cancel()
        onClose?()
    }

    func dismissResultTapped() {
        recognizedTask?.cancel()
        captureWatchdog?.cancel()
        showsFullDetails.value = false
        capturedImage.value = nil
        analysis.value = nil
        phase.value = .idle
    }

    func switchMode(_ action: HomeQuickLogAction) {
        recognizedTask?.cancel()
        onSwitchMode?(action)
    }

    func viewDetailsTapped() {
        guard let draft = makeDraft() else { return }
        onViewDetails?(draft)
    }

    func confirmLogTapped() {
        guard let draft = makeDraft() else { return }
        onAddEntry?(draft)
    }

    func makeDraft() -> ProductDetailsDraft? {
        guard let result = analysis.value else { return nil }
        return ProductDetailsMath.draft(
            from: result,
            imageData: capturedImage.value?.jpegData(compressionQuality: 0.9),
            mealType: result.mealType,
            date: diaryDate
        )
    }

    func beginCapture() {
        guard phase.value == .idle else { return }
        recognizedTask?.cancel()
        showsFullDetails.value = false
        capturedImage.value = nil
        statusText.value = L10n.tr("photo.analyzing")
        phase.value = .identifying
        // If the camera never hands the photo back, the screen would stay "identifying" and ignore
        // every later shutter press until the app is restarted.
        captureWatchdog?.cancel()
        captureWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.captureTimeoutNanoseconds ?? 0)
            guard let self, !Task.isCancelled,
                  self.phase.value == .identifying, !self.isAnalyzing.value else { return }
            self.fail(with: FoodPhotoCaptureError.cameraUnavailable.localizedDescription)
        }
    }

    func captureFailed(_ error: Error) {
        captureWatchdog?.cancel()
        // Setup problems while the camera merely opens stay quiet; the gallery still works then.
        let userWasWaiting = phase.value == .identifying
        if userWasWaiting {
            Analytics.tracker.track(.errorShown(context: "photo_camera", reason: "capture_failed"))
        }
        fail(with: error.localizedDescription, announce: userWasWaiting)
    }

    func analyze(imageData: Data) {
        capturedImage.value = UIImage(data: imageData)
        startAnalysis(imageData: imageData)
    }

    func analyze(image: UIImage) {
        capturedImage.value = image
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            fail(with: FoodPhotoAnalysisError.compressionFailed.localizedDescription)
            return
        }
        startAnalysis(imageData: data)
    }

    private func startAnalysis(imageData: Data) {
        captureWatchdog?.cancel()
        guard !isAnalyzing.value else { return }
        recognizedTask?.cancel()
        isAnalyzing.value = true
        canConfirmLog.value = false
        analysis.value = nil
        showsFullDetails.value = false
        resultTitleText.value = ""
        resultDetailsText.value = ""
        confidenceText.value = ""
        nutritionScoreText.value = ""
        statusText.value = L10n.tr("photo.analyzing")
        phase.value = .identifying

        Task { @MainActor in
            do {
                let result = try await analyzeFoodPhotoUseCase.execute(
                    imageData: imageData,
                    mealType: selectedMealType,
                    note: note,
                    inventoryMode: inventoryMode
                )
                if inventoryMode {
                    analysis.value = result
                    var items = PantryItem.from(analysis: result)
                    if let searchFoodProductsUseCase {
                        items = await searchFoodProductsUseCase.attachProductPhotos(to: items)
                    }
                    isAnalyzing.value = false
                    Analytics.tracker.track(.recognized("fridge", confidence: result.confidence))
                    onFridgeItemsReady?(items)
                    return
                }
                // A result card for a leaf or a wall would offer to log 0 kcal with a "good" health score.
                if result.findsNoFood { throw FoodPhotoAnalysisError.noFood }
                Analytics.tracker.track(.recognized("photo", confidence: result.confidence))
                analysis.value = result
                resultTitleText.value = result.name
                resultDetailsText.value = details(for: result)
                confidenceText.value = L10n.format("textLog.confidence", Int((result.confidence * 100).rounded()))
                let facts = result.nutritionFacts
                nutritionScoreText.value = L10n.format("home.scoreFormat", facts.score, facts.grade.rawValue)
                canConfirmLog.value = true
                statusText.value = result.assistantMessage.isEmpty ? L10n.tr("textLog.readyToConfirm") : result.assistantMessage
                phase.value = .recognized
                scheduleResultPresentation()
            } catch {
                Analytics.tracker.track(.recognitionFailed(inventoryMode ? "fridge" : "photo", error: error))
                fail(with: error.localizedDescription)
            }
            isAnalyzing.value = false
        }
    }

    private func scheduleResultPresentation() {
        recognizedTask?.cancel()
        recognizedTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, phase.value == .recognized else { return }
            phase.value = .result
        }
    }

    private func fail(with message: String, announce: Bool = true) {
        analysis.value = nil
        capturedImage.value = nil
        canConfirmLog.value = false
        statusText.value = message
        phase.value = .idle
        if announce { errorText.value = message }
        Analytics.tracker.track(.foodLogFailed(method: "photo"))
    }

    private func details(for result: FoodPhotoAnalysis) -> String {
        var lines: [String] = []
        lines.append(L10n.format("textLog.mealLine", result.mealType.localizedTitle))
        lines.append(L10n.format("textLog.caloriesLine", Int(result.calories.rounded())))
        lines.append(L10n.format("textLog.proteinLine", Int(result.protein.rounded())))
        lines.append(L10n.format("textLog.carbsLine", Int(result.carbs.rounded())))
        lines.append(L10n.format("textLog.fatsLine", Int(result.fats.rounded())))
        if let grams = result.portionGrams {
            lines.append(L10n.format("textLog.portionGrams", grams))
        }
        if let ml = result.portionMilliliters {
            lines.append(L10n.format("textLog.portionMl", ml))
        }
        if !result.notes.isEmpty {
            lines.append(result.notes)
        }
        return lines.joined(separator: "\n")
    }
}
