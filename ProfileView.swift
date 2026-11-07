import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pushNotifications = PushNotificationManager.shared
    @State private var name = ""
    @State private var sex = "female"
    @State private var ageMode = "unset"
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var age = ""
    @State private var height = ""
    @State private var goal = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FieldNoteBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionEyebrow(text: "Settings")
                            Text("You").font(.system(size: 29, weight: .semibold, design: .rounded)).foregroundStyle(FieldNoteStyle.ink)
                            Text(session.profile?.display_name ?? "Your FieldNote profile")
                                .font(.system(size: 13, design: .monospaced)).foregroundStyle(FieldNoteStyle.muted)
                        }

                        FieldNotePanel(padding: 17) {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionEyebrow(text: "Body profile")
                                VStack(alignment: .leading, spacing: 7) {
                                    fieldLabel("Display name")
                                    TextField("Name", text: $name)
                                        .textContentType(.name).textInputAutocapitalization(.words)
                                        .profileInputStyle()
                                }
                                VStack(alignment: .leading, spacing: 7) {
                                    fieldLabel("Body profile · for body fat formula")
                                    Picker("Body profile", selection: $sex) {
                                        Text("Female").tag("female")
                                        Text("Male").tag("male")
                                    }
                                    .pickerStyle(.segmented)
                                    .tint(FieldNoteStyle.accent)
                                }
                                VStack(alignment: .leading, spacing: 9) {
                                    fieldLabel("Age · for BMR estimate")
                                    Picker("Age", selection: $ageMode) {
                                        Text("Not set").tag("unset")
                                        Text("Birth date").tag("birthdate")
                                        Text("Age only").tag("age")
                                    }
                                    .pickerStyle(.segmented)
                                    .tint(FieldNoteStyle.accent)
                                    if ageMode == "birthdate" {
                                        DatePicker("Date of birth", selection: $dateOfBirth, in: earliestAllowedBirthDate...latestAllowedBirthDate, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .tint(FieldNoteStyle.accent)
                                    } else if ageMode == "age" {
                                        HStack {
                                            Text("Age")
                                            Spacer()
                                            TextField("Years", text: $age).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90).profileInputStyle()
                                        }
                                    }
                                }
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 7) {
                                        fieldLabel("Height · cm")
                                        TextField("—", text: $height).keyboardType(.decimalPad).profileInputStyle()
                                    }
                                    VStack(alignment: .leading, spacing: 7) {
                                        fieldLabel("Goal · kg")
                                        TextField("—", text: $goal).keyboardType(.decimalPad).profileInputStyle()
                                    }
                                }
                                Text("Age, height, sex and your latest weight estimate resting energy use (BMR). This is not a calorie target. Height also supports the US Navy body-fat estimate.")
                                    .font(.system(size: 11, design: .monospaced)).lineSpacing(3).foregroundStyle(FieldNoteStyle.muted)
                                Button(action: save) {
                                    HStack { Spacer(); if busy { ProgressView().tint(FieldNoteStyle.paper) }; Text(busy ? "Saving…" : "Save"); Spacer() }
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(FieldNoteStyle.paper).padding(.vertical, 13)
                                        .background(FieldNoteStyle.buttonGradient, in: RoundedRectangle(cornerRadius: 15))
                                }
                                .buttonStyle(.plain).disabled(busy)
                                if let message {
                                    Text(message).font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(message == "Profile saved." ? FieldNoteStyle.sage : FieldNoteStyle.clay)
                                }
                            }
                        }

                        FieldNotePanel(padding: 17) {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionEyebrow(text: "Your data")
                                Text("Your check-ins, measurements, notes and progress photos are private to your account.")
                                    .font(.system(size: 13, design: .rounded)).lineSpacing(4).foregroundStyle(FieldNoteStyle.ink)
                            }
                        }

                        FieldNotePanel(padding: 17) {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionEyebrow(text: "Reminders")
                                Toggle(isOn: Binding(
                                    get: { pushNotifications.enabled },
                                    set: { value in Task { await pushNotifications.setEnabled(value) } }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Weekly check-in")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(FieldNoteStyle.ink)
                                        Text("A nudge to log your weight and measurements.")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(FieldNoteStyle.muted)
                                    }
                                }
                                .tint(FieldNoteStyle.accent)

                                Text(pushNotifications.message)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(FieldNoteStyle.muted)
                                    .fixedSize(horizontal: false, vertical: true)

                                if pushNotifications.requiresSettings {
                                    Button("Open iPhone Settings") {
                                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                        UIApplication.shared.open(url)
                                    }
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(FieldNoteStyle.accent)
                                }

                                if pushNotifications.enabled {
                                    Button {
                                        Task { await pushNotifications.sendTestReminder() }
                                    } label: {
                                        Text("Send test reminder")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(FieldNoteStyle.accent)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button(role: .destructive) { Task { await session.signOut(); dismiss() } } label: {
                            Text("Sign out")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(FieldNoteStyle.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 30)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(FieldNoteStyle.accent)
                }
            }
            .toolbarBackground(FieldNoteStyle.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear(perform: hydrate)
            .task { await pushNotifications.refreshAuthorization() }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(FieldNoteStyle.muted)
    }

    private func save() {
        if ageMode == "age", !age.isEmpty, let years = Int(age), !(13...120).contains(years) {
            message = "Enter an age from 13 to 120."
            return
        }
        if ageMode == "age", !age.isEmpty, Int(age) == nil {
            message = "Enter your age as a whole number."
            return
        }
        busy = true
        message = nil
        Task {
            let dob = ageMode == "birthdate" ? dateOfBirth.apiDateString : nil
            let manualAge = ageMode == "age" ? age : ""
            do { try await session.saveProfile(name: name, sex: sex, dateOfBirth: dob, age: manualAge, height: height, goal: goal); message = "Profile saved." }
            catch { message = error.localizedDescription }
            busy = false
        }
    }

    private func hydrate() {
        guard let profile = session.profile else { return }
        name = profile.display_name ?? ""
        sex = profile.sex
        if let dob = profile.date_of_birth, let parsed = entryDate(dob) {
            ageMode = "birthdate"
            dateOfBirth = parsed
        } else if let ageYears = profile.age_years {
            ageMode = "age"
            age = String(ageYears)
        }
        height = profile.height_cm.map { String($0) } ?? ""
        goal = profile.goal_weight_kg.map { String($0) } ?? ""
    }

    private var latestAllowedBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -13, to: .now) ?? .now
    }

    private var earliestAllowedBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -120, to: .now) ?? .distantPast
    }
}

private extension Date {
    var apiDateString: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", parts.year ?? 2000, parts.month ?? 1, parts.day ?? 1)
    }
}

private extension View {
    func profileInputStyle() -> some View {
        self.font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundStyle(FieldNoteStyle.ink)
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(FieldNoteStyle.paper, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(FieldNoteStyle.line, lineWidth: 1))
    }
}
