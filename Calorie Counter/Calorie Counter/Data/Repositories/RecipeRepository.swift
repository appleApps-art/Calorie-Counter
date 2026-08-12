import CoreData
import Foundation

protocol RecipeRepositoryProtocol {
    func fetchSaved() throws -> [Recipe]
    func fetchSaved(externalId: String) throws -> Recipe?
    func save(_ recipe: Recipe) throws
    func delete(id: UUID) throws
    func isSaved(externalId: String) throws -> Bool
}

final class RecipeRepository: RecipeRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchSaved() throws -> [Recipe] {
        let context = coreDataStack.viewContext
        let request = CDSavedRecipe.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return try context.fetch(request).compactMap(SavedRecipeMapper.map)
    }

    func fetchSaved(externalId: String) throws -> Recipe? {
        let context = coreDataStack.viewContext
        let request = CDSavedRecipe.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "externalId == %@", externalId)
        return try context.fetch(request).first.flatMap(SavedRecipeMapper.map)
    }

    func save(_ recipe: Recipe) throws {
        let context = coreDataStack.viewContext
        let request = CDSavedRecipe.fetchRequest()
        request.fetchLimit = 1
        if let externalId = recipe.externalId, !externalId.isEmpty {
            request.predicate = NSPredicate(format: "externalId == %@", externalId)
        } else {
            request.predicate = NSPredicate(format: "id == %@", recipe.id as CVarArg)
        }
        let object = try context.fetch(request).first ?? CDSavedRecipe(context: context)
        var toSave = recipe
        if object.id == nil {
            toSave.id = recipe.id
        } else if let existingId = object.id {
            toSave.id = existingId
        }
        SavedRecipeMapper.apply(toSave, to: object)
        try coreDataStack.saveContext()
    }

    func delete(id: UUID) throws {
        let context = coreDataStack.viewContext
        let request = CDSavedRecipe.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let object = try context.fetch(request).first {
            context.delete(object)
            try coreDataStack.saveContext()
        }
    }

    func isSaved(externalId: String) throws -> Bool {
        let context = coreDataStack.viewContext
        let request = CDSavedRecipe.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "externalId == %@", externalId)
        return try context.fetch(request).first != nil
    }
}
