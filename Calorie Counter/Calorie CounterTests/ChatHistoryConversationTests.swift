import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class ChatHistoryConversationTests: XCTestCase {
    func testHistoryHasOneRowPerConversationOrderedByLastMessage() throws {
        let first = UUID(), second = UUID()
        let repository = MemoryChatHistory([
            message("user", "Ідеї страв", 0, first),
            message("assistant", "Що любите?", 1, first),
            message("user", "Порадь сніданок\nбез молока", 2, first),
            message("user", "Окрема розмова", 3, second),
            message("assistant", "Остання\n\nвідповідь", 4, first)
        ])
        let vm = makeViewModel(repository)
        let rows = vm.sections.value.flatMap(\.rows)
        XCTAssertEqual(rows.map(\.id), [first, second])
        XCTAssertEqual(rows.first?.title, "Порадь сніданок без молока")
        XCTAssertEqual(rows.first?.subtitle, "Остання відповідь")
        XCTAssertEqual(rows.first?.date, repository.messages.last?.createdAt)
        XCTAssertEqual(rows.last?.subtitle, "")
    }

    func testLegacyHistoryStaysInOneArchiveWithoutChangingMessages() throws {
        let repository = MemoryChatHistory([
            message("user", "Старий запит", 0, nil),
            message("assistant", "Стара відповідь", 1, nil),
            message("user", "Ще один старий запит", 2, nil),
            message("user", "Продовження архіву", 3, ChatConversation.legacyID),
            message("user", "Новий чат", 4, UUID())
        ])
        let original = repository.messages
        let vm = makeViewModel(repository)
        let rows = vm.sections.value.flatMap(\.rows)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.last?.id, ChatConversation.legacyID)
        XCTAssertEqual(rows.last?.title, L10n.tr("ai.history.legacyTitle"))
        XCTAssertEqual(repository.messages, original)
        let persist = PersistChatHistoryUseCase(chatHistoryRepository: repository)
        XCTAssertEqual(try persist.loadConversation(id: ChatConversation.legacyID), Array(original.prefix(4)))
    }

    func testSearchFindsEarlierMessagesAndCardsInsideConversation() throws {
        let id = UUID()
        let option = MealSuggestionOption(
            title: "Вівсянка з чорницею", summary: "", calories: 350,
            protein: 12, carbs: 50, fats: 10, ingredients: []
        )
        let encoded = try XCTUnwrap(ChatHistoryVisualCodec.encode(.init(kind: .recipe(option, mealType: .breakfast))))
        let repository = MemoryChatHistory([
            message("user", "План на день", 0, id),
            message("assistant", "Можна без лактози", 1, id),
            message(encoded.role, encoded.content, 2, id),
            message("user", "Дякую", 3, id),
            message("assistant", "Будь ласка", 4, id),
            message("user", "Інша тема", 5, UUID())
        ])
        let vm = makeViewModel(repository)
        for query in ["ЛАКТОЗИ", "чорницею", "Дякую"] {
            vm.updateSearch(query)
            XCTAssertEqual(vm.sections.value.flatMap(\.rows).map(\.id), [id])
        }
        vm.updateSearch("відсутній текст")
        XCTAssertTrue(vm.sections.value.isEmpty)
        vm.clearSearch()
        XCTAssertEqual(vm.sections.value.flatMap(\.rows).count, 2)
    }

    func testCategoryFilterIncludesEveryTopicWithoutLeakingBetweenChats() {
        let mixed = UUID(), nutrition = UUID()
        let repository = MemoryChatHistory([
            message("user", L10n.tr(AIChatCategory.meals.titleKey), 0, mixed),
            message("user", L10n.tr(AIChatCategory.swaps.titleKey), 1, mixed),
            message("user", L10n.tr(AIChatCategory.nutrition.titleKey), 2, nutrition),
            message("user", "Невідома категорія", 3, UUID())
        ])
        let vm = makeViewModel(repository)
        for category in [AIChatCategory.meals, .swaps] {
            vm.selectFilter(.category(category))
            XCTAssertEqual(vm.sections.value.flatMap(\.rows).map(\.id), [mixed])
        }
        vm.selectFilter(.category(.nutrition))
        XCTAssertEqual(vm.sections.value.flatMap(\.rows).map(\.id), [nutrition])
        vm.selectFilter(.all)
        XCTAssertEqual(vm.sections.value.flatMap(\.rows).count, 3)
    }

    func testReplacementKeepsOriginalConversationAndDateAndCannotResurrectDeletedHistory() throws {
        let id = UUID()
        let original = message("assistant", "Початкова картка", 0, id)
        let repository = MemoryChatHistory([original])
        let persist = PersistChatHistoryUseCase(chatHistoryRepository: repository)
        let update = ChatHistoryMessage(id: original.id, role: "assistant", content: "Оновлена картка", createdAt: Date())
        try persist.replace(update)
        XCTAssertEqual(repository.messages.first?.conversationID, id)
        XCTAssertEqual(repository.messages.first?.createdAt, original.createdAt)
        XCTAssertEqual(repository.messages.first?.content, update.content)
        try persist.deleteAll()
        try persist.replace(update)
        XCTAssertTrue(repository.messages.isEmpty, "Late card enrichment must not recreate deleted messages")
    }

    func testEmptyChatsAreHiddenAndClearAllRemovesConversationRows() {
        let repository = MemoryChatHistory([message("assistant", "Welcome", 0, UUID())])
        let vm = makeViewModel(repository)
        XCTAssertTrue(vm.sections.value.isEmpty)
        repository.messages.append(message("user", "Перший запит", 1, UUID()))
        vm.reload()
        XCTAssertEqual(vm.sections.value.flatMap(\.rows).count, 1)
        vm.deleteAll()
        XCTAssertTrue(vm.sections.value.isEmpty)
        XCTAssertTrue(repository.messages.isEmpty)
    }

    func testTappingEachHistoryRowReturnsItsConversationID() throws {
        let first = UUID(), second = UUID()
        let vm = makeViewModel(MemoryChatHistory([
            message("user", "Перша розмова", 0, first),
            message("user", "Друга розмова", 1, second)
        ]))
        let controller = ChatHistoryViewController(viewModel: vm)
        controller.loadViewIfNeeded()
        let table = try XCTUnwrap(controller.value(forKey: "tableView") as? UITableView)
        let cell = controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        let rows = descendants(of: cell).compactMap { $0 as? ChatHistoryRowView }
        XCTAssertEqual(rows.count, 2)
        var selected: [UUID] = []
        controller.onSelectConversation = { selected.append($0) }
        rows.forEach { $0.onTap?() }
        XCTAssertEqual(selected, [second, first])
    }

    func testNoSearchResultsKeepsClearHistoryAvailable() throws {
        let vm = makeViewModel(MemoryChatHistory([message("user", "Обід", 0, UUID())]))
        let controller = ChatHistoryViewController(viewModel: vm)
        controller.loadViewIfNeeded()
        vm.updateSearch("немає збігів")
        XCTAssertTrue(vm.sections.value.isEmpty)
        XCTAssertTrue(vm.hasHistory)
        let clear = try XCTUnwrap(controller.value(forKey: "clearAllButton") as? UIButton)
        XCTAssertFalse(clear.isHidden)
        vm.deleteAll()
        XCTAssertFalse(vm.hasHistory)
        XCTAssertTrue(clear.isHidden)
        XCTAssertEqual(vm.searchText.value, "")
        XCTAssertEqual(vm.selectedFilter.value, .all)
    }

    func testFailedClearKeepsHistoryAndReportsFailure() {
        let repository = MemoryChatHistory([message("user", "Обід", 0, UUID())])
        let vm = makeViewModel(repository)
        let rows = vm.sections.value
        repository.failWrites = true
        vm.deleteAll()
        XCTAssertEqual(vm.sections.value, rows)
        XCTAssertTrue(vm.hasHistory)
        XCTAssertEqual(vm.errorMessage.value, L10n.tr("ai.history.clearError"))
    }

    private func makeViewModel(_ repository: MemoryChatHistory) -> ChatHistoryViewModel {
        ChatHistoryViewModel(persistChatHistoryUseCase: PersistChatHistoryUseCase(chatHistoryRepository: repository))
    }

    func testHistoryHidesTabBarWithoutQARouteAndRestoresRootOnBack() {
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        let history = ChatHistoryViewController(viewModel: makeViewModel(MemoryChatHistory([])))
        navigation.pushViewController(history, animated: false)
        XCTAssertTrue(navigation.topViewController?.hidesBottomBarWhenPushed == true)
        navigation.popViewController(animated: false)
        XCTAssertTrue(navigation.topViewController === root)
        XCTAssertFalse(root.hidesBottomBarWhenPushed)
    }

    private func message(_ role: String, _ text: String, _ second: TimeInterval, _ conversationID: UUID?) -> ChatHistoryMessage {
        ChatHistoryMessage(
            id: UUID(), role: role, content: text,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000 + second), conversationID: conversationID
        )
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}

private final class MemoryChatHistory: ChatHistoryRepositoryProtocol {
    var messages: [ChatHistoryMessage]
    var failWrites = false
    init(_ messages: [ChatHistoryMessage]) { self.messages = messages }
    func fetchAll() throws -> [ChatHistoryMessage] { messages.sorted { $0.createdAt < $1.createdAt } }
    func fetchRecent(limit: Int) throws -> [ChatHistoryMessage] { Array(try fetchAll().suffix(limit)) }
    func append(_ message: ChatHistoryMessage) throws { messages.append(message) }
    func replaceAll(_ messages: [ChatHistoryMessage]) throws {
        if failWrites { throw NSError(domain: "test", code: 1) }
        self.messages = messages
    }
}
