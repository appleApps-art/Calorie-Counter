import CoreData
import Foundation

protocol WaterEntryRepositoryProtocol {
    func fetchEntries(for date: Date) throws -> [WaterEntry]
    func fetchEntries(from start: Date, to end: Date) throws -> [WaterEntry]
    func save(_ entry: WaterEntry) throws
    func delete(id: UUID) throws
}

final class WaterEntryRepository: WaterEntryRepositoryProtocol {
    private let coreDataStack: CoreDataStack

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    func fetchEntries(for date: Date) throws -> [WaterEntry] {
        let range = DateRangeHelper.dayInterval(for: date)
        return try fetchEntries(from: range.start, to: range.end)
    }

    func fetchEntries(from start: Date, to end: Date) throws -> [WaterEntry] {
        let context = coreDataStack.viewContext
        let request = CDWaterEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            start as NSDate,
            end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let objects = try context.fetch(request)
        return objects.compactMap(WaterEntryMapper.map)
    }

    func save(_ entry: WaterEntry) throws {
        let context = coreDataStack.viewContext
        let request = CDWaterEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
        let object = try context.fetch(request).first ?? CDWaterEntry(context: context)
        WaterEntryMapper.apply(entry, to: object)
        try coreDataStack.saveContext()
    }

    func delete(id: UUID) throws {
        let context = coreDataStack.viewContext
        let request = CDWaterEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let object = try context.fetch(request).first {
            context.delete(object)
            try coreDataStack.saveContext()
        }
    }
}
