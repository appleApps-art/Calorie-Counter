import Foundation
import CoreGraphics

struct ProgressMacroColumn: Equatable {
    var date: Date
    var proteinKcal: Double
    var carbsKcal: Double
    var fatsKcal: Double
    var calories: Double
    var aggregationDayCount: Int = 1

    var stackTotal: Double { proteinKcal + carbsKcal + fatsKcal }
    var plotValue: Double { max(calories, stackTotal) }
}

struct ProgressValueColumn: Equatable {
    var date: Date
    var value: Double
    var aggregationDayCount: Int = 1
}

struct ProgressPhotoPreview: Equatable {
    var photo: ProgressPhoto
    var dateText: String
}

struct ProgressPhotoDaySection: Equatable {
    var date: Date
    var dateText: String
    var pair: ProgressPhotoPair
}

struct ProgressChartScale: Equatable {
    var min: Double
    var max: Double

    var range: Double { Swift.max(max - min, .ulpOfOne) }

    func y(for value: Double, in plot: CGRect) -> CGFloat {
        plot.maxY - CGFloat((value - min) / range) * plot.height
    }

    func height(for value: Double, in plot: CGRect) -> CGFloat {
        CGFloat(value / range) * plot.height
    }

    static func bars(values: [Double], target: Double) -> ProgressChartScale {
        let peak = Swift.max(values.max() ?? 0, target, 1)
        return ProgressChartScale(min: 0, max: ProgressChartMath.niceCeiling(peak))
    }

    static func line(values: [Double]) -> ProgressChartScale {
        ProgressChartMath.lineScale(values: values)
    }
}

enum ProgressChartMath {
    static func slice(_ points: [DailyMacroPoint], period: ProgressChartPeriod, now: Date, calendar: Calendar) -> [DailyMacroPoint] {
        let start = calendar.date(byAdding: .day, value: -(period.dayCount - 1), to: calendar.startOfDay(for: now)) ?? now
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return points.filter { $0.date >= start && $0.date < end }
    }

    static func calorieColumns(
        points: [DailyMacroPoint],
        period: ProgressChartPeriod,
        now: Date,
        calendar: Calendar
    ) -> [ProgressMacroColumn] {
        let sliced = slice(points, period: period, now: now, calendar: calendar)
        let grouped = Dictionary(grouping: sliced) { calendar.startOfDay(for: $0.date) }
        return bucketDates(period: period, now: now, calendar: calendar).map { bucket in
            let items = bucket.days.flatMap { grouped[$0] ?? [] }
            let days = Double(bucket.days.count)
            return ProgressMacroColumn(
                date: bucket.date,
                proteinKcal: items.reduce(0) { $0 + $1.protein } * 4 / days,
                carbsKcal: items.reduce(0) { $0 + $1.carbs } * 4 / days,
                fatsKcal: items.reduce(0) { $0 + $1.fats } * 9 / days,
                calories: items.reduce(0) { $0 + $1.calories } / days,
                aggregationDayCount: bucket.days.count
            )
        }
    }

    static func expenditureColumns(
        workouts: [WorkoutEntry],
        healthActivity: [HealthDailyActivity] = [],
        period: ProgressChartPeriod,
        now: Date,
        calendar: Calendar
    ) -> [ProgressValueColumn] {
        let daily = dailyExpenditure(workouts: workouts, healthActivity: healthActivity, period: period, now: now, calendar: calendar)
        let grouped = Dictionary(uniqueKeysWithValues: daily.map { ($0.date, $0.value) })
        return bucketDates(period: period, now: now, calendar: calendar).map { bucket in
            let burned = bucket.days.reduce(0.0) { total, day in
                total + (grouped[day] ?? 0)
            }
            return ProgressValueColumn(date: bucket.date, value: burned / Double(bucket.days.count), aggregationDayCount: bucket.days.count)
        }
    }

    static func dailyExpenditure(
        workouts: [WorkoutEntry],
        healthActivity: [HealthDailyActivity] = [],
        period: ProgressChartPeriod,
        now: Date,
        calendar: Calendar
    ) -> [ProgressValueColumn] {
        let workoutsByDay = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.date) }
        let activityByDay = Dictionary(grouping: healthActivity) { calendar.startOfDay(for: $0.date) }
        return bucketDates(period: period, now: now, calendar: calendar).flatMap(\.days).map { day in
            ProgressValueColumn(date: day, value: ActivityEnergyCalculator.total(
                workouts: workoutsByDay[day] ?? [], healthActivity: activityByDay[day]?.last
            ))
        }
    }

    static func weightColumns(
        entries: [WeightEntry],
        period: ProgressChartPeriod,
        now: Date,
        calendar: Calendar
    ) -> [ProgressValueColumn] {
        let start = calendar.date(byAdding: .day, value: -(period.dayCount - 1), to: calendar.startOfDay(for: now)) ?? now
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return entries
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
            .map { ProgressValueColumn(date: $0.date, value: $0.weightKilograms) }
    }

    static func insightText(points: [DailyMacroPoint], fiberTarget: Double, now: Date, calendar: Calendar) -> String? {
        let thisWeek = slice(points, period: .week, now: now, calendar: calendar)
        let previousEnd = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let previousWeek = slice(points, period: .week, now: previousEnd, calendar: calendar)
        let thisProtein = average(\.protein, in: thisWeek)
        let previousProtein = average(\.protein, in: previousWeek)
        let thisFiber = average(\.fiber, in: thisWeek)
        let hasFood = thisWeek.contains { $0.calories > 0 || $0.protein > 0 || $0.fiber > 0 }
        guard hasFood else { return nil }

        var parts: [String] = []
        if previousProtein > 0, thisProtein > 0 {
            let delta = ((thisProtein - previousProtein) / previousProtein) * 100
            let percent = Int(abs(delta).rounded())
            if percent > 0 {
                let key = delta >= 0 ? "progress.insight.proteinImproved" : "progress.insight.proteinDropped"
                parts.append(L10n.format(key, percent))
            }
        }
        if thisFiber > 0, thisFiber < fiberTarget {
            parts.append(L10n.tr("progress.insight.fiberBelow"))
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    static func photoPreviews(_ photos: [ProgressPhoto], calendar: Calendar, limit: Int = 3) -> [ProgressPhotoPreview] {
        let sorted = photos.sorted { $0.date > $1.date }
        var seenDays = Set<Date>()
        var result: [ProgressPhotoPreview] = []
        for photo in sorted {
            let day = calendar.startOfDay(for: photo.date)
            guard seenDays.insert(day).inserted else { continue }
            result.append(ProgressPhotoPreview(photo: photo, dateText: photoDateText(photo.date)))
            if result.count == limit { break }
        }
        return result
    }

    static func photoDaySections(_ photos: [ProgressPhoto], calendar: Calendar) -> [ProgressPhotoDaySection] {
        let grouped = Dictionary(grouping: photos) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).compactMap { day in
            let pair = ProgressPhotoPair.from(grouped[day] ?? [])
            guard pair.front != nil || pair.side != nil else { return nil }
            return ProgressPhotoDaySection(
                date: day,
                dateText: photoDateText(day),
                pair: pair
            )
        }
    }

    static func axisDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    static func photoDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return formatter.string(from: date)
    }

    static func kcalText(_ value: Double) -> String {
        L10n.format("progress.kcalFormat", groupedNumber(value))
    }

    static func columnKcalText(_ value: Double, dayCount: Int) -> String {
        dayCount > 1 ? L10n.format("progress.dailyAverageKcalFormat", groupedNumber(value)) : kcalText(value)
    }

    static func groupedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    static func axisNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = abs(value.rounded() - value) < 0.05 ? 0 : 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value.rounded()))"
    }

    static func niceCeiling(_ value: Double) -> Double {
        guard value > 0 else { return 1 }
        let exponent = floor(log10(value))
        let magnitude = pow(10, exponent)
        let normalized = value / magnitude
        let nice: Double
        if normalized <= 1 {
            nice = 1
        } else if normalized <= 2 {
            nice = 2
        } else if normalized <= 2.5 {
            nice = 2.5
        } else if normalized <= 5 {
            nice = 5
        } else {
            nice = 10
        }
        return nice * magnitude
    }

    static func lineScale(values: [Double]) -> ProgressChartScale {
        guard let rawMin = values.min(), let rawMax = values.max() else {
            return ProgressChartScale(min: 0, max: 1)
        }
        var lower = rawMin
        var upper = rawMax
        if abs(upper - lower) < 0.5 {
            lower -= 1
            upper += 1
        } else {
            let padding = (upper - lower) * 0.1
            lower -= padding
            upper += padding
        }
        let span = Swift.max(upper - lower, 0.1)
        let magnitude = pow(10, floor(log10(span)))
        let normalized = span / magnitude
        let step: Double
        if normalized <= 2 {
            step = magnitude / 2
        } else if normalized <= 5 {
            step = magnitude
        } else {
            step = magnitude * 2
        }
        let niceMin = floor(lower / step) * step
        let niceMax = ceil(upper / step) * step
        return ProgressChartScale(min: niceMin, max: Swift.max(niceMax, niceMin + step))
    }

    static func macroCalloutText(_ name: String, grams: Double) -> String {
        "\(name)  \(L10n.format("onboarding.plan.gramsFormat", Int(grams.rounded())))"
    }

    private static func average(_ keyPath: KeyPath<DailyMacroPoint, Double>, in points: [DailyMacroPoint]) -> Double {
        let active = points.filter { $0[keyPath: keyPath] > 0 || $0.calories > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + $1[keyPath: keyPath] } / Double(active.count)
    }

    private struct DateBucket {
        var date: Date
        var days: [Date]
    }

    private static func bucketDates(
        period: ProgressChartPeriod,
        now: Date,
        calendar: Calendar
    ) -> [DateBucket] {
        let today = calendar.startOfDay(for: now)
        let days: [Date] = (0..<period.dayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: -((period.dayCount - 1) - offset), to: today)
        }
        guard period != .week else {
            return days.map { DateBucket(date: $0, days: [$0]) }
        }
        var buckets: [Date: [Date]] = [:]
        var order: [Date] = []
        for day in days {
            let week = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
            if buckets[week] == nil {
                order.append(week)
            }
            buckets[week, default: []].append(day)
        }
        return order.map { DateBucket(date: $0, days: buckets[$0] ?? [$0]) }
    }
}
