import SwiftUI
import Charts

private enum TrendMetric: String, CaseIterable, Identifiable {
    case weight, bodyFat, waist, hip, chest, arm, thigh, neck
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weight: "weight"
        case .bodyFat: "body fat %"
        case .waist: "waist"
        case .hip: "hip"
        case .chest: "chest"
        case .arm: "arm"
        case .thigh: "thigh"
        case .neck: "neck"
        }
    }
    var unit: String { self == .weight ? "kg" : (self == .bodyFat ? "%" : "cm") }
    func value(_ entry: Entry, profile: Profile?) -> Double? {
        switch self {
        case .weight: entry.weight_kg
        case .bodyFat: bodyFatOf(entry, profile: profile)
        case .waist: entry.waist_cm
        case .hip: entry.hip_cm
        case .chest: entry.chest_cm
        case .arm: entry.arm_cm
        case .thigh: entry.thigh_cm
        case .neck: entry.neck_cm
        }
    }
}

struct TrendsView: View {
    @EnvironmentObject private var session: AppSession
    let openSettings: () -> Void
    @State private var metric: TrendMetric = .weight
    @State private var busyEntryID: String?
    @State private var entryToDelete: Entry?
    @State private var actionError: String?

    private var trend: WeightTrend { WeightTrend.calculate(entries: session.entries, goal: session.profile?.goal_weight_kg) }
    private var series: [WeightPoint] {
        session.entries.compactMap { entry in
            guard let date = entryDate(entry.entry_date), let value = metric.value(entry, profile: session.profile) else { return nil }
            return WeightPoint(date: date, value: value)
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        FieldNoteTopBar(openSettings: openSettings)
                        VStack(alignment: .leading, spacing: 5) {
                            SectionEyebrow(text: "Trends")
                            Text("Where this is heading")
                                .font(.system(size: 27, weight: .semibold, design: .rounded))
                                .foregroundStyle(FieldNoteStyle.ink)
                        }
                        weightForecastPanel
                        measurementTrendPanel
                        logPanel
                        if let actionError { InlineMessage(text: actionError) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .refreshable { await session.loadDashboard() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("Delete this check-in?", isPresented: Binding(get: { entryToDelete != nil }, set: { if !$0 { entryToDelete = nil } }), titleVisibility: .visible) {
                Button("Delete check-in", role: .destructive) {
                    guard let entryToDelete else { return }
                    Task {
                        do { try await session.deleteEntry(id: entryToDelete.id) }
                        catch { actionError = error.localizedDescription }
                        self.entryToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { entryToDelete = nil }
            } message: {
                if let entryToDelete { Text("This removes the entry from \(displayDate(entryToDelete.entry_date)).") }
            }
        }
    }

    private var weightForecastPanel: some View {
        FieldNotePanel(padding: 17) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionEyebrow(text: "Weight · kg")
                    Spacer()
                    Text("dashed = forecast").font(.system(size: 9, weight: .regular, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
                }
                if trend.recentPoints.isEmpty {
                    Text("Log weight on a few dates to build your report.")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(FieldNoteStyle.muted)
                        .frame(maxWidth: .infinity, minHeight: 155)
                } else {
                    Chart {
                        if let goal = session.profile?.goal_weight_kg {
                            RuleMark(y: .value("Goal", goal))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 5]))
                                .foregroundStyle(FieldNoteStyle.clay)
                        }
                        ForEach(trend.recentPoints) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Weight", point.value))
                                .foregroundStyle(FieldNoteStyle.ink.opacity(0.45))
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(x: .value("Date", point.date), y: .value("Weight", point.value))
                                .foregroundStyle(FieldNoteStyle.ink)
                                .symbolSize(40)
                        }
                        ForEach(trend.forecastPoints) { point in
                            LineMark(x: .value("Forecast date", point.date), y: .value("Forecast weight", point.value))
                                .foregroundStyle(FieldNoteStyle.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        }
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().foregroundStyle(FieldNoteStyle.muted) } }
                    .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().foregroundStyle(FieldNoteStyle.muted) } }
                    .chartXScale(domain: .automatic(includesZero: false))
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 185)
                }
                HStack(spacing: 8) {
                    summaryTile("pace / wk", trend.slopePerWeek.map { signed($0, digits: 2) } ?? "—")
                    summaryTile("current", trend.current.map { String(format: "%.1f", $0) } ?? "—")
                    summaryTile("goal", session.profile?.goal_weight_kg.map { String(format: "%.1f", $0) } ?? "—")
                }
                FieldNoteStatus(text: forecastMessage, color: trend.status == "wrong-way" ? FieldNoteStyle.clay : FieldNoteStyle.sage)
            }
        }
    }

    private var forecastMessage: String {
        switch trend.status {
        case "on-track":
            if let eta = trend.etaDate { return "At this pace, your goal is around \(eta.formatted(.dateTime.month(.abbreviated).year()))." }
            return "At this pace, your goal is more than 3 years out."
        case "wrong-way": return "Your recent trend is moving away from your goal."
        case "flat": return "Your recent weight is holding steady."
        case "reached": return "You have reached your goal weight."
        case "no-goal": return "Set a goal weight in settings to see a forecast."
        default: return "Add at least two weigh-ins to estimate your goal date."
        }
    }

    private var measurementTrendPanel: some View {
        FieldNotePanel(padding: 16) {
            VStack(alignment: .leading, spacing: 13) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(TrendMetric.allCases) { option in
                            Button { metric = option } label: {
                                Text(option.title)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(metric == option ? FieldNoteStyle.paper : FieldNoteStyle.muted)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(metric == option ? FieldNoteStyle.ink : FieldNoteStyle.paper, in: Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if series.isEmpty {
                    Text("No \(metric.title) data yet.")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(FieldNoteStyle.muted)
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    Chart(series) { point in
                        LineMark(x: .value("Date", point.date), y: .value(metric.title, point.value))
                            .foregroundStyle(FieldNoteStyle.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2.2))
                        PointMark(x: .value("Date", point.date), y: .value(metric.title, point.value))
                            .foregroundStyle(FieldNoteStyle.accent)
                            .symbolSize(38)
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().foregroundStyle(FieldNoteStyle.muted) } }
                    .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in AxisValueLabel().foregroundStyle(FieldNoteStyle.muted) } }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 165)
                    if let first = series.first, let last = series.last {
                        HStack {
                            Text("\(String(format: "%.1f", first.value)) \(metric.unit) → \(String(format: "%.1f", last.value)) \(metric.unit)")
                            Spacer()
                            Text(signed(last.value - first.value) + " \(metric.unit)").foregroundStyle(FieldNoteStyle.accent)
                        }
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(FieldNoteStyle.muted)
                    }
                }
            }
        }
    }

    private var logPanel: some View {
        FieldNotePanel(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    SectionEyebrow(text: "Log")
                    Spacer()
                    Text("\(session.entries.count) check-ins")
                        .font(.system(size: 10, weight: .regular, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
                }.padding(17)
                if session.entries.isEmpty {
                    Text("Your entries will appear here.")
                        .font(.system(size: 12, weight: .regular, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(17)
                } else {
                    ForEach(session.entries) { entry in logRow(entry) }
                }
            }
        }
    }

    private func logRow(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(entryDate(entry.entry_date)?.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)) ?? entry.entry_date)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(FieldNoteStyle.muted)
                    .frame(width: 68, alignment: .leading)
                Text(entry.weight_kg.map { String(format: "%.1f kg", $0) } ?? "Tape/photo")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(FieldNoteStyle.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let waist = entry.waist_cm { Text("\(String(format: "%.1f", waist)) cm").font(.system(size: 9, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted) }
                Button { runInsight(for: entry) } label: {
                    if busyEntryID == entry.id { ProgressView().tint(FieldNoteStyle.accent) }
                    else { Image(systemName: "sparkles").foregroundStyle(entry.ai_insight == nil ? FieldNoteStyle.muted : FieldNoteStyle.accent) }
                }.buttonStyle(.plain).disabled(busyEntryID != nil).accessibilityLabel("Generate insight for this entry")
                Button(role: .destructive) { entryToDelete = entry } label: { Image(systemName: "trash").foregroundStyle(FieldNoteStyle.muted) }
                    .buttonStyle(.plain).accessibilityLabel("Delete this entry")
            }
            if let text = entry.ai_insight, !text.isEmpty {
                Text(text).font(.system(size: 11, weight: .regular, design: .monospaced)).lineSpacing(3).foregroundStyle(FieldNoteStyle.muted)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(FieldNoteStyle.paper.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .overlay(alignment: .top) { Rectangle().fill(FieldNoteStyle.line).frame(height: 1) }
    }

    private func summaryTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            SectionEyebrow(text: title)
            Text(value).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(FieldNoteStyle.ink)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 9).background(FieldNoteStyle.paper.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
    }

    private func runInsight(for entry: Entry) {
        busyEntryID = entry.id
        actionError = nil
        Task {
            do { try await session.generateEntryInsight(id: entry.id) }
            catch { actionError = error.localizedDescription }
            busyEntryID = nil
        }
    }
}
