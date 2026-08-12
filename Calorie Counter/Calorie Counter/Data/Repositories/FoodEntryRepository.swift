import CoreData
import Foundation

protocol FoodEntryRepositoryProtocol {
    func fetchEntries(for date: Date) throws -> [FoodEntry]
    func fetchEntries(from start: Date, to end: Date) throws -> [FoodEntry]
    func fetchEntry(id: UUID) throws -> FoodEntry?
    func save(_ entry: FoodEntry) throws
    func delete(id: UUID) throws
}

final class FoodEntryRepository: FoodEntryRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchEntries(for date: Date) throws -> [FoodEntry] {
        let range = DateRangeHelper.dayInterval(for: date)
        return try fetchEntries(from: range.start, to: range.end)
    }

    func fetchEntries(from start: Date, to end: Date) throws -> [FoodEntry] {
        let context = coreDataStack.viewContext
        let request = CDFoodEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            start as NSDate,
            end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let objects = try context.fetch(request)
        return objects.compactMap(FoodEntryMapper.map)
    }

    func fetchEntry(id: UUID) throws -> FoodEntry? {
        let context = coreDataStack.viewContext
        let request = CDFoodEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first.flatMap(FoodEntryMapper.map)
    }

    func save(_ entry: FoodEntry) throws {
        let context = coreDataStack.viewContext
        let request = CDFoodEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        let object = try context.fetch(request).first ?? CDFoodEntry(context: context)
        FoodEntryMapper.apply(entry, to: object)
        try coreDataStack.saveContext()
    }

    func delete(id: UUID) throws {
        let context = coreDataStack.viewContext
        let request = CDFoodEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let object = try context.fetch(request).first {
            context.delete(object)
            try coreDataStack.saveContext()
        }
    }
}
