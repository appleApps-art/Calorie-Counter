import CoreData
import XCTest
@testable import Calorie_Counter

@MainActor
final class ChatConversationPersistenceTests: XCTestCase {
    func testConversationIdentifiersRoundTripAlongsideLegacyMessages() throws {
        let stack = CoreDataStack(inMemory: true)
        let repository = ChatHistoryRepository(coreDataStack: stack)
        let firstConversationID = UUID()
        let secondConversationID = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let messages: [Calorie_Counter.ChatHistoryMessage] = [
            .init(id: UUID(), role: "user", content: "Стара розмова", createdAt: start, conversationID: nil),
            .init(
                id: UUID(), role: "user", content: "Ідеї страв", createdAt: start.addingTimeInterval(1),
                conversationID: firstConversationID
            ),
            .init(
                id: UUID(), role: "assistant", content: "Ідея для вечері", createdAt: start.addingTimeInterval(2),
                conversationID: firstConversationID
            ),
            .init(
                id: UUID(), role: "user", content: "Заміна продуктів", createdAt: start.addingTimeInterval(3),
                conversationID: secondConversationID
            ),
        ]
        for message in messages {
            try repository.append(message)
        }
        stack.viewContext.reset()
        XCTAssertEqual(try repository.fetchAll(), messages)
        XCTAssertEqual(try repository.fetchRecent(limit: 2), Array(messages.suffix(2)))

        try repository.replaceAll(messages)
        stack.viewContext.reset()
        XCTAssertEqual(try repository.fetchAll(), messages, "Rewriting history must preserve conversation membership")
    }

    func testBundledV1SQLiteHistoryMigratesToCurrentModelWithoutLosingMessages() throws {
        let bundleURL = try XCTUnwrap(Bundle(for: CoreDataStack.self)
            .url(forResource: "CalorieCounter", withExtension: "momd"))
        let legacyModel = try XCTUnwrap(NSManagedObjectModel(
            contentsOf: bundleURL.appendingPathComponent("CalorieCounter.mom")
        ))
        let currentModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: bundleURL))
        let legacyEntity = try XCTUnwrap(legacyModel.entitiesByName["CDChatMessage"])
        XCTAssertNil(legacyEntity.attributesByName["conversationID"], "The deployed source model must remain bundled unchanged")
        let conversationAttribute = try XCTUnwrap(currentModel.entitiesByName["CDChatMessage"]?
            .attributesByName["conversationID"])
        XCTAssertEqual(conversationAttribute.attributeType, .UUIDAttributeType)
        XCTAssertTrue(conversationAttribute.isOptional)

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("bity-chat-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let storeURL = folder.appendingPathComponent("CalorieCounter.sqlite")
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let legacyMessages: [Calorie_Counter.ChatHistoryMessage] = [
            .init(id: UUID(), role: "user", content: "Страви на весь день", createdAt: start),
            .init(
                id: UUID(), role: "recipe",
                content: "{\"mealType\":\"breakfast\",\"option\":{\"title\":\"Вівсянка\"}}",
                createdAt: start.addingTimeInterval(1)
            ),
        ]

        let legacyCoordinator = NSPersistentStoreCoordinator(managedObjectModel: legacyModel)
        let legacyStore = try legacyCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL
        )
        let legacyContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        legacyContext.persistentStoreCoordinator = legacyCoordinator
        for message in legacyMessages {
            // Explicit NSManagedObject avoids binding the generated current
            // CDChatMessage subclass to the legacy model during the migration.
            let row = NSManagedObject(entity: legacyEntity, insertInto: legacyContext)
            row.setValue(message.id, forKey: "id")
            row.setValue(message.role, forKey: "role")
            row.setValue(message.content, forKey: "content")
            row.setValue(message.createdAt, forKey: "createdAt")
        }
        try legacyContext.save()
        legacyContext.reset()
        try legacyCoordinator.remove(legacyStore)

        let currentCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
        let migratedStore = try currentCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
            ]
        )
        defer { try? currentCoordinator.remove(migratedStore) }
        let migratedContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        migratedContext.persistentStoreCoordinator = currentCoordinator
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDChatMessage")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let rows = try migratedContext.fetch(request)
        XCTAssertEqual(rows.count, legacyMessages.count)
        for (row, original) in zip(rows, legacyMessages) {
            XCTAssertEqual(row.value(forKey: "id") as? UUID, original.id)
            XCTAssertEqual(row.value(forKey: "role") as? String, original.role)
            XCTAssertEqual(row.value(forKey: "content") as? String, original.content)
            XCTAssertEqual(row.value(forKey: "createdAt") as? Date, original.createdAt)
            XCTAssertNil(row.value(forKey: "conversationID"), "Existing history remains in the legacy conversation")
        }

        let currentEntity = try XCTUnwrap(currentModel.entitiesByName["CDChatMessage"])
        let newConversationID = UUID()
        let newMessageID = UUID()
        let newRow = NSManagedObject(entity: currentEntity, insertInto: migratedContext)
        newRow.setValue(newMessageID, forKey: "id")
        newRow.setValue("user", forKey: "role")
        newRow.setValue("Нова розмова", forKey: "content")
        newRow.setValue(start.addingTimeInterval(2), forKey: "createdAt")
        newRow.setValue(newConversationID, forKey: "conversationID")
        try migratedContext.save()
        migratedContext.reset()
        let savedRows = try migratedContext.fetch(request)
        XCTAssertEqual(savedRows.count, legacyMessages.count + 1)
        XCTAssertEqual(savedRows.last?.value(forKey: "id") as? UUID, newMessageID)
        XCTAssertEqual(savedRows.last?.value(forKey: "conversationID") as? UUID, newConversationID)
    }
}
