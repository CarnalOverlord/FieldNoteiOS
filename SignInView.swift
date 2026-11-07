import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var busy = false

    var body: some View {
        ZStack {
            FieldNoteBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    brand
                        .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(isRegistering ? "Create your account" : "Welcome back")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(FieldNoteStyle.ink)
                        Text(isRegistering ? "Start with your email and a password." : "Sign in to continue your journal.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(FieldNoteStyle.muted)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        labeledField("EMAIL ADDRESS", icon: "envelope") {
                            TextField(
                                "you@example.com",
                                text: $email,
                                prompt: Text("you@example.com").foregroundColor(FieldNoteStyle.cardMuted)
                            )
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                        }

                        labeledField("PASSWORD", icon: "lock") {
                            SecureField(
                                isRegistering ? "At least 8 characters" : "Your password",
                                text: $password,
                                prompt: Text(isRegistering ? "At least 8 characters" : "Your password").foregroundColor(FieldNoteStyle.cardMuted)
                            )
                            .textContentType(isRegistering ? .newPassword : .password)
                            .submitLabel(.go)
                            .onSubmit(submit)
                        }
                        if isRegistering {
                            Text("Choose at least 8 characters.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(FieldNoteStyle.muted)
                                .padding(.leading, 2)
                                .padding(.top, -10)
                        }
                    }

                    if let message = session.errorMessage {
                        Text(message)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 1, green: 0.63, blue: 0.68))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: submit) {
                        HStack(spacing: 10) {
                            if busy { ProgressView().tint(.white) }
                            Text(isRegistering ? "Create account" : "Sign in")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(FieldNoteStyle.buttonGradient, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: FieldNoteStyle.violet.opacity(0.4), radius: 18, y: 6)
                    }
                    .disabled(busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                    .opacity(busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty ? 0.72 : 1)

                    Button {
                        isRegistering.toggle()
                        session.errorMessage = nil
                    } label: {
                        Group {
                            if isRegistering {
                                Text("Already have an account? ") + Text("Sign in").bold()
                            } else {
                                Text("New to FieldNote? ") + Text("Create an account").bold()
                            }
                        }
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(FieldNoteStyle.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .disabled(busy)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.clear)
        }
    }

    private var brand: some View {
        HStack(spacing: 13) {
            Image(systemName: "leaf")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(FieldNoteStyle.accent)
                .frame(width: 54, height: 54)
                .background(FieldNoteStyle.buttonGradient, in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(FieldNoteStyle.accent.opacity(0.45), lineWidth: 1))
                .shadow(color: FieldNoteStyle.violet.opacity(0.4), radius: 14, y: 5)
            Text("FieldNote")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(FieldNoteStyle.ink)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func labeledField<Field: View>(
        _ title: String,
        icon: String,
        @ViewBuilder field: () -> Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(FieldNoteStyle.ink.opacity(0.9))
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FieldNoteStyle.cardMuted)
                    .frame(width: 20)
                field()
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(FieldNoteStyle.cardInk)
                    .tint(FieldNoteStyle.violet)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .background(FieldNoteStyle.card, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(FieldNoteStyle.accent.opacity(0.36), lineWidth: 1))
        }
    }

    private func submit() {
        guard !busy else { return }
        busy = true
        Task {
            await session.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                register: isRegistering
            )
            busy = false
        }
    }
}
