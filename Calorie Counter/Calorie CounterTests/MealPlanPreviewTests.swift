import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class MealPlanPreviewTests: XCTestCase {
    func testSwappingAMealOffersTheChoiceAndThenPutsItInPlace() async throws {
        let catalog = MealPlanFakeSpoonacular()
        catalog.recipesByDishType = [
            "main course": [
                dish(title: "Запечений лосось", calories: 520),
                dish(title: "Рагу з нутом", calories: 560)
            ]
        ]
        let plans = FakeMealPlanRepository()
        let model = makeModel(catalog: catalog, plans: plans)
        let slot = try XCTUnwrap(model.selectedDay.value?.slots.first { $0.mealType == .lunch })
        var offered: [Recipe] = []
        model.onSwapOptions = { _, options in offered = options }

        model.swapTapped(slot)
        let asked = await waitUntil { !offered.isEmpty }
        XCTAssertTrue(asked, "The sheet from the design opens instead of a silent swap")
        XCTAssertEqual(offered.map(\.title), ["Запечений лосось", "Рагу з нутом"])
        XCTAssertNil(model.swappingRecipeIndex.value, "The spinner gives the arrow back")

        model.applySwap(slot, with: offered[1])
        let lunch = model.selectedDay.value?.slots.first { $0.mealType == .lunch }?.recipe.title
        XCTAssertEqual(lunch, "Рагу з нутом", "The chosen dish is the one that lands in the plan")
        XCTAssertEqual(model.swappedAlertTitle.value, L10n.tr("recipes.mealPlan.swapped"))
        XCTAssertEqual(plans.saved.last?.recipes.contains { $0.title == "Рагу з нутом" }, true)
    }

    func testAPlanOpenedFromTheListAsksWhichDaysItCovers() throws {
        let harness = TestHarness()
        let model = makeModel(
            catalog: MealPlanFakeSpoonacular(),
            plans: FakeMealPlanRepository(),
            harness: harness,
            isFreshlyCreated: false,
            layouts: [1, 1]
        )
        var asked: MealPlan?
        model.onPickDiaryDates = { asked = $0 }

        model.addToDiaryTapped()
        XCTAssertNotNil(asked, "The sheet from the design comes first")
        XCTAssertFalse(model.addedAlertVisible.value)
        XCTAssertTrue(try harness.food.fetchAll().isEmpty, "Nothing is logged until the days are picked")

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: today))
        model.addPlan(on: [today, tomorrow])
        let logged = try harness.food.fetchAll()
        XCTAssertEqual(logged.count, 2, "Each day of the plan lands on its own date")
        XCTAssertEqual(
            Set(logged.map { Calendar.current.startOfDay(for: $0.date) }),
            [today, tomorrow]
        )
        XCTAssertTrue(model.addedAlertVisible.value)
    }

    func testAPlanJustCreatedGoesStraightIntoTheDiary() throws {
        let harness = TestHarness()
        let model = makeModel(
            catalog: MealPlanFakeSpoonacular(),
            plans: FakeMealPlanRepository(),
            harness: harness
        )
        var asked = false
        model.onPickDiaryDates = { _ in asked = true }

        model.addToDiaryTapped()
        XCTAssertFalse(asked, "Right after creating it, the button just logs the day")
        XCTAssertTrue(model.addedAlertVisible.value)
        XCTAssertFalse(try harness.food.fetchAll().isEmpty)
    }

    func testTheScreenClosesOnceTheDayIsInTheDiary() {
        let model = makeModel(catalog: MealPlanFakeSpoonacular(), plans: FakeMealPlanRepository())
        var closed = false
        model.onBack = { closed = true }
        model.addToDiaryTapped()
        XCTAssertTrue(model.addedAlertVisible.value)
        model.dismissAddedAlert()
        XCTAssertTrue(closed, "Nothing is left to do on the plan once its day is logged")
    }

    func testAMealWithNoReplacementSaysSoInsteadOfSpinningForNothing() async throws {
        let model = makeModel(catalog: MealPlanFakeSpoonacular(), plans: FakeMealPlanRepository())
        let slot = try XCTUnwrap(model.selectedDay.value?.slots.first)

        model.swapTapped(slot)
        let told = await waitUntil { model.swappedAlertVisible.value }
        XCTAssertTrue(told)
        XCTAssertEqual(model.swappedAlertTitle.value, L10n.tr("recipes.mealPlan.swapUnavailable"))
        XCTAssertNil(model.swappingRecipeIndex.value, "The arrow comes back")
    }

    func testSharingSendsTheWholePlanAndNotJustItsHeadline() {
        let model = makeModel(catalog: MealPlanFakeSpoonacular(), plans: FakeMealPlanRepository())
        var shared = ""
        model.onShare = { text, _ in shared = text }
        model.shareTapped()

        XCTAssertTrue(shared.contains("План 1"))
        XCTAssertTrue(shared.contains(L10n.format("recipes.mealPlan.day", 1)))
        XCTAssertTrue(shared.contains("Вівсянка"), "Every dish travels with the plan")
        XCTAssertTrue(shared.contains("Паста"))
        XCTAssertTrue(shared.contains(MealType.lunch.localizedTitle))
    }

    func testDeletingAPlanAsksFirst() {
        let plans = FakeMealPlanRepository()
        let model = makeModel(catalog: MealPlanFakeSpoonacular(), plans: plans)
        var asked = false
        var deleted = false
        model.onConfirmDelete = { asked = true }
        model.onDeleted = { deleted = true }

        model.deleteTapped()
        XCTAssertTrue(asked)
        XCTAssertFalse(deleted, "Nothing is removed before the question is answered")
        XCTAssertTrue(plans.deleted.isEmpty)

        model.deleteConfirmed()
        XCTAssertTrue(deleted)
        XCTAssertEqual(plans.deleted.count, 1)
    }

    func testTheArrowIsReplacedByASpinnerWhileTheSwapLoads() throws {
        let row = MealPlanMealRowView()
        row.frame = CGRect(x: 0, y: 0, width: 370, height: 76)
        let slot = MealPlanSlot(
            mealType: .lunch,
            recipeIndex: 0,
            recipe: dish(title: "Паста", calories: 600)
        )
        row.configure(slot, isSwapping: true)
        row.layoutIfNeeded()

        let spinner = try XCTUnwrap(firstSpinner(in: row, id: "mealPlan.row.swapSpinner"))
        let arrow = try XCTUnwrap(firstButton(in: row) { $0.isHidden })
        XCTAssertTrue(spinner.isAnimating, "The wait has to be visible")
        XCTAssertFalse(spinner.isHidden)
        let spinnerCentre = spinner.superview?.convert(spinner.center, to: row) ?? spinner.center
        let arrowCentre = arrow.superview?.convert(arrow.center, to: row) ?? arrow.center
        XCTAssertEqual(spinnerCentre.x, arrowCentre.x, accuracy: 1, "It stands exactly where the arrow was")
        XCTAssertEqual(spinnerCentre.y, arrowCentre.y, accuracy: 1)
        XCTAssertTrue(row.bounds.insetBy(dx: -1, dy: -1).contains(spinnerCentre), "And inside the row")
    }

    func testTheDishPhotoSlotShowsALoaderUntilThePictureArrives() throws {
        let row = MealPlanMealRowView()
        row.frame = CGRect(x: 0, y: 0, width: 370, height: 76)
        var recipe = dish(title: "Паста", calories: 600)
        // A host nobody answers: the picture is still on its way when the row appears.
        recipe.imageURL = URL(string: "https://10.255.255.1/pasta-\(UUID().uuidString).jpg")
        row.configure(MealPlanSlot(mealType: .lunch, recipeIndex: 0, recipe: recipe), isSwapping: false)
        row.layoutIfNeeded()

        let spinner = try XCTUnwrap(firstSpinner(in: row, id: "mealPlan.row.photoSpinner"))
        XCTAssertTrue(spinner.isAnimating, "The slot shows the wait, not an empty square or a fork")
        let photo = try XCTUnwrap(row.value(forKey: "photoImageView") as? UIImageView)
        XCTAssertNil(photo.image, "No placeholder glyph while loading")
        let spinnerCentre = spinner.superview?.convert(spinner.center, to: row) ?? .zero
        let photoCentre = photo.superview?.convert(photo.center, to: row) ?? .zero
        XCTAssertEqual(spinnerCentre.x, photoCentre.x, accuracy: 1)
        XCTAssertEqual(spinnerCentre.y, photoCentre.y, accuracy: 1)
    }

    func testDishNamesInThePlanAreSeventeenPoints() throws {
        let row = MealPlanMealRowView()
        row.configure(MealPlanSlot(mealType: .lunch, recipeIndex: 0, recipe: dish(title: "Паста", calories: 600)), isSwapping: false)
        let name = try XCTUnwrap(firstLabel(in: row) { $0.text == "Паста" })
        XCTAssertEqual(name.font.pointSize, .adaptFont(17), accuracy: 0.5)
    }

    func testTappingADishInTheSwapSheetPicksIt() throws {
        let slot = MealPlanSlot(mealType: .lunch, recipeIndex: 0, recipe: dish(title: "Паста", calories: 600))
        let options = [dish(title: "Лосось", calories: 520), dish(title: "Рагу", calories: 560)]
        let sheet = SwapMealSheetViewController(slot: slot, options: options)
        sheet.view.frame = CGRect(x: 0, y: 0, width: 402, height: 700)
        sheet.loadViewIfNeeded()
        sheet.view.layoutIfNeeded()
        var confirmed: Recipe?
        sheet.onConfirm = { confirmed = $0 }

        let rows = controls(in: sheet.view).filter(\.isUserInteractionEnabled)
        XCTAssertEqual(rows.count, options.count, "Only the replacements can be picked")
        rows[1].sendActions(for: .touchUpInside)
        sheet.view.layoutIfNeeded()

        let button = try XCTUnwrap(firstButton(in: sheet.view) { $0.configuration?.title != nil })
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(confirmed?.title, "Рагу", "The dish the user tapped is the one that is used")
    }

    // MARK: - Helpers

    private func controls(in view: UIView) -> [UIControl] {
        view.subviews.flatMap { subview -> [UIControl] in
            if let control = subview as? UIControl, !(control is UIButton) { return [control] }
            return controls(in: subview)
        }
    }

    private func firstButton(in view: UIView, where match: (UIButton) -> Bool) -> UIButton? {
        for subview in view.subviews {
            if let button = subview as? UIButton, match(button) { return button }
            if let found = firstButton(in: subview, where: match) { return found }
        }
        return nil
    }

    // MARK: - Editing the plan with Bity

    func testBitySwapsTheDishItNamesInThePlan() throws {
        let plans = FakeMealPlanRepository()
        let model = makeModel(catalog: MealPlanFakeSpoonacular(), plans: plans)

        let applied = model.applySwapProposal(
            MealPlanSwapProposal(
                dayNumber: 1,
                mealType: .breakfast,
                currentTitle: "Вівсянка",
                replacementTitle: "Омлет з овочами",
                calories: 380,
                protein: 24,
                carbs: 12,
                fats: 19,
                ingredients: ["2 яйця", "150 г овочів"],
                steps: ["Збийте яйця та обсмажте."]
            )
        )

        XCTAssertTrue(applied)
        let saved = try XCTUnwrap(plans.saved.last)
        XCTAssertEqual(saved.recipes.map(\.title), ["Омлет з овочами", "Паста"], "Only the named dish moves")
        XCTAssertEqual(saved.recipes.first?.calories, 380)
        XCTAssertEqual(saved.recipes.first?.ingredients.map(\.name), ["2 яйця", "150 г овочів"])
        XCTAssertTrue(model.swappedAlertVisible.value, "The same confirmation as a manual swap")
    }

    func testAProposalThatPointsAtNothingLeavesThePlanAlone() {
        let plans = FakeMealPlanRepository()
        let model = makeModel(catalog: MealPlanFakeSpoonacular(), plans: plans)

        let applied = model.applySwapProposal(
            MealPlanSwapProposal(currentTitle: "Борщ", replacementTitle: "Омлет")
        )

        XCTAssertFalse(applied)
        XCTAssertTrue(plans.saved.isEmpty, "Nothing is written when the dish is not in the plan")
    }

    private func firstLabel(in view: UIView, where match: (UILabel) -> Bool) -> UILabel? {
        for subview in view.subviews {
            if let found = subview as? UILabel, match(found) { return found }
            if let nested = firstLabel(in: subview, where: match) { return nested }
        }
        return nil
    }

    private func firstSpinner(in view: UIView, id: String? = nil) -> UIActivityIndicatorView? {
        for subview in view.subviews {
            if let found = subview as? UIActivityIndicatorView, id == nil || found.accessibilityIdentifier == id {
                return found
            }
            if let nested = firstSpinner(in: subview, id: id) { return nested }
        }
        return nil
    }


    private func makeModel(
        catalog: MealPlanFakeSpoonacular,
        plans: FakeMealPlanRepository,
        harness: TestHarness = TestHarness(),
        isFreshlyCreated: Bool = true,
        layouts: [Int] = [2]
    ) -> MealPlanPreviewViewModel {
        let plan = MealPlan(
            id: UUID(),
            title: CreateMealPlanUseCase.planTitle(number: 1),
            weeks: 1,
            imageURL: nil,
            recipes: [dish(title: "Вівсянка", calories: 420), dish(title: "Паста", calories: 600)],
            createdAt: Date(),
            dayLayouts: layouts,
            mealTypeKeys: ["breakfast", "lunch"]
        )
        let model = MealPlanPreviewViewModel(
            plan: plan,
            mealPlanRepository: plans,
            searchRecipesUseCase: SearchRecipesUseCase(
                spoonacularService: catalog,
                aiFoodSearchService: MealPlanFakeAISearch()
            ),
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                foodEntryRepository: harness.food,
                waterEntryRepository: harness.water,
                userGoalsRepository: harness.goals,
                workoutEntryRepository: harness.workout
            ),
            logFoodUseCase: LogFoodUseCase(foodEntryRepository: harness.food),
            isFreshlyCreated: isFreshlyCreated
        )
        model.viewDidLoad()
        return model
    }

    private func dish(title: String, calories: Double) -> Recipe {
        Recipe(
            id: UUID(),
            externalId: nil,
            title: title,
            summary: nil,
            imageURL: URL(string: "https://img.spoonacular.com/recipes/1-556x370.jpg"),
            readyInMinutes: 20,
            servings: 1,
            calories: calories,
            protein: 20,
            carbs: 40,
            fats: 10,
            ingredients: [],
            steps: ["Крок"],
            sourceName: nil
        )
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
