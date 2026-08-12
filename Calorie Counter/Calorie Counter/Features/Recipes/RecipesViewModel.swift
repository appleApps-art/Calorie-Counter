import Foundation

enum RecipesSearchMode: Int, Equatable {
    case recipes = 0
    case foods = 1
}

struct RecipesListItem: Equatable {
    enum Kind: Equatable {
        case recipe(Recipe)
        case food(FoodProduct)
    }

    let title: String
    let subtitle: String
    let kind: Kind
}

final class RecipesViewModel {
    let titleText = Observable(L10n.tr("recipes.title"))
    let statusText = Observable(L10n.tr("recipes.searchHint"))
    let resultsText = Observable("")
    let isLoading = Observable(false)
    let searchMode = Observable(RecipesSearchMode.recipes)
    let items = Observable<[RecipesListItem]>([])

    var onSelectRecipe: ((Recipe) -> Void)?
    var onSelectFoodProduct: ((FoodProduct) -> Void)?

    private let searchRecipesUseCase: SearchRecipesUseCase
    private let searchFoodProductsUseCase: SearchFoodProductsUseCase
    private let recipeRepository: RecipeRepositoryProtocol
    private var searchQuery = ""
    private var cachedRecipes: [Recipe] = []
    private var cachedFoods: [FoodProduct] = []

    init(
        searchRecipesUseCase: SearchRecipesUseCase,
        searchFoodProductsUseCase: SearchFoodProductsUseCase,
        recipeRepository: RecipeRepositoryProtocol
    ) {
        self.searchRecipesUseCase = searchRecipesUseCase
        self.searchFoodProductsUseCase = searchFoodProductsUseCase
        self.recipeRepository = recipeRepository
    }

    func viewDidLoad() {
        loadSavedRecipes()
    }

    func updateSearchQuery(_ text: String) {
        searchQuery = text
    }

    func searchModeChanged(_ index: Int) {
        searchMode.value = RecipesSearchMode(rawValue: index) ?? .recipes
        titleText.value = searchMode.value == .recipes ? L10n.tr("recipes.title") : L10n.tr("recipes.foods")
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if searchMode.value == .recipes {
                loadSavedRecipes()
            } else {
                items.value = []
                resultsText.value = L10n.tr("recipes.searchFoodsHint")
                statusText.value = L10n.tr("recipes.foods")
            }
        } else {
            searchTapped()
        }
    }

    func searchTapped() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            statusText.value = L10n.tr("recipes.enterQuery")
            return
        }
        isLoading.value = true
        statusText.value = L10n.tr("recipes.searching")

        Task { @MainActor in
            do {
                switch searchMode.value {
                case .recipes:
                    let recipes = try await searchRecipesUseCase.execute(query: query)
                    cachedRecipes = recipes
                    items.value = recipes.map {
                        RecipesListItem(
                            title: $0.title,
                            subtitle: nutritionSubtitle(calories: $0.calories, minutes: $0.readyInMinutes),
                            kind: .recipe($0)
                        )
                    }
                    resultsText.value = recipes.isEmpty ? L10n.tr("recipes.noneFound") : L10n.format("recipes.countFormat", recipes.count)
                case .foods:
                    let foods = try await searchFoodProductsUseCase.execute(query: query)
                    cachedFoods = foods
                    items.value = foods.map {
                        RecipesListItem(
                            title: $0.name,
                            subtitle: foodSubtitle($0),
                            kind: .food($0)
                        )
                    }
                    resultsText.value = foods.isEmpty ? L10n.tr("recipes.foodsNone") : L10n.format("recipes.foodsCount", foods.count)
                }
                statusText.value = L10n.tr("common.done")
            } catch {
                statusText.value = error.localizedDescription
                items.value = []
                resultsText.value = L10n.tr("recipes.searchFailed")
            }
            isLoading.value = false
        }
    }

    func selectItem(at index: Int) {
        guard items.value.indices.contains(index) else { return }
        switch items.value[index].kind {
        case .recipe(let recipe):
            onSelectRecipe?(recipe)
        case .food(let product):
            onSelectFoodProduct?(product)
        }
    }

    private func loadSavedRecipes() {
        do {
            let saved = try recipeRepository.fetchSaved()
            cachedRecipes = saved
            items.value = saved.map {
                RecipesListItem(
                    title: $0.title,
                    subtitle: L10n.format("recipes.savedPrefix", nutritionSubtitle(calories: $0.calories, minutes: $0.readyInMinutes)),
                    kind: .recipe($0)
                )
            }
            resultsText.value = saved.isEmpty ? L10n.tr("recipes.savedEmpty") : L10n.format("recipes.savedCount", saved.count)
            statusText.value = L10n.tr("recipes.savedStatus")
        } catch {
            statusText.value = error.localizedDescription
        }
    }

    private func nutritionSubtitle(calories: Double?, minutes: Int?) -> String {
        var parts: [String] = []
        if let calories {
            parts.append(L10n.format("recipes.kcal", Int(calories.rounded())))
        }
        if let minutes {
            parts.append(L10n.format("recipes.min", minutes))
        }
        return parts.isEmpty ? L10n.tr("recipes.generic") : parts.joined(separator: " · ")
    }

    private func foodSubtitle(_ product: FoodProduct) -> String {
        var parts = [product.kind == .ingredient ? L10n.tr("recipes.ingredient") : L10n.tr("recipes.product")]
        if let brand = product.brand, !brand.isEmpty {
            parts.append(brand)
        }
        if let calories = product.calories {
            parts.append(L10n.format("recipes.kcal", Int(calories.rounded())))
        }
        return parts.joined(separator: " · ")
    }
}
