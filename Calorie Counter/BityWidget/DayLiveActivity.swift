import ActivityKit
import SwiftUI
import WidgetKit

struct DayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DayActivityAttributes.self) { context in
            LockScreenDayView(state: context.state)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CalorieBadge(state: context.state)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StreakBadge(days: context.state.streakDays)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    MealRow(state: context.state)
                        .padding(.top, 6)
                }
            } compactLeading: {
                StreakBadge(days: context.state.streakDays)
            } compactTrailing: {
                Text(LiveActivityFormat.calories(context.state.remainingCalories))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(LiveActivityPalette.calorieTint(isOverTarget: context.state.isOverTarget))
            } minimal: {
                CalorieRing(state: context.state)
            }
            .widgetURL(AppDeepLink.home.url)
            .keylineTint(LiveActivityPalette.calorieTint(isOverTarget: context.state.isOverTarget))
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenDayView: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                CalorieBadge(state: state)
                Spacer(minLength: 8)
                StreakBadge(days: state.streakDays)
            }
            MealRow(state: state)
        }
    }
}

// MARK: - Pieces

private struct CalorieBadge: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            CalorieRing(state: state)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(LiveActivityFormat.calories(abs(state.remainingCalories)))
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                Text(WidgetL10n.tr(state.isOverTarget ? "widget.over" : "widget.remaining"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CalorieRing: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.02, state.progress))
                .stroke(
                    LiveActivityPalette.calorieTint(isOverTarget: state.isOverTarget),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundStyle(LiveActivityPalette.streak)
            Text("\(days)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetL10n.format("widget.streakAccessibility", days))
    }
}

private struct MealRow: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            MealButton(meal: .breakfast, calories: state.calories(for: .breakfast))
            MealButton(meal: .lunch, calories: state.calories(for: .lunch))
            MealButton(meal: .dinner, calories: state.calories(for: .dinner))
            // Snacks sit apart from the three main meals, the way the diary groups them.
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 44)
                .padding(.horizontal, 2)
            MealButton(meal: .snacks, calories: state.calories(for: .snacks))
        }
    }
}

private struct MealButton: View {
    let meal: WidgetMealKind
    let calories: Double

    var body: some View {
        Link(destination: AppDeepLink.logMeal(meal).url) {
            VStack(spacing: 3) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: meal.systemImageName)
                                .font(.system(size: 14))
                                .foregroundStyle(LiveActivityPalette.tint(for: meal))
                        )
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, LiveActivityPalette.accent)
                        .offset(x: 3, y: 1)
                }
                Text(WidgetL10n.tr(meal.localizationKey))
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(LiveActivityFormat.kcal(calories))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(WidgetL10n.tr(meal.localizationKey))
    }
}

// MARK: - Formatting

enum LiveActivityFormat {
    static func calories(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    static func kcal(_ value: Double) -> String {
        WidgetL10n.format("widget.kcalValue", Int(value.rounded()))
    }
}

enum LiveActivityPalette {
    static let accent = Color(red: 0.13, green: 0.47, blue: 1)
    static let streak = Color(red: 1, green: 0.45, blue: 0.16)

    static func calorieTint(isOverTarget: Bool) -> Color {
        isOverTarget ? .orange : .green
    }

    static func tint(for meal: WidgetMealKind) -> Color {
        switch meal {
        case .breakfast: return Color(red: 1, green: 0.62, blue: 0.18)
        case .lunch: return Color(red: 0.98, green: 0.76, blue: 0.18)
        case .dinner: return Color(red: 0.45, green: 0.4, blue: 0.95)
        case .snacks: return Color(red: 0.2, green: 0.78, blue: 0.47)
        }
    }
}
