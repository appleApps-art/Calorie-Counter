import CoreData
import Foundation

protocol PantryRepositoryProtocol {
    func fetchAll() throws -> [PantryItem]
    func save(_ item: PantryItem) throws
    func delete(ids: [UUID]) throws
}

final class PantryRepository: PantryRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchAll() throws -> [PantryItem] {
        let context = coreDataStack.viewContext
        let request = CDPantryItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return try context.fetch(request).compactMap(PantryItemMapper.map)
    }

    func save(_ item: PantryItem) throws {
        let context = coreDataStack.viewContext
        let request = CDPantryItem.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
        let object = try context.fetch(request).first ?? CDPantryItem(context: context)
        PantryItemMapper.apply(item, to: object)
        try coreDataStack.saveContext()
    }

    func delete(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let context = coreDataStack.viewContext
        let request = CDPantryItem.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        try context.fetch(request).forEach { context.delete($0) }
        try coreDataStack.saveContext()
    }
}
