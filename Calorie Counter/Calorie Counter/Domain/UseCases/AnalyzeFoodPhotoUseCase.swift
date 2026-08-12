import Foundation

final class AnalyzeFoodPhotoUseCase {
    private let foodPhotoAnalysisService: FoodPhotoAnalysisServiceProtocol
    private let buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase

    init(
        foodPhotoAnalysisService: FoodPhotoAnalysisServiceProtocol,
        buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase
    ) {
        self.foodPhotoAnalysisService = foodPhotoAnalysisService
        self.buildAIAssistantUserContextUseCase = buildAIAssistantUserContextUseCase
    }

    func execute(
        imageData: Data,
        mealType: MealType = .snacks,
        note: String? = nil,
        includeDiaryContext: Bool = true
    ) async throws -> FoodPhotoAnalysis {
        let context = includeDiaryContext ? try buildAIAssistantUserContextUseCase.execute() : nil
        return try await foodPhotoAnalysisService.analyze(
            imageData: imageData,
            mealType: mealType,
            note: note,
            userContext: context
        )
    }
}
