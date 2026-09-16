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
    let addedAlertVisible = Observable(false)
    let heroImage = Observable<UIImage?>(nil)
    let swappingRecipeIndex = Observable<Int?>(nil)

    var onBack: (() -> Void)?
    var onShare: ((String, UIImage?) -> Void)?
    var onEditWithBity: ((MealPlan) -> Void)?
    var onDeleted: (() -> Void)?
    var onOpenRecipe: ((Recipe) -> Void)?

    private var plan: MealPlan
    private let mealPlanRepository: MealPlanRepositoryProtocol
    private let searchRecipesUseCase: SearchRecipesUseCase
    private let fetchDailyDiaryUseCase: FetchDailyDiaryUseCase
    private let logFoodUseCase: LogFoodUseCase
    private var calorieGoal = UserGoals.default.calorieTarget

    init(
        plan: MealPlan,
        mealPlanRepository: MealPlanRepositoryProtocol,
        searchRecipesUseCase: SearchRecipesUseCase,
        fetchDailyDiaryUseCase: FetchDailyDiaryUseCase,
        logFoodUseCase: LogFoodUseCase
    ) {
        self.plan = plan
        self.mealPlanRepository = mealPlanRepository
        self.searchRecipesUseCase = searchRecipesUseCase
        self.fetchDailyDiaryUseCase = fetchDailyDiaryUseCase
        self.logFoodUseCase = logFoodUseCase
        publish()
    }

    func viewDidLoad() {
        calorieGoal = (try? fetchDailyDiaryUseCase.execute())?.goals.calorieTarget ?? UserGoals.default.calorieTarget
        publish()
        loadHeroImage()
    }

    func backTapped() {
        onBack?()
    }

    func shareTapped() {
        onShare?(shareText(), heroImage.value)
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
            let query = [slot.mealType.rawValue, slot.recipe.title]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let results = (try? await searchRecipesUseCase.generateRecipes(
                query: query,
                filters: .empty,
                number: 12
            )) ?? []
            let replacement = results.first { candidate in
                candidate.title.caseInsensitiveCompare(slot.recipe.title) != .orderedSame
                    && candidate.id != slot.recipe.id
                    && candidate.externalId != slot.recipe.externalId
            }
            if let replacement {
                var next = replacement
                next.id = UUID()
                plan.replacingRecipe(at: slot.recipeIndex, with: next)
                try? mealPlanRepository.save(plan)
                publish()
                loadHeroImage()
                swappedAlertVisible.value = true
            }
            swappingRecipeIndex.value = nil
        }
    }

    func recipeTapped(_ slot: MealPlanSlot) {
        onOpenRecipe?(slot.recipe)
    }

    func addToDiaryTapped() {
        let slots = selectedDay.value?.slots ?? []
        guard !slots.isEmpty else { return }
        do {
            try slots.forEach { slot in
                var draft = ProductDetailsMath.draft(from: slot.recipe, mealType: slot.mealType)
                draft.servings = 1
                _ = try logFoodUseCase.execute(draft.toFoodEntry())
            }
            addedAlertVisible.value = true
        } catch {
        }
    }

    func editWithBityTapped() {
        onEditWithBity?(plan)
    }

    func deleteTapped() {
        try? mealPlanRepository.delete(id: plan.id)
        onDeleted?()
    }

    func dismissSwappedAlert() {
        swappedAlertVisible.value = false
    }

    func dismissAddedAlert() {
        addedAlertVisible.value = false
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

    private func loadHeroImage() {
        guard let url = plan.imageURL else {
            heroImage.value = nil
            return
        }
        Task { @MainActor [weak self] in
            guard let image = await RemoteImageLoader.shared.fetch(url) else { return }
            guard self?.plan.imageURL == url else { return }
            self?.heroImage.value = image
        }
    }

    private func shareText() -> String {
        [plan.title, plan.subtitle, calorieShareBodyText.value]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func grouped(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }
}
