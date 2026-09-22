import Foundation

enum CreateRecipeFormKind {
    case recipe
    case mealPlan
}

enum CreateIngredientSource: Equatable {
    case pantry
    case custom
}

final class CreateRecipeFormViewModel {
    let kind: CreateRecipeFormKind
    let titleText: String
    let source = Observable(CreateIngredientSource.pantry)
    let pantryItems = Observable<[PantryItem]>([])
    let selectedPantryIds = Observable<Set<UUID>>([])
    let customIngredients = Observable<[String]>([])
    let ingredientQuery = Observable("")
    let mealTypeKey = Observable("recipes.filters.breakfast")
    let selectedMealKeys = Observable<[String]>([
        "recipes.filters.breakfast",
        "recipes.filters.lunch",
        "recipes.filters.dinner"
    ])
    let cookMinutes = Observable<Int?>(nil)
    let maxCalories = Observable(250)
    let cuisineKey = Observable("recipes.filters.any")
    let dietKey = Observable("recipes.filters.any")
    let detailsText = Observable("")
    let selectedDates = Observable<[Date]>([])
    let isLoading = Observable(false)
    let isRecording = Observable(false)
    let canConfirmIngredient = Observable(false)

    let mealTypeOptions = [
        "recipes.filters.breakfast",
        "recipes.filters.lunch",
        "recipes.filters.dinner",
        "recipes.filters.snack"
    ]
    let cuisineOptions = [
        "recipes.filters.any",
        "recipes.filters.italian",
        "recipes.filters.asian",
        "recipes.filters.mexican",
        "recipes.filters.greek"
    ]
    let dietOptions = [
        "recipes.filters.any",
        "recipes.filters.vegetarian",
        "recipes.filters.vegan",
        "recipes.filters.lean",
        "recipes.filters.weightGain",
        "recipes.filters.balance"
    ]
    let cookOptions: [(String, Int?)] = [
        ("recipes.filters.any", nil),
        ("recipes.filters.cook15", 15),
        ("recipes.filters.cook30", 30),
        ("recipes.filters.cook60", 60)
    ]

    var onBack: (() -> Void)?
    var onCreatedRecipe: ((Recipe) -> Void)?
    var onCreatedMealPlan: ((MealPlan) -> Void)?
    var onCreateFinished: ((Recipe?, MealPlan?) -> Void)?

    private let fetchPantryItemsUseCase: FetchPantryItemsUseCase
    private let createRecipeUseCase: CreateRecipeUseCase
    private let createMealPlanUseCase: CreateMealPlanUseCase
    private let dictation: VoiceConfirmDictation

    init(
        kind: CreateRecipeFormKind,
        fetchPantryItemsUseCase: FetchPantryItemsUseCase,
        createRecipeUseCase: CreateRecipeUseCase,
        createMealPlanUseCase: CreateMealPlanUseCase,
        voiceRecorder: VoiceFoodAudioRecording,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase
    ) {
        self.kind = kind
        self.titleText = L10n.tr(kind == .recipe ? "recipes.createRecipe" : "recipes.createMealPlan")
        self.fetchPantryItemsUseCase = fetchPantryItemsUseCase
        self.createRecipeUseCase = createRecipeUseCase
        self.createMealPlanUseCase = createMealPlanUseCase
        dictation = VoiceConfirmDictation(
            recorder: voiceRecorder,
            transcribeFoodVoiceUseCase: transcribeFoodVoiceUseCase
        )
        dictation.onText = { [weak self] text in
            self?.ingredientQuery.value = text
        }
        dictation.isRecording.bind { [weak self] value in
            self?.isRecording.value = value
        }
        dictation.canConfirm.bind { [weak self] value in
            self?.canConfirmIngredient.value = value
        }
        selectedDates.value = Self.defaultDates()
    }

    var selectedPantryNames: [String] {
        let ids = selectedPantryIds.value
        return pantryItems.value.filter { ids.contains($0.id) }.map(\.name)
    }

    var dateRangeText: String {
        let dates = selectedDates.value.sorted()
        guard let start = dates.first, let end = dates.last else {
            return L10n.tr("recipes.create.selectDates")
        }
        return Self.formatRange(start: start, end: end)
    }

    func viewDidLoad() {
        let items = (try? fetchPantryItemsUseCase.execute()) ?? []
        pantryItems.value = items
        selectedPantryIds.value = Set(items.map(\.id))
    }

    func backTapped() {
        dictation.cancel()
        onBack?()
    }

    func selectSource(_ source: CreateIngredientSource) {
        dictation.cancel()
        self.source.value = source
        ingredientQuery.value = ""
        canConfirmIngredient.value = false
    }

    func removePantryItem(_ id: UUID) {
        var next = selectedPantryIds.value
        next.remove(id)
        selectedPantryIds.value = next
    }

    func updateIngredientQuery(_ text: String) {
        ingredientQuery.value = text
        dictation.clearConfirmIfEmpty(text)
    }

    /// "огірки, помідори, капуста" is three products, not one long tag.
    func addCustomIngredient(_ name: String) {
        let parts = name
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return }
        var next = customIngredients.value
        parts.forEach { part in
            guard !next.contains(where: { $0.caseInsensitiveCompare(part) == .orderedSame }) else { return }
            next.append(part)
        }
        customIngredients.value = next
        ingredientQuery.value = ""
        dictation.consumeConfirm()
    }

    func removeCustomIngredient(_ name: String) {
        customIngredients.value.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    func selectMealType(_ key: String) {
        if kind == .mealPlan {
            var next = selectedMealKeys.value
            if let index = next.firstIndex(of: key) {
                next.remove(at: index)
            } else {
                next.append(key)
            }
            selectedMealKeys.value = next
        } else {
            mealTypeKey.value = key
        }
    }

    func selectCookTime(_ minutes: Int?) {
        cookMinutes.value = minutes
    }

    func updateCalories(_ value: Int) {
        let next = min(max(value, 0), RecipeSearchFilters.calorieCeiling)
        guard maxCalories.value != next else { return }
        maxCalories.value = next
    }

    func selectCuisine(_ key: String) {
        cuisineKey.value = key
    }

    func selectDiet(_ key: String) {
        dietKey.value = key
    }

    func updateDetails(_ text: String) {
        detailsText.value = text
    }

    func updateDates(_ dates: [Date]) {
        selectedDates.value = dates.sorted()
    }

    func toggleVoiceTapped() {
        if canConfirmIngredient.value {
            dictation.consumeConfirm()
            addCustomIngredient(ingredientQuery.value)
            return
        }
        if isRecording.value {
            dictation.finish()
        } else {
            dictation.start()
        }
    }

    /// A recipe is cooked from products, so it cannot be made from none; a meal plan can.
    /// A product typed into the field but not yet confirmed still counts.
    func acceptPendingIngredientAndCheckMissing() -> Bool {
        if source.value == .custom {
            addCustomIngredient(ingredientQuery.value)
        }
        guard kind == .recipe else { return false }
        return makeInput().ingredients.isEmpty
    }

    var missingIngredientsMessage: String {
        guard source.value == .pantry else { return L10n.tr("recipes.create.noIngredientsCustom") }
        return pantryItems.value.isEmpty
            ? L10n.tr("recipes.create.noIngredientsEmptyPantry")
            : L10n.tr("recipes.create.noIngredientsPantry")
    }

    func createTapped() {
        guard !isLoading.value else { return }
        isLoading.value = true
        let input = makeInput()
        let kindName = kind == .recipe ? "recipe" : "meal_plan"
        Analytics.tracker.track(.recipeCreateStarted(
            kind: kindName,
            source: String(describing: source.value),
            ingredientCount: input.ingredients.count
        ))
        let started = Date()
        Task { @MainActor in
            var recipe: Recipe?
            var plan: MealPlan?
            do {
                switch kind {
                case .recipe:
                    recipe = try await createRecipeUseCase.execute(input)
                case .mealPlan:
                    plan = try await createMealPlanUseCase.execute(input)
                }
            } catch {
            }
            Analytics.tracker.track(.recipeCreateFinished(
                kind: kindName,
                success: recipe != nil || plan != nil,
                origin: recipe.map { $0.origin.isAIRecipe ? "ai" : "catalog" },
                seconds: Int(Date().timeIntervalSince(started).rounded())
            ))
            onCreateFinished?(recipe, plan)
        }
    }

    func endLoading() {
        isLoading.value = false
    }

    private func makeInput() -> RecipeGenerationInput {
        let ingredients: [String]
        switch source.value {
        case .pantry:
            ingredients = selectedPantryNames
        case .custom:
            ingredients = customIngredients.value
        }
        let mealTypes: [String]
        if kind == .mealPlan {
            mealTypes = selectedMealKeys.value.map(Self.mealTypeValue(from:))
        } else {
            mealTypes = [Self.mealTypeValue(from: mealTypeKey.value)]
        }
        let cuisine: String?
        let diet: String?
        if kind == .mealPlan {
            cuisine = cuisineKey.value == "recipes.filters.any" ? nil : cuisineKey.value
            diet = dietKey.value == "recipes.filters.any" ? nil : dietKey.value
        } else {
            cuisine = cuisineKey.value == "recipes.filters.any" ? nil : L10n.tr(cuisineKey.value)
            diet = dietKey.value == "recipes.filters.any" ? nil : L10n.tr(dietKey.value)
        }
        let dates = selectedDates.value.sorted()
        return RecipeGenerationInput(
            ingredients: ingredients,
            mealTypes: mealTypes,
            cuisine: cuisine,
            diet: diet,
            maxReadyMinutes: kind == .recipe ? cookMinutes.value : nil,
            maxCalories: kind == .recipe ? maxCalories.value : nil,
            details: detailsText.value,
            startDate: dates.first,
            endDate: dates.last
        )
    }

    private static func mealTypeValue(from key: String) -> String {
        switch key {
        case "recipes.filters.breakfast":
            return MealType.breakfast.rawValue
        case "recipes.filters.lunch":
            return MealType.lunch.rawValue
        case "recipes.filters.dinner":
            return MealType.dinner.rawValue
        case "recipes.filters.snack":
            return MealType.snacks.rawValue
        default:
            return L10n.tr(key)
        }
    }

    private static func defaultDates() -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<3).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// "Oct 24 - 26, 2026", "24.-26. Okt. 2026", "2026年10月24日～26日": the system knows each
    /// language's day, month and year order; only its long dash is swapped for a hyphen.
    private static func formatRange(start: Date, end: Date) -> String {
        let interval = DateIntervalFormatter()
        interval.locale = .appFormatting
        interval.dateTemplate = "yMMMd"
        return interval.string(from: start, to: end).withShortDashes
    }
}
