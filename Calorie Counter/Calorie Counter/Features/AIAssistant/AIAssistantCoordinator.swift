import UIKit

final class AIAssistantCoordinator {
    private let navigationController: UINavigationController
    private let container: DIContainer
    private weak var persistentChat: AIAssistantViewController?
    private lazy var foodLoggingCoordinator = FoodLoggingCoordinator(
        navigationController: navigationController,
        container: container
    )

    init(navigationController: UINavigationController, container: DIContainer) {
        self.navigationController = navigationController
        self.container = container
    }

    func makeRoot() -> UIViewController {
        if container.updateAppSettingsUseCase.current().hasSeenAIIntro {
            return makeChatViewController()
        }
        return makeIntro()
    }

    func showChat(recipe: Recipe? = nil, initialInput: String? = nil) {
        let chat = makeChatViewController(recipe: recipe, initialInput: initialInput, isTabRoot: false)
        navigationController.pushViewController(chat, animated: true)
    }

    private func makeIntro() -> UIViewController {
        let intro = AIIntroViewController()
        intro.onStart = { [weak self] in
            Analytics.tracker.track(.aiIntroCompleted)
            self?.completeIntro()
        }
        return intro
    }

    private func completeIntro() {
        var settings = container.updateAppSettingsUseCase.current()
        settings.hasSeenAIIntro = true
        container.updateAppSettingsUseCase.execute(settings)
        let chat = makeChatViewController()
        navigationController.setViewControllers([chat], animated: true)
    }

    private func makeChatViewController(
        recipe: Recipe? = nil,
        initialInput: String? = nil,
        isTabRoot: Bool = true
    ) -> AIAssistantViewController {
        let isPersistentSession = isTabRoot && recipe == nil
        let viewModel = container.makeAIAssistantViewModel(
            recipeContext: recipe,
            initialInput: initialInput,
            isPersistentSession: isPersistentSession
        )
        let chat = AIAssistantViewController(viewModel: viewModel)
        chat.showsBackButton = !isTabRoot
        chat.showsHistoryButton = isPersistentSession
        chat.showsNewChatButton = isPersistentSession
        foodLoggingCoordinator.attachRecipeDetailsOpening(to: chat)
        if isPersistentSession {
            persistentChat = chat
            chat.onHistory = { [weak self] in
                self?.showHistory()
            }
        }
        return chat
    }

    private func showHistory() {
        let viewModel = ChatHistoryViewModel(
            persistChatHistoryUseCase: container.persistChatHistoryUseCase,
            voiceRecorder: container.voiceFoodAudioRecorder,
            transcribeFoodVoiceUseCase: container.transcribeFoodVoiceUseCase
        )
        let history = ChatHistoryViewController(viewModel: viewModel)
        history.onSelectConversation = { [weak self] conversationID in
            self?.persistentChat?.restorePersistedConversation(id: conversationID)
            self?.navigationController.popViewController(animated: true)
        }
        navigationController.pushViewController(history, animated: true)
    }
}
