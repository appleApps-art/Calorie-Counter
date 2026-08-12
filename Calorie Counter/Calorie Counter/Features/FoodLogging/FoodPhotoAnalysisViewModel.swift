import Foundation
import UIKit

final class FoodPhotoAnalysisViewModel {
    let statusText = Observable(L10n.tr("photo.status"))
    let resultTitleText = Observable("")
    let resultDetailsText = Observable("")
    let confidenceText = Observable("")
    let nutritionScoreText = Observable("")
    let isAnalyzing = Observable(false)
    let canConfirmLog = Observable(false)
    let analysis = Observable<FoodPhotoAnalysis?>(nil)

    var onLogged: (() -> Void)?

    private let analyzeFoodPhotoUseCase: AnalyzeFoodPhotoUseCase
    private let logFoodUseCase: LogFoodUseCase
    private var selectedMealType: MealType = .snacks
    private var note: String?

    init(
        analyzeFoodPhotoUseCase: AnalyzeFoodPhotoUseCase,
        logFoodUseCase: LogFoodUseCase
    ) {
        self.analyzeFoodPhotoUseCase = analyzeFoodPhotoUseCase
        self.logFoodUseCase = logFoodUseCase
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

    func analyze(imageData: Data) {
        guard !isAnalyzing.value else { return }
        isAnalyzing.value = true
        canConfirmLog.value = false
        analysis.value = nil
        resultTitleText.value = ""
        resultDetailsText.value = ""
        confidenceText.value = ""
        statusText.value = L10n.tr("photo.analyzing")

        Task { @MainActor in
            do {
                let result = try await analyzeFoodPhotoUseCase.execute(
                    imageData: imageData,
                    mealType: selectedMealType,
                    note: note
                )
                analysis.value = result
                resultTitleText.value = result.name
                resultDetailsText.value = details(for: result)
                confidenceText.value = L10n.format("textLog.confidence", Int((result.confidence * 100).rounded()))
                let facts = result.nutritionFacts
                nutritionScoreText.value = L10n.format("home.scoreFormat", facts.score, facts.grade.rawValue)
                canConfirmLog.value = true
                statusText.value = result.assistantMessage.isEmpty ? L10n.tr("textLog.readyToConfirm") : result.assistantMessage
            } catch {
                analysis.value = nil
                canConfirmLog.value = false
                statusText.value = error.localizedDescription
            }
            isAnalyzing.value = false
        }
    }

    func analyze(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            statusText.value = FoodPhotoAnalysisError.compressionFailed.localizedDescription
            return
        }
        analyze(imageData: data)
    }

    func confirmLogTapped() {
        guard let result = analysis.value else { return }
        do {
            try logFoodUseCase.execute(result.toFoodEntry(source: "photo"))
            statusText.value = L10n.tr("textLog.foodLogged")
            onLogged?()
        } catch {
            statusText.value = error.localizedDescription
        }
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
