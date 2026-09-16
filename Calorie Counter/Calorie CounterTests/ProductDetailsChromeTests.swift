import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class ProductDetailsChromeTests: XCTestCase {
    func testProductDetailsXibWrapsTagsInHorizontalScrollView() throws {
        let xml = try String(contentsOf: productDetailsURL("ProductDetailsViewController.xib"), encoding: .utf8)
        XCTAssertTrue(xml.contains("outlet property=\"tagsScrollView\" destination=\"tags-scroll\""))
        XCTAssertTrue(xml.contains("id=\"tags-scroll\""))
        XCTAssertTrue(xml.contains("alwaysBounceHorizontal=\"YES\""))
        XCTAssertTrue(xml.contains("id=\"tags\" customClass=\"AdaptiveStackView\""))
        XCTAssertTrue(xml.contains("firstItem=\"tags\" firstAttribute=\"leading\" secondItem=\"tags-content\""))
        XCTAssertTrue(xml.contains("firstItem=\"tags-content\" firstAttribute=\"trailing\" secondItem=\"tags\""))
    }

    func testProductDetailsTagsScrollInsteadOfClipping() {
        let viewModel = ProductDetailsViewModel()
        let controller = ProductDetailsViewController(viewModel: viewModel)
        viewModel.configure(draftWithOverflowingTags())
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()

        let chips = views(of: ProductTagChipView.self, in: controller.view)
        XCTAssertGreaterThanOrEqual(chips.count, 4)
        guard let stack = chips.first?.superview as? UIStackView,
              let scrollView = stack.superview as? UIScrollView else {
            return XCTFail("nutrition tags should live in a horizontal scroll view")
        }
        XCTAssertFalse(scrollView.isHidden)
        XCTAssertGreaterThan(scrollView.contentSize.width, scrollView.bounds.width)
        XCTAssertTrue(scrollView.isScrollEnabled)

        let last = chips.max { lhs, rhs in
            lhs.convert(lhs.bounds, to: scrollView).maxX < rhs.convert(rhs.bounds, to: scrollView).maxX
        }!
        let fitting = last.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        XCTAssertEqual(last.bounds.width, fitting.width, accuracy: 1)
        XCTAssertGreaterThan(last.convert(last.bounds, to: scrollView).maxX, scrollView.bounds.width)
    }

    func testProductWithCatalogCompositionNeverShowsRecipeSections() throws {
        var draft = draftWithOverflowingTags()
        draft.catalogKind = .product
        draft.ingredients = [FoodIngredient(name: "Milk", grams: 100)]
        draft.recipeSteps = ["Recipe-like metadata must not turn a product into a dish"]
        let model = ProductDetailsViewModel()
        model.configure(draft)
        let screen = ProductDetailsViewController(viewModel: model)
        screen.loadViewIfNeeded()
        XCTAssertTrue(model.ingredients.value.isEmpty)
        XCTAssertTrue(model.recipeSteps.value.isEmpty)
        XCTAssertFalse(model.wantToCookVisible.value)
        XCTAssertTrue(try XCTUnwrap(screen.value(forKey: "ingredientsSection") as? UIView).isHidden)
        XCTAssertTrue(try XCTUnwrap(screen.value(forKey: "recipeSection") as? UIView).isHidden)
        XCTAssertEqual(model.draft.value?.ingredients.count, 1, "Preserve catalog data for logging")
    }

    func testWellnessUsesSelectedDateServingsAndRefreshesDiary() throws {
        var diary = emptyDiary(calories: 500)
        var requestedDate: Date?
        var draft = draftWithOverflowingTags()
        draft.servings = 2
        let model = ProductDetailsViewModel(diaryProvider: { date in
            requestedDate = date
            return diary
        })
        model.configure(draft)
        XCTAssertEqual(requestedDate, draft.date)
        XCTAssertTrue(model.suggestionVisible.value)
        XCTAssertFalse(model.canAddSuggestion.value)
        XCTAssertTrue(model.suggestionSummaryText.value.contains(L10n.format("product.insight.after", 400)))
        XCTAssertTrue(model.suggestionSummaryText.value.contains(L10n.format("product.insight.protein", 40, 110)))
        diary = emptyDiary(calories: 70)
        model.refreshInsights()
        XCTAssertTrue(model.suggestionSummaryText.value.contains(L10n.format("product.insight.over", 30)))
        XCTAssertEqual(model.draft.value, draft, "Reading an insight must not modify or log food")
    }

    func testWellnessHandlesMissingNutritionAndUnavailableDiary() {
        var draft = draftWithOverflowingTags()
        XCTAssertTrue(ProductDetailsViewModel.wellnessSummary(for: draft, diary: nil)
            .contains(L10n.tr("product.insight.noDiary")))
        draft.calories = 0
        XCTAssertEqual(ProductDetailsViewModel.wellnessSummary(for: draft, diary: emptyDiary(calories: 500)),
                       L10n.tr("product.insight.missingNutrition"))
    }

    func testRelatedRecipeOpensActualRecipeAndKeepsLoggingContext() async throws {
        var original = draftWithOverflowingTags()
        original.logDates = [original.date]
        let recipe = Recipe(id: UUID(), externalId: "123", title: "Yogurt bowl", summary: nil,
                            imageURL: nil, readyInMinutes: 5, servings: 2, calories: 250,
                            protein: 20, carbs: 25, fats: 6,
                            ingredients: [RecipeIngredient(id: "yogurt", name: "Yogurt", amount: 200, unit: "g")],
                            steps: ["Mix"], sourceName: nil, origin: .spoonacular)
        let model = ProductDetailsViewModel(relatedRecipeLoader: { query in
            XCTAssertEqual(query, original.name)
            return [recipe]
        })
        model.configure(original)
        for _ in 0..<20 where model.relatedRecipeLoading.value { await Task.yield() }
        XCTAssertEqual(model.relatedRecipe.value?.externalId, "123")
        XCTAssertTrue(model.wantToCookVisible.value)
        var opened: ProductDetailsDraft?
        var logged = false
        model.onOpenRecipe = { opened = $0 }
        model.onAddToDiary = { _ in logged = true }
        model.wantToCookTapped()
        XCTAssertEqual(opened?.name, recipe.title)
        XCTAssertEqual(opened?.catalogKind, .recipe)
        XCTAssertEqual(opened?.servings, 1)
        XCTAssertEqual(opened?.date, original.date)
        XCTAssertEqual(opened?.logDates, original.logDates)
        XCTAssertFalse(logged)
        XCTAssertEqual(model.draft.value, original)
    }

    func testRelatedRecipeFailureCanRetry() async {
        var requests = 0
        let model = ProductDetailsViewModel(relatedRecipeLoader: { _ in
            requests += 1
            return []
        })
        model.configure(draftWithOverflowingTags())
        for _ in 0..<20 where model.relatedRecipeLoading.value { await Task.yield() }
        XCTAssertTrue(model.relatedRecipeUnavailable.value)
        XCTAssertTrue(model.wantToCookVisible.value)
        model.wantToCookTapped()
        for _ in 0..<20 where model.relatedRecipeLoading.value { await Task.yield() }
        XCTAssertEqual(requests, 2)
        XCTAssertNil(model.relatedRecipe.value)
    }

    private func emptyDiary(calories: Double) -> DailyDiarySummary {
        DailyDiarySummary(date: Date(), foodEntries: [], waterEntries: [], workouts: [], waterMilliliters: 0,
                          goals: UserGoals(calorieTarget: calories, proteinTarget: 150, carbsTarget: 200,
                                           fatsTarget: 65, fiberTarget: 25, sugarTarget: 50,
                                           sodiumTarget: 2300, waterTargetMilliliters: 2500))
    }

    private func draftWithOverflowingTags() -> ProductDetailsDraft {
        ProductDetailsDraft(
            name: "Борщ",
            servingLabel: "100 g",
            mealType: .snacks,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            servings: 1,
            calories: 50,
            protein: 20,
            carbs: 7,
            fats: 1.7,
            fiber: 8,
            sugar: 2,
            sodium: 80,
            portionGrams: 100,
            portionMilliliters: nil,
            ingredients: [],
            tags: [
                "Багато білка",
                "Мало вуглеводів",
                "Мало цукру",
                "Мало натрію",
                "Висока клітковина"
            ],
            notes: "",
            source: "text",
            imageData: nil
        )
    }

    private func views<T: UIView>(of type: T.Type, in root: UIView) -> [T] {
        var result: [T] = []
        var stack = [root]
        while let current = stack.popLast() {
            if let match = current as? T {
                result.append(match)
            }
            stack.append(contentsOf: current.subviews)
        }
        return result
    }

    private func productDetailsURL(_ fileName: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Features/FoodLogging/\(fileName)")
    }
}
