import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var sex = "female"
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
                                Text("Used for the optional US Navy body-fat estimate and your weight trend forecast.")
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
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(FieldNoteStyle.muted)
    }

    private func save() {
        busy = true
        message = nil
        Task {
            do { try await session.saveProfile(name: name, sex: sex, height: height, goal: goal); message = "Profile saved." }
            catch { message = error.localizedDescription }
            busy = false
        }
    }

    private func hydrate() {
        guard let profile = session.profile else { return }
        name = profile.display_name ?? ""
        sex = profile.sex
        height = profile.height_cm.map { String($0) } ?? ""
        goal = profile.goal_weight_kg.map { String($0) } ?? ""
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
