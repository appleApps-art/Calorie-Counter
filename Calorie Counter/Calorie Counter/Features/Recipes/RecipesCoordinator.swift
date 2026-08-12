import UIKit

final class RecipesCoordinator {
    private let navigationController: UINavigationController
    private let container: DIContainer
    private weak var recipeDetailViewModel: RecipeDetailViewModel?

    init(navigationController: UINavigationController, container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func start() -> UIViewController {
        let viewModel = RecipesViewModel(
            searchRecipesUseCase: container.searchRecipesUseCase,
            searchFoodProductsUseCase: container.searchFoodProductsUseCase,
            recipeRepository: container.recipeRepository
        )
        viewModel.onSelectRecipe = { [weak self] recipe in
            self?.showRecipeDetail(recipe)
        }
        viewModel.onSelectFoodProduct = { [weak self] product in
            self?.showFoodProductDetail(product)
        }
        return RecipesViewController(viewModel: viewModel)
    }

    private func showRecipeDetail(_ recipe: Recipe) {
        let viewModel = RecipeDetailViewModel(
            recipe: recipe,
            searchRecipesUseCase: container.searchRecipesUseCase,
            recipeRepository: container.recipeRepository,
            aiAssistantService: container.aiAssistantService,
            fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase
        )
        recipeDetailViewModel = viewModel
        viewModel.onRequestIngredientSwapChat = { [weak self] recipe, prefill in
            self?.presentIngredientSwapChat(recipe: recipe, prefill: prefill)
        }
        let viewController = RecipeDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showFoodProductDetail(_ product: FoodProduct) {
        let viewModel = FoodProductDetailViewModel(
            product: product,
            searchFoodProductsUseCase: container.searchFoodProductsUseCase,
            logFoodUseCase: container.logFoodUseCase
        )
        let viewController = FoodProductDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    private func presentIngredientSwapChat(recipe: Recipe, prefill: String) {
        let viewModel = AIAssistantViewModel(
            aiAssistantService: container.aiAssistantService,
            fetchDailyDiaryUseCase: container.fetchDailyDiaryUseCase,
            recipeContext: recipe,
            initialInput: prefill,
            buildAIAssistantUserContextUseCase: container.buildAIAssistantUserContextUseCase,
            parseAIAssistantActionsUseCase: container.parseAIAssistantActionsUseCase,
            confirmAIAssistantActionUseCase: container.confirmAIAssistantActionUseCase,
            persistChatHistoryUseCase: container.persistChatHistoryUseCase
        )
        viewModel.onRecipeIngredientSwapProposed = { [weak self] proposal in
            self?.recipeDetailViewModel?.applyIngredientSwapProposal(proposal)
            self?.navigationController.dismiss(animated: true)
        }
        let chat = AIAssistantViewController(viewModel: viewModel)
        let nav = UINavigationController(rootViewController: chat)
        chat.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in
                self?.navigationController.dismiss(animated: true)
            }
        )
        navigationController.present(nav, animated: true)
    }
}
