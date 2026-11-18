import SwiftUI
import WidgetKit

struct WeightEntry: TimelineEntry {
    let date: Date
    let weight: Double?
    let bmi: Double?
    let weightDate: String?
    let bodyFat: Double?
    let bodyFatIsEstimate: Bool
    let isPremium: Bool
    let weightHistory: [WidgetWeightPoint]
}

struct WeightProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeightEntry {
        WeightEntry(
            date: .now,
            weight: 72.4,
            bmi: 23.8,
            weightDate: nil,
            bodyFat: 18.6,
            bodyFatIsEstimate: true,
            isPremium: true,
            weightHistory: [
                WidgetWeightPoint(date: .now.addingTimeInterval(-60 * 60 * 24 * 14), weightKg: 74.0),
                WidgetWeightPoint(date: .now.addingTimeInterval(-60 * 60 * 24 * 7), weightKg: 73.2),
                WidgetWeightPoint(date: .now, weightKg: 72.4)
            ]
        )
    }
    func getSnapshot(in context: Context, completion: @escaping (WeightEntry) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeightEntry>) -> Void) {
        completion(Timeline(entries: [read()], policy: .after(.now.addingTimeInterval(60 * 60 * 4))))
    }
    private func read() -> WeightEntry {
        let defaults = UserDefaults(suiteName: WidgetShared.suite)
        let weight = defaults?.object(forKey: "latestWeightKg") as? Double
        let height = defaults?.object(forKey: "heightCm") as? Double
        let bmi: Double? = if let weight, let height, weight > 0, height > 0 { weight / pow(height / 100, 2) } else { nil }
        let isPremium = defaults?.bool(forKey: "premiumEnabled") ?? false
        let bodyFat = isPremium ? defaults?.object(forKey: "latestBodyFatPct") as? Double : nil
        let history = defaults?.data(forKey: "weightHistory")
            .flatMap { try? JSONDecoder().decode([WidgetWeightPoint].self, from: $0) } ?? []
        return WeightEntry(
            date: .now,
            weight: weight,
            bmi: bmi,
            weightDate: defaults?.string(forKey: "latestWeightDate"),
            bodyFat: bodyFat,
            bodyFatIsEstimate: defaults?.bool(forKey: "latestBodyFatIsEstimate") ?? false,
            isPremium: isPremium,
            weightHistory: history
        )
    }
}

struct WeightWidgetView: View {
    var entry: WeightProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemLarge {
                largeLayout
            } else {
                compactLayout
            }
        }
        .containerBackground(Color(red: 0.08, green: 0.06, blue: 0.12), for: .widget)
        .widgetURL(WidgetShared.url)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FIELDNOTE · TODAY").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.1).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                metric("WEIGHT", entry.weight.map { String(format: "%.1f kg", $0) } ?? "—")
                Spacer(minLength: 2)
                metric("BMI", entry.bmi.map { String(format: "%.1f", $0) } ?? "—")
            }
            if family == .systemMedium {
                WeightSparkline(points: entry.weightHistory, subdued: true)
                    .frame(height: 26)
                    .padding(.top, -3)
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
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("FIELDNOTE · TODAY")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 10) {
                metric("WEIGHT", entry.weight.map { String(format: "%.1f kg", $0) } ?? "—")
                Spacer(minLength: 0)
                metric("BMI", entry.bmi.map { String(format: "%.1f", $0) } ?? "—")
                Spacer(minLength: 0)
                metric("BODY FAT", bodyFatValue)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("WEIGHT TREND · LAST CHECK-INS")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                WeightSparkline(points: entry.weightHistory)
                    .frame(height: 91)
            }
            .padding(.top, 2)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text(entry.weightDate ?? "Log a check-in to start your trend")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                todayLink
            }
        }
        .padding(18)
    }

    private var bodyFatValue: String {
        guard entry.isPremium else { return "Premium" }
        guard let bodyFat = entry.bodyFat else { return "Add tape" }
        let prefix = entry.bodyFatIsEstimate ? "~" : ""
        return "\(prefix)\(String(format: "%.1f%%", bodyFat))"
    }

    private var todayLink: some View {
        Link(destination: WidgetShared.url) {
            Text("＋ TODAY")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.97, green: 0.93, blue: 1))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.purple, in: Capsule())
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 21, weight: .semibold, design: .rounded)).minimumScaleFactor(0.75).lineLimit(1)
        }
    }
}

private struct WeightSparkline: View {
    let points: [WidgetWeightPoint]
    var subdued = false

    var body: some View {
        GeometryReader { geometry in
            let chartPoints = makeChartPoints(size: geometry.size)
            ZStack {
                if !subdued {
                    Path { path in
                        for fraction in [0.25, 0.5, 0.75] {
                            let y = geometry.size.height * fraction
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

                if chartPoints.count > 1 {
                    if !subdued {
                        areaPath(points: chartPoints, height: geometry.size.height)
                            .fill(LinearGradient(
                                colors: [Color.purple.opacity(0.35), Color.purple.opacity(0.015)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    }
                    Path { path in path.addLines(chartPoints) }
                        .stroke(
                            subdued ? Color.purple.opacity(0.25) : Color.purple.opacity(0.7),
                            style: StrokeStyle(lineWidth: subdued ? 1.5 : 2.5, lineCap: .round, lineJoin: .round)
                        )
                    if !subdued, let last = chartPoints.last {
                        Circle()
                            .fill(.white)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color.purple, lineWidth: 2))
                            .position(last)
                    }
                } else {
                    Text("ADD ANOTHER WEIGH-IN TO SEE YOUR TREND")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last, points.count > 1 else {
            return "Add another weigh-in to see your weight trend."
        }
        return "Weight trend from \(String(format: "%.1f", first.weightKg)) kilograms to \(String(format: "%.1f", last.weightKg)) kilograms."
    }

    private func makeChartPoints(size: CGSize) -> [CGPoint] {
        guard points.count > 1,
              let minimum = points.map(\.weightKg).min(),
              let maximum = points.map(\.weightKg).max(),
              let firstDate = points.first?.date,
              let lastDate = points.last?.date else { return [] }

        let timeRange = max(lastDate.timeIntervalSince(firstDate), 1)
        let valueRange = max(maximum - minimum, 0.4)
        let inset: CGFloat = 7

        return points.map { point in
            let xFraction = point.date.timeIntervalSince(firstDate) / timeRange
            let yFraction = (point.weightKg - minimum) / valueRange
            return CGPoint(
                x: inset + CGFloat(xFraction) * max(size.width - inset * 2, 0),
                y: size.height - inset - CGFloat(yFraction) * max(size.height - inset * 2, 0)
            )
        }
    }

    private func areaPath(points: [CGPoint], height: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: first.x, y: height))
        path.addLine(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.closeSubpath()
        return path
    }
}

@main struct FieldNoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FieldNoteWeightWidget", provider: WeightProvider()) { entry in WeightWidgetView(entry: entry) }
            .configurationDisplayName("FieldNote Progress")
            .description("See your latest weight, BMI and body fat, and track your weight trend.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
