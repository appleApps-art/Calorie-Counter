import SwiftUI
import WidgetKit

struct DiaryWidgetView: View {
    let entry: DiaryWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            calorieRing
            VStack(alignment: .leading, spacing: 8) {
                metricRow(
                    title: WidgetL10n.tr("widget.protein"),
                    current: entry.snapshot.protein,
                    target: entry.snapshot.proteinTarget,
                    unit: WidgetL10n.tr("widget.grams")
                )
                metricRow(
                    title: WidgetL10n.tr("widget.carbs"),
                    current: entry.snapshot.carbs,
                    target: entry.snapshot.carbsTarget,
                    unit: WidgetL10n.tr("widget.grams")
                )
                metricRow(
                    title: WidgetL10n.tr("widget.fats"),
                    current: entry.snapshot.fats,
                    target: entry.snapshot.fatsTarget,
                    unit: WidgetL10n.tr("widget.grams")
                )
                metricRow(
                    title: WidgetL10n.tr("widget.water"),
                    current: entry.snapshot.waterMilliliters,
                    target: entry.snapshot.waterTargetMilliliters,
                    unit: WidgetL10n.tr("widget.milliliters")
                )
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    Link(destination: AppDeepLink.logFood.url) {
                        Text(WidgetL10n.tr("widget.log"))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .widgetURL(AppDeepLink.home.url)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var calorieRing: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 10)
            Circle()
                .trim(from: 0, to: entry.hasData ? entry.snapshot.calorieProgress : 0)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(remainingText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(WidgetL10n.tr("widget.remaining"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 118, height: 118)
    }

    private var remainingText: String {
        guard entry.hasData else { return "-" }
        return "\(Int(entry.snapshot.remainingCalories.rounded()))"
    }

    private var ringColor: Color {
        if !entry.hasData {
            return Color.primary.opacity(0.2)
        }
        return entry.snapshot.isOverCalorieTarget ? .orange : .green
    }

    private func metricRow(title: String, current: Double, target: Double, unit: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(metricText(current: current, target: target, unit: unit))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func metricText(current: Double, target: Double, unit: String) -> String {
        guard entry.hasData else { return "-" }
        return "\(Int(current.rounded()))/\(Int(target.rounded())) \(unit)"
    }
}
