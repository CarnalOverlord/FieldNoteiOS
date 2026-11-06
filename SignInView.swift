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
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Image(systemName: "leaf")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(FieldNoteStyle.accent)
                    .padding(16)
                    .background(FieldNoteStyle.buttonGradient, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(FieldNoteStyle.accent.opacity(0.45), lineWidth: 1))
                    .shadow(color: FieldNoteStyle.violet.opacity(0.45), radius: 18, y: 6)
                VStack(alignment: .leading, spacing: 8) {
                    Text("FieldNote").font(.system(size: 42, weight: .semibold, design: .serif)).foregroundStyle(FieldNoteStyle.ink)
                    Text("A quieter way to track your progress.").font(.system(size: 16)).foregroundStyle(FieldNoteStyle.muted)
                }
                VStack(spacing: 14) {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .fieldNoteInput()
                    SecureField("Password", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .fieldNoteInput()
                }
                if let message = session.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    busy = true
                    Task {
                        await session.signIn(email: email, password: password, register: isRegistering)
                        busy = false
                    }
                } label: {
                    HStack {
                        Spacer()
                        if busy { ProgressView().tint(.white) }
                        else { Text(isRegistering ? "Create account" : "Sign in").fontWeight(.semibold) }
                        Spacer()
                    }
                    .padding(.vertical, 17)
                    .foregroundStyle(.white)
                    .background(FieldNoteStyle.buttonGradient, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: FieldNoteStyle.violet.opacity(0.45), radius: 18, y: 6)
                }
                .disabled(busy || email.isEmpty || password.isEmpty)
                Button(isRegistering ? "Already have an account? Sign in" : "New to FieldNote? Create an account") {
                    isRegistering.toggle()
                    session.errorMessage = nil
                }
                .font(.subheadline.weight(.medium)).foregroundStyle(FieldNoteStyle.ink).frame(maxWidth: .infinity)
                if isRegistering { Text("Use at least 8 characters for your password.").font(.caption).foregroundStyle(FieldNoteStyle.muted).frame(maxWidth: .infinity) }
                Spacer()
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 460)
        }
    }
}

extension View {
    func fieldNoteInput() -> some View {
        self.padding(16)
            .foregroundStyle(FieldNoteStyle.cardInk)
            .background(FieldNoteStyle.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(FieldNoteStyle.accent.opacity(0.35), lineWidth: 1))
    }
}
