import Foundation

final class AnalyzeTextFoodUseCase {
    private let textFoodAnalysisService: TextFoodAnalysisServiceProtocol
    private let buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase

    init(
        textFoodAnalysisService: TextFoodAnalysisServiceProtocol,
        buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase
    ) {
        self.textFoodAnalysisService = textFoodAnalysisService
        self.buildAIAssistantUserContextUseCase = buildAIAssistantUserContextUseCase
    }

    func execute(
        text: String,
        mealType: MealType = .snacks,
        includeDiaryContext: Bool = true
    ) async throws -> FoodPhotoAnalysis {
        let context = includeDiaryContext ? try buildAIAssistantUserContextUseCase.execute() : nil
        return try await textFoodAnalysisService.analyze(
            text: text,
            mealType: mealType,
            userContext: context
        )
    }
}
