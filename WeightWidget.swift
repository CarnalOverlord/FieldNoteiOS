import SwiftUI
import WidgetKit

struct WeightEntry: TimelineEntry {
    let date: Date
    let weight: Double?
    let bmi: Double?
    let weightDate: String?
}

struct WeightProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeightEntry { WeightEntry(date: .now, weight: 72.4, bmi: 23.8, weightDate: nil) }
    func getSnapshot(in context: Context, completion: @escaping (WeightEntry) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeightEntry>) -> Void) {
        completion(Timeline(entries: [read()], policy: .after(.now.addingTimeInterval(60 * 60 * 4))))
    }
    private func read() -> WeightEntry {
        let defaults = UserDefaults(suiteName: WidgetShared.suite)
        let weight = defaults?.object(forKey: "latestWeightKg") as? Double
        let height = defaults?.object(forKey: "heightCm") as? Double
        let bmi = if let weight, let height, weight > 0, height > 0 { weight / pow(height / 100, 2) } else { nil }
        return WeightEntry(date: .now, weight: weight, bmi: bmi, weightDate: defaults?.string(forKey: "latestWeightDate"))
    }
}

struct WeightWidgetView: View {
    var entry: WeightProvider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FIELDNOTE · TODAY").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.1).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                metric("WEIGHT", entry.weight.map { String(format: "%.1f kg", $0) } ?? "—")
                Spacer(minLength: 2)
                metric("BMI", entry.bmi.map { String(format: "%.1f", $0) } ?? "—")
            }
            HStack {
                Text(entry.weightDate ?? "Your latest check-in").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 3)
                Link(destination: WidgetShared.url) {
                    Text("＋ TODAY").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(red: 0.97, green: 0.93, blue: 1)).padding(.horizontal, 10).padding(.vertical, 7).background(Color.purple, in: Capsule())
                }
            }
        }
        .padding(16)
        .containerBackground(Color(red: 0.08, green: 0.06, blue: 0.12), for: .widget)
        .widgetURL(WidgetShared.url)
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 21, weight: .semibold, design: .rounded)).minimumScaleFactor(0.75).lineLimit(1)
        }
    }
}

@main struct FieldNoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FieldNoteWeightWidget", provider: WeightProvider()) { entry in WeightWidgetView(entry: entry) }
            .configurationDisplayName("Weight & BMI")
            .description("See your latest weight and BMI, and log today's check-in.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
