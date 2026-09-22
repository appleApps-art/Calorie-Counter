import Foundation
import UIKit

final class MealPlanPreviewViewModel {
    let navTitle = Observable(L10n.tr("recipes.create.mealPlan"))
    let nameText = Observable("")
    let subtitleText = Observable("")
    let calorieShareTitleText = Observable(L10n.tr("recipes.details.calorieShareTitle"))
    let calorieShareBodyText = Observable("")
    let calorieShareProgress = Observable(CGFloat(0))
    let calorieSharePercentText = Observable("")
    let days = Observable<[MealPlanDay]>([])
    let selectedDayIndex = Observable(0)
    let selectedDay = Observable<MealPlanDay?>(nil)
    let swappedAlertVisible = Observable(false)
    let swappedAlertTitle = Observable(L10n.tr("recipes.mealPlan.swapped"))
    let addedAlertVisible = Observable(false)
    let heroImage = Observable<UIImage?>(nil)
    let swappingRecipeIndex = Observable<Int?>(nil)

    var onBack: (() -> Void)?
    var onShare: ((String, UIImage?) -> Void)?
    var onEditWithBity: ((MealPlan) -> Void)?
    var onDeleted: (() -> Void)?
    var onOpenRecipe: ((Recipe) -> Void)?
    var onConfirmDelete: (() -> Void)?
    var onSwapOptions: ((MealPlanSlot, [Recipe]) -> Void)?
    var onPickDiaryDates: ((MealPlan) -> Void)?

    private var plan: MealPlan
    /// A plan opened straight after it was made logs its day right away; one opened from the list
    /// asks which days it should cover first, as the design shows.
    private let isFreshlyCreated: Bool
    private let mealPlanRepository: MealPlanRepositoryProtocol
    private let searchRecipesUseCase: SearchRecipesUseCase
    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let logFoodUseCase: LogFoodUseCase
    private var calorieGoal = UserGoals.default.calorieTarget

    private let foodImageURL: (String) -> URL?

    init(
        plan: MealPlan,
        mealPlanRepository: MealPlanRepositoryProtocol,
        searchRecipesUseCase: SearchRecipesUseCase,
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        logFoodUseCase: LogFoodUseCase,
        isFreshlyCreated: Bool = false,
        foodImageURL: @escaping (String) -> URL? = { AIAssistantAPIConfiguration.production.foodImageURL(name: $0) }
    ) {
        self.plan = plan
        self.isFreshlyCreated = isFreshlyCreated
        self.foodImageURL = foodImageURL
        self.mealPlanRepository = mealPlanRepository
        self.searchRecipesUseCase = searchRecipesUseCase
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.logFoodUseCase = logFoodUseCase
        publish()
    }

    func viewDidLoad() {
        calorieGoal = (try? fetchDailyDiaryUseCase.execute())?.goals.calorieTarget ?? UserGoals.default.calorieTarget
        publish()
    }

    func backTapped() {
        onBack?()
    }

    func shareTapped() {
        onShare?(shareText(), heroImage.value)
    }

    /// The whole plan, day by day, so what arrives is the cooking rather than a headline.
    func shareText() -> String {
        var lines = [plan.title, plan.subtitle, calorieShareBodyText.value].filter { !$0.isEmpty }
        plan.days().forEach { day in
            lines.append("")
            lines.append(L10n.format("recipes.mealPlan.day", day.index + 1))
            day.slots.forEach { slot in
                let calories = slot.recipe.calories.map { L10n.format("photo.result.kcalValue", Int($0.rounded())) }
                lines.append(
                    [slot.mealType.localizedTitle, slot.recipe.title, calories]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                )
            }
        }
        return lines.joined(separator: "\n")
    }

    func selectDay(_ index: Int) {
        let all = plan.days()
        guard all.indices.contains(index) else { return }
        selectedDayIndex.value = index
        selectedDay.value = all[index]
    }

    func swapTapped(_ slot: MealPlanSlot) {
        guard swappingRecipeIndex.value == nil else { return }
        swappingRecipeIndex.value = slot.recipeIndex
        Task { @MainActor in
            let taken = Set(plan.recipes.map(MealPlanPacker.recipeKey))
            let options = await searchRecipesUseCase.mealPlanReplacements(
                meal: slot.mealType,
                calories: slot.recipe.calories,
                excluding: taken
            )
            swappingRecipeIndex.value = nil
            guard !options.isEmpty else {
                // Silence used to look like the arrow was broken.
                swappedAlertTitle.value = L10n.tr("recipes.mealPlan.swapUnavailable")
                swappedAlertVisible.value = true
                return
            }
            // The design lets the user choose the replacement rather than taking the first one.
            onSwapOptions?(slot, options)
        }
    }

    func applySwap(_ slot: MealPlanSlot, with recipe: Recipe) {
        var next = recipe
        next.id = UUID()
        plan.replacingRecipe(at: slot.recipeIndex, with: next)
        try? mealPlanRepository.save(plan)
        publish()
        swappedAlertTitle.value = L10n.tr("recipes.mealPlan.swapped")
        swappedAlertVisible.value = true
    }

    /// Bity's answer to "swap the porridge": find the slot it means and put its dish there.
    @discardableResult
    func applySwapProposal(_ proposal: MealPlanSwapProposal) -> Bool {
        guard let slot = slot(matching: proposal) else { return false }
        applySwap(slot, with: MealPlanSwapProposalMapper.recipe(
            from: proposal,
            replacing: slot.recipe,
            imageURL: foodImageURL(proposal.replacementTitle)
        ))
        return true
    }

    private func slot(matching proposal: MealPlanSwapProposal) -> MealPlanSlot? {
        let days = plan.days()
        var candidates = days.flatMap(\.slots)
        if let number = proposal.dayNumber, let day = days.first(where: { $0.index + 1 == number }) {
            candidates = day.slots
        }
        if let title = proposal.currentTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
           let match = candidates.first(where: { $0.recipe.title.localizedCaseInsensitiveContains(title) })
            ?? candidates.first(where: { title.localizedCaseInsensitiveContains($0.recipe.title) }) {
            return match
        }
        if let mealType = proposal.mealType, let match = candidates.first(where: { $0.mealType == mealType }) {
            return match
        }
        // Without a day or a name there is nothing to point at, so the plan is left alone.
        return proposal.dayNumber != nil ? candidates.first : nil
    }

    func recipeTapped(_ slot: MealPlanSlot) {
        onOpenRecipe?(slot.recipe)
    }

    func addToDiaryTapped() {
        guard isFreshlyCreated else {
            onPickDiaryDates?(plan)
            return
        }
        let slots = selectedDay.value?.slots ?? []
        guard !slots.isEmpty else { return }
        log(slots, on: Date())
        addedAlertVisible.value = true
    }

    /// Each day of the plan lands on the matching chosen date.
    func addPlan(on dates: [Date]) {
        let days = plan.days()
        let ordered = dates.sorted()
        guard !days.isEmpty, !ordered.isEmpty else { return }
        days.enumerated().forEach { index, day in
            guard index < ordered.count else { return }
            log(day.slots, on: ordered[index])
        }
        addedAlertVisible.value = true
    }

    private func log(_ slots: [MealPlanSlot], on date: Date) {
        slots.forEach { slot in
            var draft = ProductDetailsMath.draft(from: slot.recipe, mealType: slot.mealType, date: date)
            draft.servings = 1
            _ = try? logFoodUseCase.execute(draft.toFoodEntry())
        }
    }

    func editWithBityTapped() {
        onEditWithBity?(plan)
    }

    func deleteTapped() {
        onConfirmDelete?()
    }

    func deleteConfirmed() {
        try? mealPlanRepository.delete(id: plan.id)
        onDeleted?()
    }

    func dismissSwappedAlert() {
        swappedAlertVisible.value = false
    }

    func dismissAddedAlert() {
        addedAlertVisible.value = false
        // The day is in the diary; there is nothing left to do on this screen.
        onBack?()
    }

    func addedAlertTitle() -> String {
        var seen = Set<String>()
        var unique: [String] = []
        (selectedDay.value?.slots ?? []).map(\.mealType.localizedTitle).forEach { title in
            if seen.insert(title).inserted {
                unique.append(title)
            }
        }
        let label = unique.joined(separator: ", ")
        return L10n.format("product.entry.addedTo", label)
    }

    private func publish() {
        nameText.value = plan.title
        subtitleText.value = plan.subtitle
        let all = plan.days()
        days.value = all
        let index = min(max(selectedDayIndex.value, 0), max(all.count - 1, 0))
        selectedDayIndex.value = index
        selectedDay.value = all.indices.contains(index) ? all[index] : nil
        let dailyCalories = averageDailyCalories()
        let percent = calorieGoal > 0 ? min(100, max(0, (dailyCalories / calorieGoal) * 100)) : 0
        calorieShareProgress.value = CGFloat(percent / 100)
        calorieSharePercentText.value = "\(Int(percent.rounded()))%"
        calorieShareBodyText.value = L10n.format(
            "recipes.mealPlan.calorieShareBody",
            Self.grouped(dailyCalories),
            Self.grouped(calorieGoal)
        )
    }

    private func averageDailyCalories() -> Double {
        let all = plan.days()
        let totals = all.map { day in
            day.slots.reduce(0) { $0 + ($1.recipe.calories ?? 0) }
        }
        guard !totals.isEmpty else { return 0 }
        return totals.reduce(0, +) / Double(totals.count)
    }

    /// The cover carries the plan's name; every plan would otherwise show the same photo.
    func renderCover(size: CGSize, traits: UITraitCollection) {
        heroImage.value = MealPlanCover.image(title: plan.title, size: size, traits: traits)
    }

    private static func grouped(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .appFormatting
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }
}
