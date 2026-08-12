import CoreData
import Foundation

protocol UserGoalsRepositoryProtocol {
    func fetchGoals() throws -> UserGoals
    func save(_ goals: UserGoals) throws
}

final class UserGoalsRepository: UserGoalsRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchGoals() throws -> UserGoals {
        let context = coreDataStack.viewContext
        let request = CDUserGoals.fetchRequest()
        request.fetchLimit = 1

        if let object = try context.fetch(request).first {
            return UserGoalsMapper.map(object)
        }

        let object = CDUserGoals(context: context)
        UserGoalsMapper.apply(.default, to: object)
        try coreDataStack.saveContext()
        return .default
    }

    func save(_ goals: UserGoals) throws {
        let context = coreDataStack.viewContext
        let request = CDUserGoals.fetchRequest()
        request.fetchLimit = 1
        let object = try context.fetch(request).first ?? CDUserGoals(context: context)
        UserGoalsMapper.apply(goals, to: object)
        try coreDataStack.saveContext()
    }
}
