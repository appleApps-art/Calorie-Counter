import ActivityKit
import Foundation

/// The running day in the Dynamic Island and on the Lock Screen.
///
/// `dayStart` is fixed for the life of the activity, so a new day means a new activity rather than
/// an update; everything that moves during the day lives in `ContentState`.
struct DayActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var eatenCalories: Double
        var calorieTarget: Double
        var breakfastCalories: Double
        var lunchCalories: Double
        var dinnerCalories: Double
        var snacksCalories: Double
        var streakDays: Int

        var remainingCalories: Double {
            calorieTarget - eatenCalories
        }

        var progress: Double {
            guard calorieTarget > 0 else { return 0 }
            return min(1, max(0, eatenCalories / calorieTarget))
        }

        var isOverTarget: Bool {
            calorieTarget > 0 && eatenCalories > calorieTarget
        }

        func calories(for meal: WidgetMealKind) -> Double {
            switch meal {
            case .breakfast: return breakfastCalories
            case .lunch: return lunchCalories
            case .dinner: return dinnerCalories
            case .snacks: return snacksCalories
            }
        }
    }

    var dayStart: Date
}

extension DayActivityAttributes.ContentState {
    init(snapshot: WidgetDiarySnapshot) {
        self.init(
            eatenCalories: snapshot.eatenCalories,
            calorieTarget: snapshot.calorieTarget,
            breakfastCalories: snapshot.calories(for: .breakfast),
            lunchCalories: snapshot.calories(for: .lunch),
            dinnerCalories: snapshot.calories(for: .dinner),
            snacksCalories: snapshot.calories(for: .snacks),
            streakDays: snapshot.streakDays
        )
    }

    static let preview = DayActivityAttributes.ContentState(
        eatenCalories: 760,
        calorieTarget: 2000,
        breakfastCalories: 320,
        lunchCalories: 440,
        dinnerCalories: 0,
        snacksCalories: 0,
        streakDays: 5
    )
}
