import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class RecognitionResultPanelTests: XCTestCase {
    func testASpokenMealShowsALoaderAndThenAPictureOfTheDish() async throws {
        let picture = try writePicture()
        var requestedName: String?
        let viewModel = makeVoiceViewModel { name in
            requestedName = name
            return picture
        }

        viewModel.analysis.value = meal(named: "Курка з кіноа")
        XCTAssertTrue(viewModel.isResultImageLoading.value, "The photo slot shows a loader right away")
        XCTAssertNil(viewModel.resultImage.value)

        let loaded = await waitUntil { viewModel.resultImage.value != nil }
        XCTAssertTrue(loaded)
        XCTAssertFalse(viewModel.isResultImageLoading.value)
        XCTAssertEqual(requestedName, "Курка з кіноа", "The same picture the details screen asks for by name")
    }

    func testTheDishPictureOnTheVoiceResultGoesOnToTheDiaryEntry() async throws {
        let picture = try writePicture()
        let viewModel = makeVoiceViewModel { _ in picture }
        viewModel.analysis.value = meal(named: "Запечена картопля")
        XCTAssertEqual(viewModel.makeDraft()?.imageURL, picture, "Even before it loads, the entry knows where it is")

        let loaded = await waitUntil { viewModel.resultImage.value != nil }
        XCTAssertTrue(loaded)
        let draft = try XCTUnwrap(viewModel.makeDraft())
        XCTAssertNotNil(draft.imageData, "The picture already on screen is handed over, not fetched again")
        XCTAssertEqual(draft.imageURL, picture)
    }

    func testTheCaloriesTileOnTheVoiceResultIsJustTheNumber() {
        let viewModel = makeVoiceViewModel { _ in nil }
        viewModel.analysis.value = meal(named: "Курка з кіноа")
        XCTAssertEqual(viewModel.caloriesValueText, "420")
        XCTAssertFalse(viewModel.isResultImageLoading.value, "Without a picture to load there is no endless spinner")
    }

    func testTheLoaderSitsInThePhotoSlotOnlyWhileThereIsNoPicture() {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        let spinner = UIActivityIndicatorView(style: .medium)

        RecognitionResultPanel.setImageLoading(true, spinner: spinner, in: imageView)
        XCTAssertTrue(spinner.superview === imageView)
        XCTAssertTrue(spinner.isAnimating)

        imageView.image = UIImage(systemName: "fork.knife")
        RecognitionResultPanel.setImageLoading(true, spinner: spinner, in: imageView)
        XCTAssertFalse(spinner.isAnimating)
    }

    func testThePanelIsTheSheetColourOnlyLighterAndItsCardsAreSolid() {
        let sheet = AdaptiveView(frame: CGRect(x: 0, y: 0, width: 370, height: 500))
        let tint = UIView()
        let card = AdaptiveView()
        RecognitionResultPanel.style(sheet: sheet, tint: tint, cards: [card])

        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            var panel = (white: CGFloat(0), alpha: CGFloat(0))
            var sheetColour = (white: CGFloat(0), alpha: CGFloat(0))
            tint.backgroundColor?.resolvedColor(with: traits).getWhite(&panel.white, alpha: &panel.alpha)
            AppColor.sheetGlassTint.resolvedColor(with: traits).getWhite(&sheetColour.white, alpha: &sheetColour.alpha)
            XCTAssertEqual(panel.white, sheetColour.white, accuracy: 0.01, "Same colour as every other sheet")
            XCTAssertLessThan(panel.alpha, sheetColour.alpha, "More see-through, so the cards on it stand out")
        }
        XCTAssertFalse(card.useLiveGlass)
        XCTAssertEqual(card.cardFillColor, AppColor.backgroundsPrimary)
    }

    func testThePanelCanBePulledDownWithoutStealingTheScroll() throws {
        let panel = AdaptiveView(frame: CGRect(x: 0, y: 0, width: 402, height: 500))
        let scroll = UIScrollView(frame: panel.bounds)
        panel.addSubview(scroll)
        var dismissed = false
        let swipe = ResultPanelSwipeDismissal(panel: panel, scrollView: scroll) { dismissed = true }

        let pan = try XCTUnwrap(panel.gestureRecognizers?.first { $0 is UIPanGestureRecognizer })
        XCTAssertTrue(pan.delegate === swipe)
        XCTAssertFalse(dismissed, "Installing it closes nothing")
        withExtendedLifetime(swipe) {}
    }

    func testRecipeDetailCardsAreBlackInDarkMode() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Calorie Counter/Features/Recipes/RecipeDetailViewController.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(source.contains("backgroundsPrimaryElevated"), "Elevated grey is what made the cards look grey")
        let dark = AppColor.backgroundsPrimary.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        var white: CGFloat = 1
        dark.getWhite(&white, alpha: nil)
        XCTAssertEqual(white, 0, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makeVoiceViewModel(foodImageURL: @escaping (String) -> URL?) -> VoiceFoodLoggingViewModel {
        let harness = TestHarness()
        let diary = FetchDailyDiaryUseCase(
            foodEntryRepository: harness.food,
            waterEntryRepository: harness.water,
            userGoalsRepository: harness.goals,
            workoutEntryRepository: harness.workout
        )
        return VoiceFoodLoggingViewModel(
            recorder: VoiceFoodAudioRecorder(),
            transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase(voiceFoodTranscriptionService: VoiceFoodTranscriptionService()),
            analyzeTextFoodUseCase: AnalyzeTextFoodUseCase(
                textFoodAnalysisService: TextFoodAnalysisService(),
                buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase(
                    fetchDailyDiaryUseCase: diary,
                    userProfileRepository: harness.profile,
                    userPreferenceRepository: harness.preferences
                )
            ),
            imageLoader: RemoteImageLoader(),
            foodImageURL: foodImageURL
        )
    }

    private func meal(named name: String) -> FoodPhotoAnalysis {
        FoodPhotoAnalysis(
            name: name, mealType: .lunch,
            calories: 420, protein: 34, carbs: 42, fats: 13, fiber: 6, sugar: 5, sodium: 400,
            portionGrams: 350, portionMilliliters: nil, confidence: 0.9, notes: "", assistantMessage: ""
        )
    }

    private func writePicture() throws -> URL {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40), format: format).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func waitUntil(timeout: TimeInterval = 3, _ condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }
}
