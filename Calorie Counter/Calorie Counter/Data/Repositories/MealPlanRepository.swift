import CoreData
import Foundation

protocol MealPlanRepositoryProtocol {
    func fetchAll() throws -> [MealPlan]
    func save(_ plan: MealPlan) throws
    func delete(id: UUID) throws
}

final class MealPlanRepository: MealPlanRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchAll() throws -> [MealPlan] {
        let context = coreDataStack.viewContext
        let request = CDMealPlan.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try context.fetch(request).compactMap(MealPlanMapper.map)
    }

    func save(_ plan: MealPlan) throws {
        let context = coreDataStack.viewContext
        let request = CDMealPlan.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", plan.id as CVarArg)
        let object = try context.fetch(request).first ?? CDMealPlan(context: context)
        MealPlanMapper.apply(plan, to: object)
        try coreDataStack.saveContext()
    }

    func delete(id: UUID) throws {
        let context = coreDataStack.viewContext
        let request = CDMealPlan.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let object = try context.fetch(request).first {
            context.delete(object)
            try coreDataStack.saveContext()
        }
    }
}
