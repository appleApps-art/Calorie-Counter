import Foundation

final class TextFoodLoggingViewModel {
    let statusText = Observable(L10n.tr("textLog.status"))
    let resultTitleText = Observable("")
    let resultDetailsText = Observable("")
    let confidenceText = Observable("")
    let nutritionScoreText = Observable("")
    let isAnalyzing = Observable(false)
    let canAnalyze = Observable(false)
    let canConfirmLog = Observable(false)
    let isEditingDetails = Observable(false)
    let showsResultCard = Observable(false)
    let draftName = Observable("")
    let draftCalories = Observable("")
    let draftProtein = Observable("")
    let draftCarbs = Observable("")
    let draftFats = Observable("")
    let mealTypeIndex = Observable(MealType.snacks.caseIndex)

    var onLogged: (() -> Void)?

    private let analyzeTextFoodUseCase: AnalyzeTextFoodUseCase
    private let logFoodUseCase: LogFoodUseCase
    private var inputText = ""
    private var analysis: FoodPhotoAnalysis?

    init(
        analyzeTextFoodUseCase: AnalyzeTextFoodUseCase,
        logFoodUseCase: LogFoodUseCase
    ) {
        self.analyzeTextFoodUseCase = analyzeTextFoodUseCase
        self.logFoodUseCase = logFoodUseCase
    }

    func updateInputText(_ text: String) {
        inputText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        canAnalyze.value = !inputText.isEmpty && !isAnalyzing.value
    }

    func updateMealTypeIndex(_ index: Int) {
        mealTypeIndex.value = max(0, min(index, MealType.allCases.count - 1))
    }

    func analyzeTapped() {
        guard !isAnalyzing.value else { return }
        let text = inputText
        guard !text.isEmpty else {
            statusText.value = FoodPhotoAnalysisError.emptyText.localizedDescription
            return
        }

        isAnalyzing.value = true
        canAnalyze.value = false
        canConfirmLog.value = false
        showsResultCard.value = false
        isEditingDetails.value = false
        analysis = nil
        statusText.value = L10n.tr("textLog.analyzing")

        let mealType = MealType.allCases[mealTypeIndex.value]

        Task { @MainActor in
            do {
                let result = try await analyzeTextFoodUseCase.execute(
                    text: text,
                    mealType: mealType
                )
                applyAnalysis(result)
            } catch {
                analysis = nil
                canConfirmLog.value = false
                showsResultCard.value = false
                statusText.value = error.localizedDescription
            }
            isAnalyzing.value = false
            canAnalyze.value = !inputText.isEmpty
        }
    }

    func editDetailsTapped() {
        guard analysis != nil else { return }
        isEditingDetails.value = true
    }

    func updateDraftName(_ text: String) {
        draftName.value = text
    }

    func updateDraftCalories(_ text: String) {
        draftCalories.value = text
    }

    func updateDraftProtein(_ text: String) {
        draftProtein.value = text
    }

    func updateDraftCarbs(_ text: String) {
        draftCarbs.value = text
    }

    func updateDraftFats(_ text: String) {
        draftFats.value = text
    }

    func confirmLogTapped() {
        guard var result = analysis else { return }
        result.name = draftName.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.name.isEmpty else {
            statusText.value = L10n.tr("textLog.nameRequired")
            return
        }
        result.calories = Double(draftCalories.value) ?? result.calories
        result.protein = Double(draftProtein.value) ?? result.protein
        result.carbs = Double(draftCarbs.value) ?? result.carbs
        result.fats = Double(draftFats.value) ?? result.fats
        result.mealType = MealType.allCases[mealTypeIndex.value]
        analysis = result

        do {
            try logFoodUseCase.execute(result.toFoodEntry(source: "text"))
            statusText.value = L10n.tr("textLog.foodLogged")
            onLogged?()
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    private func applyAnalysis(_ result: FoodPhotoAnalysis) {
        analysis = result
        if let index = MealType.allCases.firstIndex(of: result.mealType) {
            mealTypeIndex.value = index
        }
        draftName.value = result.name
        draftCalories.value = String(Int(result.calories.rounded()))
        draftProtein.value = String(Int(result.protein.rounded()))
        draftCarbs.value = String(Int(result.carbs.rounded()))
        draftFats.value = String(Int(result.fats.rounded()))
        resultTitleText.value = result.name
        resultDetailsText.value = details(for: result)
        confidenceText.value = L10n.format("textLog.confidence", Int((result.confidence * 100).rounded()))
        let facts = result.nutritionFacts
        nutritionScoreText.value = L10n.format("home.scoreFormat", facts.score, facts.grade.rawValue)
        showsResultCard.value = true
        canConfirmLog.value = true
        isEditingDetails.value = false
        statusText.value = result.assistantMessage.isEmpty ? L10n.tr("textLog.readyToConfirm") : result.assistantMessage
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

private extension MealType {
    var caseIndex: Int {
        MealType.allCases.firstIndex(of: self) ?? 0
    }
}
