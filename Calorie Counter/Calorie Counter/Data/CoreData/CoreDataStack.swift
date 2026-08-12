import CoreData

final class CoreDataStack {
    let persistentContainer: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    init(modelName: String = "CalorieCounter") {
        persistentContainer = NSPersistentContainer(name: modelName)
        persistentContainer.persistentStoreDescriptions.forEach { description in
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        persistentContainer.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Unresolved Core Data error: \(error)")
            }
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
