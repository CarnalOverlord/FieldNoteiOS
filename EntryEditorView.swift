import SwiftUI

struct EntryEditorView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State var date: Date
    @State private var weight = ""
    @State private var neck = ""
    @State private var waist = ""
    @State private var hip = ""
    @State private var chest = ""
    @State private var arm = ""
    @State private var thigh = ""
    @State private var notes = ""
    @State private var busy = false
    @State private var error: String?

    init(date: Date) {
        _date = State(initialValue: date)
    }

    private var estimate: Double? {
        guard let profile = session.profile else { return nil }
        return NavyBodyFat.estimate(profile: profile, neck: parseMeasurement(neck), waist: parseMeasurement(waist), hip: parseMeasurement(hip))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                Form {
                    Section {
                        DatePicker("Entry date", selection: $date, displayedComponents: .date)
                        measurement("Weight", text: $weight, unit: "kg", symbol: "scalemass")
                    } header: { Text("The basics") }

                    Section {
                        measurement("Neck", text: $neck, unit: "cm")
                        measurement("Waist", text: $waist, unit: "cm")
                        if session.profile?.sex != "male" { measurement("Hip", text: $hip, unit: "cm") }
                        measurement("Chest", text: $chest, unit: "cm")
                        measurement("Arm", text: $arm, unit: "cm")
                        measurement("Thigh", text: $thigh, unit: "cm")
                        HStack {
                            Text("Body fat estimate")
                            Spacer()
                            Text(estimate.map { String(format: "%.1f%%", $0) } ?? "Add profile height")
                                .foregroundStyle(FieldNoteStyle.muted)
                        }
                    } header: { Text("Measurements") } footer: { Text("The US Navy estimate uses your profile height and circumference measurements.") }

                    Section {
                        TextField("Anything you want to remember?", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    } header: { Text("Note") }

                    if let error { Section { Text(error).font(.footnote).foregroundStyle(.red) } }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        busy = true
                        Task {
                            do {
                                try await session.save(date: date, weight: weight, neck: neck, waist: waist, hip: hip, chest: chest, arm: arm, thigh: thigh, notes: notes)
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    } label: { if busy { ProgressView() } else { Text("Save").fontWeight(.semibold) } }
                    .disabled(busy)
                }
            }
            .task { hydrateExistingEntry() }
        }
    }

    @ViewBuilder
    private func measurement(_ title: String, text: Binding<String>, unit: String, symbol: String? = nil) -> some View {
        HStack(spacing: 10) {
            if let symbol { Image(systemName: symbol).foregroundStyle(FieldNoteStyle.muted).frame(width: 18) }
            Text(title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit).font(.footnote).foregroundStyle(FieldNoteStyle.muted).frame(width: 22, alignment: .leading)
        }
    }

    private func hydrateExistingEntry() {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let target = String(format: "%04d-%02d-%02d", parts.year ?? 2000, parts.month ?? 1, parts.day ?? 1)
        guard let existing = session.entries.first(where: { $0.entry_date == target }) else { return }
        weight = existing.weight_kg.map { String($0) } ?? ""
        neck = existing.neck_cm.map { String($0) } ?? ""
        waist = existing.waist_cm.map { String($0) } ?? ""
        hip = existing.hip_cm.map { String($0) } ?? ""
        chest = existing.chest_cm.map { String($0) } ?? ""
        arm = existing.arm_cm.map { String($0) } ?? ""
        thigh = existing.thigh_cm.map { String($0) } ?? ""
        notes = existing.notes ?? ""
    }
}
