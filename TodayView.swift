import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if let error = session.errorMessage { InlineMessage(text: error, retry: { Task { await session.loadDashboard() } }) }
                        if let summary = session.dashboardData {
                            progressCard(summary)
                            quickStats(summary)
                            insightCard(summary)
                            recentSection
                        } else if session.errorMessage == nil {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await session.loadDashboard() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEditor) { EntryEditorView(date: Date()) }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).tracking(1.5).foregroundStyle(FieldNoteStyle.muted)
                Text("Today, gently.").font(.system(size: 30, weight: .medium, design: .serif)).foregroundStyle(FieldNoteStyle.ink)
            }
            Spacer()
            Button { showingEditor = true } label: {
                Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(FieldNoteStyle.paper)
                    .frame(width: 46, height: 46).background(FieldNoteStyle.accent, in: Circle())
                    .shadow(color: FieldNoteStyle.accent.opacity(0.48), radius: 16, y: 5)
            }
            .accessibilityLabel("Log today’s measurements")
        }
        .padding(.top, 10)
    }

    private func progressCard(_ summary: Dashboard) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("YOUR LATEST CHECK-IN", systemImage: "leaf")
                    .font(.system(size: 10, weight: .bold)).tracking(1.1).foregroundStyle(FieldNoteStyle.cardMuted)
                Spacer()
                if summary.weigh_in_due { Text("DUE TODAY").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(FieldNoteStyle.accent) }
            }
            if let entry = summary.latest_entry {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(entry.weight_kg.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—")
                        .font(.system(size: 55, weight: .regular, design: .serif)).foregroundStyle(FieldNoteStyle.cardInk)
                    Text("kg").font(.system(size: 17, weight: .medium)).foregroundStyle(FieldNoteStyle.cardMuted)
                    Spacer()
                    if let previous = summary.previous_entry?.weight_kg, let current = entry.weight_kg {
                        let delta = current - previous
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "%+.1f kg", delta)).font(.system(size: 13, weight: .semibold)).foregroundStyle(delta <= 0 ? FieldNoteStyle.cardInk : FieldNoteStyle.violet)
                            Text("since last time").font(.system(size: 10)).foregroundStyle(FieldNoteStyle.cardMuted)
                        }
                    }
                }
                HStack {
                    Text(displayDate(entry.entry_date)).font(.system(size: 12)).foregroundStyle(FieldNoteStyle.cardMuted)
                    Spacer()
                    if let goal = summary.profile.goal_weight_kg { Text("Goal  \(goal, specifier: "%.1f") kg").font(.system(size: 12, weight: .medium)).foregroundStyle(FieldNoteStyle.cardInk) }
                }
            } else {
                Text("Your first entry starts a useful little story.").font(.system(size: 19, design: .serif)).foregroundStyle(FieldNoteStyle.cardInk)
                Button("Log your first check-in") { showingEditor = true }.font(.subheadline.weight(.semibold)).foregroundStyle(FieldNoteStyle.violet)
            }
        }
        .padding(22)
        .background(FieldNoteStyle.card, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: FieldNoteStyle.violet.opacity(0.17), radius: 24, y: 12)
    }

    private func quickStats(_ summary: Dashboard) -> some View {
        let savedEstimate = summary.latest_entry?.body_fat_pct
        let calculatedEstimate = summary.latest_entry.flatMap { entry in
            session.profile.flatMap { NavyBodyFat.estimate(profile: $0, neck: entry.neck_cm, waist: entry.waist_cm, hip: entry.hip_cm) }
        }
        let bodyFat = savedEstimate ?? calculatedEstimate
        HStack(spacing: 12) {
            StatCard(title: "BODY FAT", value: bodyFat.map { String(format: "%.1f%%", $0) } ?? "—", detail: "US Navy estimate")
            StatCard(title: "TREND", value: String(format: "%+.1f", summary.forecast?.slope_per_week ?? 0), detail: "kg per week")
        }
    }

    private func insightCard(_ summary: Dashboard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("A NOTE TO YOURSELF", systemImage: "quote.opening").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(FieldNoteStyle.accent)
            if let insight = summary.profile.last_insight, !insight.isEmpty {
                Text(insight).font(.system(size: 15, design: .serif)).lineSpacing(4).foregroundStyle(FieldNoteStyle.ink)
            } else {
                Text("Small, steady check-ins make patterns easier to see over time.").font(.system(size: 16, design: .serif)).lineSpacing(4).foregroundStyle(FieldNoteStyle.ink)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.20, green: 0.13, blue: 0.46), Color(red: 0.12, green: 0.10, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent notes").font(.system(size: 21, weight: .medium, design: .serif)).foregroundStyle(FieldNoteStyle.ink)
                Spacer()
            }
            ForEach(session.entries.prefix(3)) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayDate(entry.entry_date)).font(.system(size: 13, weight: .medium)).foregroundStyle(FieldNoteStyle.ink)
                        Text(entry.notes?.isEmpty == false ? entry.notes! : "A check-in, kept simple").font(.system(size: 11)).foregroundStyle(FieldNoteStyle.muted).lineLimit(1)
                    }
                    Spacer()
                    Text(entry.weight_kg.map { String(format: "%.1f kg", $0) } ?? "Measurements")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(FieldNoteStyle.ink)
                }
                .padding(.vertical, 12)
                if entry.id != session.entries.prefix(3).last?.id { Divider().overlay(FieldNoteStyle.line) }
            }
            if session.entries.isEmpty { Text("Your journal will take shape here.").font(.subheadline).foregroundStyle(FieldNoteStyle.muted) }
        }
        .padding(.top, 4)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(FieldNoteStyle.cardMuted)
            Text(value).font(.system(size: 25, weight: .regular, design: .serif)).foregroundStyle(FieldNoteStyle.cardInk)
            Text(detail).font(.system(size: 10)).foregroundStyle(FieldNoteStyle.cardMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(17)
        .background(FieldNoteStyle.card, in: RoundedRectangle(cornerRadius: 19))
    }
}

struct InlineMessage: View {
    let text: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.footnote).foregroundStyle(.red)
            if let retry { Button("Try again", action: retry).font(.footnote.weight(.semibold)) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}
