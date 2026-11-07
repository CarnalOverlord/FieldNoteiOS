import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedEntry: Entry?

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                if session.entries.isEmpty {
                    ContentUnavailableView("Your journal is waiting", systemImage: "book.closed", description: Text("Add a check-in to begin seeing your progress over time."))
                } else {
                    List(session.entries) { entry in
                        Button { selectedEntry = entry } label: {
                            HStack(spacing: 14) {
                                VStack(spacing: 2) {
                                Text(day(entry.entry_date)).font(.system(size: 20, weight: .medium, design: .rounded))
                                    Text(month(entry.entry_date)).font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1)
                                }
                                    .foregroundStyle(FieldNoteStyle.violet).frame(width: 48)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.weight_kg.map { String(format: "%.1f kg", $0) } ?? "Measurement entry")
                                        .font(.system(size: 16, weight: .medium, design: .rounded)).foregroundStyle(FieldNoteStyle.cardInk)
                                    Text(summary(entry)).font(.system(size: 11, weight: .regular, design: .rounded)).foregroundStyle(FieldNoteStyle.cardMuted).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(FieldNoteStyle.cardMuted)
                            }
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(FieldNoteStyle.card)
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable { await session.loadDashboard() }
                }
            }
            .navigationTitle("Your journal")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedEntry) { EntryDetailView(entry: $0) }
        }
    }

    private func day(_ date: String) -> String { String(date.suffix(2)) }
    private func month(_ date: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: date) else { return "" }
        f.dateFormat = "MMM"; return f.string(from: d).uppercased()
    }
    private func summary(_ entry: Entry) -> String {
        let values = [("Waist", entry.waist_cm), ("Hip", entry.hip_cm), ("Chest", entry.chest_cm), ("Arm", entry.arm_cm), ("Thigh", entry.thigh_cm), ("Body fat", entry.body_fat_pct)]
            .compactMap { pair -> String? in
                let (name, value) = pair
                guard let value else { return nil }
                return "\(name) \(String(format: "%.1f", value))\(name == "Body fat" ? "%" : " cm")"
            }
        return values.isEmpty ? (entry.notes ?? "A check-in, kept simple") : values.joined(separator: " · ")
    }
}

private struct EntryDetailView: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(displayDate(entry.entry_date)).font(.system(size: 30, weight: .medium, design: .rounded)).foregroundStyle(FieldNoteStyle.ink)
                        if let weight = entry.weight_kg { Text(String(format: "%.1f kg", weight)).font(.system(size: 42, weight: .regular, design: .rounded)).foregroundStyle(FieldNoteStyle.ink) }
                        if let path = entry.photo_path { RemoteProgressPhoto(path: path).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 18)) }
                        VStack(spacing: 0) {
                            detailRow("Neck", entry.neck_cm)
                            detailRow("Waist", entry.waist_cm)
                            detailRow("Hip", entry.hip_cm)
                            detailRow("Chest", entry.chest_cm)
                            detailRow("Arm", entry.arm_cm)
                            detailRow("Thigh", entry.thigh_cm)
                            detailRow("Body fat", entry.body_fat_pct, suffix: "%")
                        }
                        .padding(16).background(FieldNoteStyle.card, in: RoundedRectangle(cornerRadius: 20))
                        if let notes = entry.notes, !notes.isEmpty {
                            Text(notes).font(.system(size: 16, design: .rounded)).lineSpacing(4).foregroundStyle(FieldNoteStyle.cardInk).padding(18).frame(maxWidth: .infinity, alignment: .leading).background(FieldNoteStyle.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
                        }
                        if let insight = entry.ai_insight, !insight.isEmpty {
                            Text(insight).font(.system(size: 15, design: .rounded)).lineSpacing(4).padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.20, green: 0.13, blue: 0.46), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func detailRow(_ title: String, _ value: Double?, suffix: String = " cm") -> some View {
        HStack {
            Text(title).foregroundStyle(FieldNoteStyle.cardMuted)
            Spacer()
            Text(value.map { String(format: "%.1f%@", $0, suffix) } ?? "—").foregroundStyle(FieldNoteStyle.cardInk)
        }
        .font(.system(size: 14, weight: .regular, design: .rounded)).padding(.vertical, 9)
    }
}
