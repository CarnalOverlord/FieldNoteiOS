import SwiftUI
import Charts

struct TodayView: View {
    @EnvironmentObject private var session: AppSession
    let openSettings: () -> Void
    @State private var showingEditor = false
    @State private var showingProgressStory = false

    private var trend: WeightTrend {
        WeightTrend.calculate(entries: session.entries, goal: session.profile?.goal_weight_kg)
    }
    private var latest: Entry? { session.entries.first }
    private var latestPhoto: Entry? { session.entries.filter { $0.photo_path != nil }.first }
    private var firstPhoto: Entry? { session.entries.filter { $0.photo_path != nil }.last }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                FieldNoteBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        FieldNoteTopBar(openSettings: openSettings)
                        if let error = session.errorMessage { InlineMessage(text: error, retry: { Task { await session.loadDashboard() } }) }
                        todayHeading
                        weightCard
                        shareStoryButton
                        bmrCard
                        trendCard
                        bodyFatCard
                        progressPhotosCard
                        if let summary = session.dashboardData, let insight = summary.profile.last_insight, !insight.isEmpty {
                            insightPreview(insight)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 95)
                }
                .refreshable { await session.loadDashboard() }

                Button { showingEditor = true } label: {
                    Label("Log entry", systemImage: "plus")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(FieldNoteStyle.paper)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 15)
                        .background(FieldNoteStyle.buttonGradient, in: Capsule())
                        .shadow(color: FieldNoteStyle.accent.opacity(0.3), radius: 18, y: 8)
                }
                .accessibilityLabel("Log weight, measurements, or a progress photo")
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEditor) { EntryEditorView(date: Date()) }
        }
    }

    private var progressStoryData: ProgressStoryData? {
        ProgressStoryData.make(
            entries: session.entries,
            profile: session.profile,
            latestMeasurement: session.dashboardData?.latest_measurement_entry
        )
    }

    private var shareStoryButton: some View {
        Button {
            showingProgressStory = true
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FieldNoteStyle.paper)
                    .frame(width: 42, height: 42)
                    .background(FieldNoteStyle.buttonGradient, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Make a progress story")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(FieldNoteStyle.ink)
                    Text("A little recognition goes a long way.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(FieldNoteStyle.muted)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FieldNoteStyle.accent)
            }
            .padding(14)
            .background(FieldNoteStyle.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(FieldNoteStyle.line, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(progressStoryData == nil)
        .opacity(progressStoryData == nil ? 0.55 : 1)
        .accessibilityHint("Creates a story-sized image with your latest progress to share.")
        .sheet(isPresented: $showingProgressStory) {
            if let data = progressStoryData {
                ProgressStoryShareSheet(data: data)
            }
        }
    }

    private var todayHeading: some View {
        VStack(alignment: .leading, spacing: 6) {
            let days = max(0, 7 - (session.dashboardData?.days_since_weigh_in ?? 7))
            SectionEyebrow(text: "\(Date.now.formatted(.dateTime.weekday(.wide)).uppercased()) · \(days == 0 ? "WEIGH-IN DUE" : "NEXT WEIGH-IN IN \(days)D")")
            Text("Your progress,\none day at a time.")
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .foregroundStyle(FieldNoteStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 3)
    }

    private var weightCard: some View {
        let previous = session.entries.dropFirst().first?.weight_kg
        let initial = session.entries.last?.weight_kg
        let current = latest?.weight_kg
        let sinceLast = current.flatMap { c in previous.map { c - $0 } }
        let total = current.flatMap { c in initial.map { c - $0 } }
        let toGoal = current.flatMap { c in session.profile?.goal_weight_kg.map { abs(c - $0) } }
        return FieldNotePanel(padding: 0) {
            VStack(alignment: .leading, spacing: 13) {
                SectionEyebrow(text: "Weight · kg")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(current.map { String(format: "%.1f", $0) } ?? "—")
                        .font(.system(size: 58, weight: .medium, design: .monospaced))
                        .foregroundStyle(FieldNoteStyle.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("kg").font(.system(size: 19, weight: .regular, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
                }
                HStack(spacing: 7) {
                    deltaPill(sinceLast.map { "\($0 <= 0 ? "▼" : "▲") \(String(format: "%.1f", abs($0))) since last" } ?? "no prior weigh-in", positive: (sinceLast ?? 0) <= 0)
                    deltaPill(total.map { "\(signed($0)) total" } ?? "new log", positive: (total ?? 0) <= 0)
                    deltaPill(toGoal.map { "\(String(format: "%.1f", $0)) to go" } ?? "set a goal", positive: true)
                }
                HStack {
                    Text(latest.map { displayDate($0.entry_date) } ?? "Log your first check-in")
                    Spacer()
                    if let goal = session.profile?.goal_weight_kg { Text("GOAL  \(String(format: "%.1f", goal)) kg") }
                }
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(FieldNoteStyle.muted)
            }
            .padding(18)
        }
    }

    private func deltaPill(_ text: String, positive: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(positive ? FieldNoteStyle.sage : FieldNoteStyle.clay)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(FieldNoteStyle.paper.opacity(0.65), in: Capsule())
            .overlay(Capsule().stroke(FieldNoteStyle.line, lineWidth: 1))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private var bmrCard: some View {
        let currentWeight = session.entries.first(where: { $0.weight_kg != nil })?.weight_kg
        let estimate = session.profile.flatMap { BasalMetabolicRate.estimate(profile: $0, weightKg: currentWeight) }
        return FieldNotePanel(padding: 17) {
            HStack(spacing: 14) {
                Image(systemName: "flame")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(FieldNoteStyle.accent)
                    .frame(width: 42, height: 42)
                    .background(FieldNoteStyle.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    SectionEyebrow(text: "Estimated BMR")
                    if let estimate {
                        Text("\(Int(estimate.rounded())) kcal/day")
                            .font(.system(size: 22, weight: .medium, design: .monospaced))
                            .foregroundStyle(FieldNoteStyle.ink)
                    } else {
                        Text("Add age, height and a weigh-in")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(FieldNoteStyle.muted)
                    }
                }
                Spacer(minLength: 0)
            }
            Text("Resting energy estimate, not a calorie target or medical recommendation.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(FieldNoteStyle.muted)
                .padding(.top, 8)
        }
    }

    private var trendCard: some View {
        FieldNotePanel(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionEyebrow(text: "Weight trend")
                    Spacer()
                    Text("\(trend.recentPoints.count) pts · \(trend.slopePerWeek.map { String(format: "%+.2f kg/wk", $0) } ?? "need more data")")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(FieldNoteStyle.muted)
                }
                if trend.recentPoints.isEmpty {
                    emptyChart("Add weigh-ins to see your trend.")
                } else {
                    Chart {
                        if let goal = session.profile?.goal_weight_kg {
                            RuleMark(y: .value("Goal", goal))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                .foregroundStyle(FieldNoteStyle.clay.opacity(0.8))
                        }
                        ForEach(trend.recentPoints) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Weight", point.value))
                                .foregroundStyle(FieldNoteStyle.ink.opacity(0.35))
                                .lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(x: .value("Date", point.date), y: .value("Weight", point.value))
                                .foregroundStyle(FieldNoteStyle.ink)
                                .symbolSize(42)
                        }
                        if trend.forecastPoints.count == 2 {
                            ForEach(trend.forecastPoints) { point in
                                LineMark(x: .value("Date", point.date), y: .value("Forecast", point.value))
                                    .foregroundStyle(FieldNoteStyle.accent)
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                            }
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 165)
                    .overlay(alignment: .bottomLeading) {
                        SectionEyebrow(text: "DASHED · FORECAST", color: FieldNoteStyle.accent).padding(.bottom, 3)
                    }
                }
                FieldNoteStatus(text: forecastMessage)
            }
        }
    }

    private var forecastMessage: String {
        switch trend.status {
        case "on-track":
            if let date = trend.etaDate { return "At this pace, your goal is around \(date.formatted(.dateTime.month(.abbreviated).year()))." }
            return "At this pace, your goal is more than 3 years out."
        case "wrong-way": return "Your recent trend is moving away from your goal."
        case "flat": return "Your recent weight is holding steady. Keep logging to see the pattern."
        case "reached": return "You’ve reached your current goal."
        case "no-goal": return "Set a goal weight in settings to see a forecast."
        default: return "Add a couple of weigh-ins to estimate your trend."
        }
    }

    private var bodyFatCard: some View {
        let tape = session.dashboardData?.latest_measurement_entry ?? latest
        let fat = bodyFatOf(tape, profile: session.profile)
        return FieldNotePanel(padding: 18) {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    SectionEyebrow(text: "Body fat · Navy")
                    Spacer()
                    Text(tape?.waist_cm == nil || tape?.neck_cm == nil ? "no tape yet" : "US Navy")
                        .font(.system(size: 10, weight: .regular, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
                }
                HStack(spacing: 14) {
                    FieldNoteMetric(title: "Waist", value: tape?.waist_cm.map { "\(String(format: "%.1f", $0)) cm" } ?? "—")
                    FieldNoteMetric(title: "Neck", value: tape?.neck_cm.map { "\(String(format: "%.1f", $0)) cm" } ?? "—")
                    FieldNoteMetric(title: "Fat", value: fat.map { String(format: "%.1f%%", $0) } ?? "—", color: FieldNoteStyle.clay)
                }
                Capsule().fill(FieldNoteStyle.line).frame(height: 5)
            }
        }
    }

    private var progressPhotosCard: some View {
        FieldNotePanel(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionEyebrow(text: "Progress · side by side")
                    Spacer()
                    Text("PHOTOS").font(.system(size: 9, weight: .regular, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
                }
                HStack(spacing: 12) {
                    photoSlot(firstPhoto, label: "first")
                    photoSlot(latestPhoto, label: "latest")
                }
                HStack(spacing: 12) {
                    if let first = firstPhoto?.weight_kg, let latest = latestPhoto?.weight_kg {
                        Label("\(signed(latest - first)) kg", systemImage: "scalemass")
                    }
                    if let first = firstPhoto?.waist_cm, let latest = latestPhoto?.waist_cm {
                        Label("\(signed(latest - first)) cm waist", systemImage: "ruler")
                    }
                }
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(FieldNoteStyle.sage)
            }
        }
    }

    @ViewBuilder
    private func photoSlot(_ entry: Entry?, label: String) -> some View {
        VStack(spacing: 8) {
            if let path = entry?.photo_path {
                RemoteProgressPhoto(path: path).frame(height: 178).clipped().clipShape(RoundedRectangle(cornerRadius: 15))
            } else {
                PhotoPlaceholder().frame(height: 178)
            }
            HStack {
                Text(label)
                Spacer()
                if let entry { Text(displayDate(entry.entry_date)) }
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(FieldNoteStyle.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func insightPreview(_ text: String) -> some View {
        FieldNotePanel(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                SectionEyebrow(text: "AI insight", color: FieldNoteStyle.accent)
                Text(text).font(.system(size: 14, weight: .regular, design: .rounded)).lineSpacing(4).foregroundStyle(FieldNoteStyle.ink).lineLimit(3)
            }
        }
    }

    private func emptyChart(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .regular, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
            .frame(maxWidth: .infinity).frame(height: 145)
    }
}

func signed(_ value: Double, digits: Int = 1) -> String {
    let sign = value > 0 ? "+" : value < 0 ? "−" : "±"
    return "\(sign)\(String(format: "%.*f", digits, abs(value)))"
}

struct InlineMessage: View {
    let text: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.footnote).foregroundStyle(FieldNoteStyle.clay)
            if let retry { Button("Try again", action: retry).font(.footnote.weight(.semibold)).foregroundStyle(FieldNoteStyle.accent) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldNoteStyle.clay.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FieldNoteStyle.line, lineWidth: 1))
    }
}
