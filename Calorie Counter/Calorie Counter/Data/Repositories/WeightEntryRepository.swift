import CoreData
import Foundation

protocol WeightEntryRepositoryProtocol {
    func fetchEntries() throws -> [WeightEntry]
    func fetchEntries(for date: Date) throws -> [WeightEntry]
    func fetchEntries(from start: Date, to end: Date) throws -> [WeightEntry]
    func save(_ entry: WeightEntry) throws
}

final class WeightEntryRepository: WeightEntryRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchEntries() throws -> [WeightEntry] {
        let context = coreDataStack.viewContext
        let request = CDWeightEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let objects = try context.fetch(request)
        return objects.compactMap(WeightEntryMapper.map)
    }

    func fetchEntries(for date: Date) throws -> [WeightEntry] {
        let range = DateRangeHelper.dayInterval(for: date)
        return try fetchEntries(from: range.start, to: range.end)
    }

    func fetchEntries(from start: Date, to end: Date) throws -> [WeightEntry] {
        let context = coreDataStack.viewContext
        let request = CDWeightEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            start as NSDate,
            end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let objects = try context.fetch(request)
        return objects.compactMap(WeightEntryMapper.map)
    }

    func save(_ entry: WeightEntry) throws {
        let context = coreDataStack.viewContext
        let request = CDWeightEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        let object = try context.fetch(request).first ?? CDWeightEntry(context: context)
        WeightEntryMapper.apply(entry, to: object)
        try coreDataStack.saveContext()
    }
}
