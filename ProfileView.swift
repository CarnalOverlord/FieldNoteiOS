import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
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
                Form {
                    Section {
                        TextField("Display name", text: $name)
                        Picker("Body profile", selection: $sex) {
                            Text("Female").tag("female")
                            Text("Male").tag("male")
                        }
                        numberField("Height", text: $height, unit: "cm")
                        numberField("Goal weight", text: $goal, unit: "kg")
                    } header: { Text("Your profile") } footer: { Text("Height and body profile are used for the optional US Navy body-fat estimate.") }

                    Section {
                        Label(session.profile?.display_name ?? "FieldNote account", systemImage: "checkmark.circle").foregroundStyle(FieldNoteStyle.ink)
                        Button {
                            busy = true
                            Task {
                                do {
                                    try await session.saveProfile(name: name, sex: sex, height: height, goal: goal)
                                    message = "Profile saved."
                                } catch { message = error.localizedDescription }
                                busy = false
                            }
                        } label: { HStack { Text("Save profile"); Spacer(); if busy { ProgressView() } }
                        }
                        .disabled(busy)
                        if let message { Text(message).font(.footnote).foregroundStyle(message == "Profile saved." ? FieldNoteStyle.ink : .red) }
                    }

                    Section {
                        Button(role: .destructive) { Task { await session.signOut() } } label: { Text("Sign out") }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: hydrate)
        }
    }

    private func numberField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
            Text(unit).font(.footnote).foregroundStyle(FieldNoteStyle.muted).frame(width: 25, alignment: .leading)
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
