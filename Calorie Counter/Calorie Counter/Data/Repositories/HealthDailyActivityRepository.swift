import CoreData
import Foundation

final class HealthDailyActivityRepository: HealthDailyActivityStoring {
    private let stack: CoreDataStack
    private let onChange: () -> Void

    init(coreDataStack: CoreDataStack, onChange: @escaping () -> Void = {}) {
        stack = coreDataStack
        self.onChange = onChange
    }

    func fetch(from start: Date, to end: Date) throws -> [HealthDailyActivity] {
        try rows(from: start, to: end).compactMap { row in
            guard let date = row.date else { return nil }
            return HealthDailyActivity(
                date: date,
                activeEnergyKilocalories: row.activeEnergyKilocalories?.doubleValue,
                steps: row.steps?.doubleValue
            )
        }
    }

    func replace(_ days: [HealthDailyActivity], from start: Date, to end: Date) throws {
        let current = try rows(from: start, to: end)
        let calendar = Calendar.current
        var byDate = Dictionary(grouping: current) { calendar.startOfDay(for: $0.date ?? .distantPast) }
        var changed = false
        for day in days where day.date >= start && day.date < end {
            let date = calendar.startOfDay(for: day.date)
            let matching = byDate.removeValue(forKey: date) ?? []
            let row = matching.first ?? CDDailyHealthActivity(context: stack.viewContext)
            let energy = day.activeEnergyKilocalories.map { NSNumber(value: max(0, $0)) }
            let steps = day.steps.map { NSNumber(value: max(0, $0)) }
            if row.date != date || row.activeEnergyKilocalories != energy || row.steps != steps {
                row.date = date
                row.activeEnergyKilocalories = energy
                row.steps = steps
                changed = true
            }
            for duplicate in matching.dropFirst() {
                stack.viewContext.delete(duplicate)
                changed = true
            }
        }
        for obsolete in byDate.values.flatMap({ $0 }) {
            stack.viewContext.delete(obsolete)
            changed = true
        }
        guard changed else { return }
        try stack.saveContext()
        onChange()
    }

    private func rows(from start: Date, to end: Date) throws -> [CDDailyHealthActivity] {
        let request = CDDailyHealthActivity.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        return try stack.viewContext.fetch(request)
    }
}
