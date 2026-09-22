import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class CreateRecipeFormSectionTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testRemovingAProductKeepsTheOthersLaidOutAsChips() throws {
        let names = ["Olive Oil", "Chicken Breast", "Spinach", "Greek Yogurt", "Eggs"]
        let (controller, viewModel) = makeScreen(pantry: names)

        let before = chips(in: controller, stack: "pantryChipsStack")
        XCTAssertEqual(before.map(\.title), names)
        assertChipsHugTheirTitles(before)

        let removed = try XCTUnwrap(viewModel.pantryItems.value.first { $0.name == "Chicken Breast" })
        viewModel.removePantryItem(removed.id)
        settle()

        let after = chips(in: controller, stack: "pantryChipsStack")
        XCTAssertEqual(after.map(\.title), names.filter { $0 != "Chicken Breast" })
        assertChipsHugTheirTitles(after)
    }

    func testPickingADietKeepsTheSameChipsInPlace() {
        let (controller, viewModel) = makeScreen(pantry: ["Eggs"])

        let before = chips(in: controller, stack: "dietStack")
        XCTAssertEqual(before.count, viewModel.dietOptions.count)
        let identities = before.map { ObjectIdentifier($0.button) }

        viewModel.selectDiet("recipes.filters.vegan")
        settle()

        let after = chips(in: controller, stack: "dietStack")
        XCTAssertEqual(after.map { ObjectIdentifier($0.button) }, identities, "Diet chips must be reused, not rebuilt")
        XCTAssertEqual(selectedTitles(after), [L10n.tr("recipes.filters.vegan")])
    }

    func testPickingACuisineOrMealKeepsTheSameChipsInPlace() {
        let (controller, viewModel) = makeScreen(pantry: ["Eggs"])
        let cuisine = chips(in: controller, stack: "cuisineStack").map { ObjectIdentifier($0.button) }
        let meals = chips(in: controller, stack: "mealTypeStack").map { ObjectIdentifier($0.button) }
        let cook = chips(in: controller, stack: "cookStack").map { ObjectIdentifier($0.button) }

        viewModel.selectCuisine("recipes.filters.italian")
        viewModel.selectMealType("recipes.filters.dinner")
        viewModel.selectCookTime(30)
        settle()

        XCTAssertEqual(chips(in: controller, stack: "cuisineStack").map { ObjectIdentifier($0.button) }, cuisine)
        XCTAssertEqual(chips(in: controller, stack: "mealTypeStack").map { ObjectIdentifier($0.button) }, meals)
        XCTAssertEqual(chips(in: controller, stack: "cookStack").map { ObjectIdentifier($0.button) }, cook)
        XCTAssertEqual(selectedTitles(chips(in: controller, stack: "cuisineStack")), [L10n.tr("recipes.filters.italian")])
        XCTAssertEqual(selectedTitles(chips(in: controller, stack: "mealTypeStack")), [L10n.tr("recipes.filters.dinner")])
        XCTAssertEqual(selectedTitles(chips(in: controller, stack: "cookStack")), [L10n.tr("recipes.filters.cook30")])
    }

    func testASelectedChipReadsWhiteOnTealInLightAndBlackInDark() {
        let (controller, viewModel) = makeScreen(pantry: ["Eggs"])
        viewModel.selectDiet("recipes.filters.vegan")
        settle()
        let vegan = chips(in: controller, stack: "dietStack").first { $0.title == L10n.tr("recipes.filters.vegan") }
        let foreground = try? XCTUnwrap(vegan?.button.configuration?.baseForegroundColor)
        XCTAssertEqual(foreground, AppColor.onAccent)
        XCTAssertEqual(
            foreground?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)),
            UIColor.white.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        )
    }

    func testProductChipsAreAsTallAsTheDesign() {
        let (controller, _) = makeScreen(pantry: ["Eggs", "Olive Oil"])
        settle()
        let heights = chips(in: controller, stack: "pantryChipsStack").map { $0.button.bounds.height }
        XCTAssertFalse(heights.isEmpty)
        heights.forEach { XCTAssertEqual($0, .adaptHeight(34), accuracy: 0.5) }
    }

    func testTheCalendarCardCarriesItsOwnSmallerCorner() throws {
        let (controller, _) = makeScreen(pantry: ["Eggs"], kind: .mealPlan)
        settle()
        let card = try XCTUnwrap(controller.value(forKey: "datesCard") as? AdaptiveView)
        XCTAssertEqual(card.layer.cornerRadius, .adaptWidth(16), accuracy: 0.5)
        let details = try XCTUnwrap(controller.value(forKey: "detailsCard") as? AdaptiveView)
        XCTAssertEqual(details.layer.cornerRadius, .adaptWidth(16), accuracy: 0.5)
    }

    // MARK: - Helpers

    private func assertChipsHugTheirTitles(
        _ chips: [(button: UIButton, title: String)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        chips.forEach { chip in
            let natural = ProductChipFlow.fittedWidth(chip.button)
            XCTAssertEqual(
                chip.button.bounds.width,
                natural,
                accuracy: 2,
                "\(chip.title) is stretched instead of hugging its title",
                file: file,
                line: line
            )
        }
    }

    private func selectedTitles(_ chips: [(button: UIButton, title: String)]) -> [String] {
        chips.filter { $0.button.configuration?.baseBackgroundColor == AppColor.teal }.map(\.title)
    }

    private func chips(in controller: UIViewController, stack name: String) -> [(button: UIButton, title: String)] {
        guard let stack = controller.value(forKey: name) as? UIStackView else { return [] }
        return buttons(in: stack).map { ($0, title(of: $0)) }
    }

    private func buttons(in view: UIView) -> [UIButton] {
        view.subviews.flatMap { subview -> [UIButton] in
            if let button = subview as? UIButton { return [button] }
            return buttons(in: subview)
        }
    }

    private func title(of button: UIButton) -> String {
        if let identifier = button.accessibilityIdentifier, !identifier.isEmpty { return identifier }
        return button.configuration?.title ?? button.currentTitle ?? ""
    }

    private func settle() {
        window?.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        window?.layoutIfNeeded()
    }

    private func makeScreen(pantry names: [String], kind: CreateRecipeFormKind = .recipe) -> (CreateRecipeFormViewController, CreateRecipeFormViewModel) {
        let harness = TestHarness()
        let items = names.map { name in
            PantryItem(
                id: UUID(), name: name, quantityText: "", amount: nil, unit: nil, useBy: nil,
                imageURL: nil, imageData: nil, createdAt: Date(), updatedAt: Date()
            )
        }
        let spoonacular = MealPlanFakeSpoonacular()
        let viewModel = CreateRecipeFormViewModel(
            kind: kind,
            fetchPantryItemsUseCase: FetchPantryItemsUseCase(pantryRepository: StubPantryRepository(items: items)),
            createRecipeUseCase: CreateRecipeUseCase(
                searchRecipesUseCase: SearchRecipesUseCase(
                    spoonacularService: spoonacular,
                    aiFoodSearchService: MealPlanFakeAISearch()
                ),
                recipeRepository: harness.recipes
            ),
            createMealPlanUseCase: CreateMealPlanUseCase(
                mealPlanRepository: FakeMealPlanRepository(),
                spoonacularService: spoonacular,
                fetchUserPreferencesUseCase: FetchUserPreferencesUseCase(
                    userPreferenceRepository: harness.preferences
                ),
                fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                    foodEntryRepository: harness.food,
                    waterEntryRepository: harness.water,
                    userGoalsRepository: harness.goals,
                    workoutEntryRepository: harness.workout
                ),
                pantryRepository: FakePantryRepository()
            ),
            voiceRecorder: MealPlanFakeVoiceRecorder(),
            transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase(
                voiceFoodTranscriptionService: MealPlanFakeVoiceTranscription()
            )
        )
        viewModel.pantryItems.value = items
        viewModel.selectedPantryIds.value = Set(items.map(\.id))

        let controller = CreateRecipeFormViewController(viewModel: viewModel)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        self.window = window
        return (controller, viewModel)
    }
}

private final class StubPantryRepository: PantryRepositoryProtocol {
    private let items: [PantryItem]

    init(items: [PantryItem]) {
        self.items = items
    }

    func fetchAll() throws -> [PantryItem] { items }
    func save(_ item: PantryItem) throws {}
    func delete(ids: [UUID]) throws {}
}
