import CoreData

final class CoreDataStack {
    let persistentContainer: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    init(modelName: String = "CalorieCounter", inMemory: Bool = false) {
        persistentContainer = NSPersistentContainer(name: modelName)
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.shouldAddStoreAsynchronously = false
            persistentContainer.persistentStoreDescriptions = [description]
        } else {
            persistentContainer.persistentStoreDescriptions.forEach { description in
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
            }
        }
        var loadError: Error?
        let condition = NSCondition()
        var finished = false
        persistentContainer.loadPersistentStores { _, error in
            condition.lock()
            loadError = error
            finished = true
            condition.signal()
            condition.unlock()
        }
        if inMemory {
            condition.lock()
            while !finished {
                condition.wait()
            }
            condition.unlock()
        }
        if let loadError {
            assertionFailure("Unresolved Core Data error: \(loadError)")
        }
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func saveContext() throws {
        let context = viewContext
        guard context.hasChanges else { return }
        try context.save()
    }
}
