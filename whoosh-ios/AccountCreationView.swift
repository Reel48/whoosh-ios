import SwiftUI

/// Account creation / sign-in — the first screen for signed-out users. Defaults
/// to sign-up ("create your account"); a toggle switches to sign-in. On success
/// the AppModel re-resolves: a brand-new user lands in onboarding.
struct AccountCreationView: View {
    @EnvironmentObject private var model: AppModel

    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var note: String?
    @State private var errorShake = 0

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && !busy
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image("WhooshBolt")
                        .renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 40, height: 40)
                    Image("WhooshWordmark")
                        .renderingMode(.template).resizable().scaledToFit()
                        .frame(height: 28)
                }
                .foregroundStyle(Color.whooshInk)
                .accessibilityLabel("Whoosh")
                Text(isSignUp ? "Create your account" : "Welcome back")
                    .font(.title.bold())
                Text(isSignUp ? "Join Whoosh" : "Sign in to Whoosh")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 64)
            .padding(.bottom, 36)

            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding().background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password (8+ characters)", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .padding().background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error { Text(error).foregroundStyle(.bad).font(.footnote) }
                if let note { Text(note).foregroundStyle(.secondary).font(.footnote) }

                Button {
                    Task { await submit() }
                } label: {
                    if busy { ProgressView().tint(Color.whooshInk) }
                    else { Text(isSignUp ? "Create account" : "Sign in") }
                }
                .buttonStyle(.primaryFill)
                .opacity(canSubmit ? 1 : 0.5)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 24)
            .shake(trigger: errorShake)

            Spacer()

            Button(isSignUp ? "Already have an account?  Sign in"
                            : "New here?  Create an account") {
                isSignUp.toggle(); error = nil; note = nil
            }
            .font(.footnote)
            .padding(.bottom, 24)
        }
    }

    private func submit() async {
        busy = true; error = nil; note = nil
        defer { busy = false }
        do {
            if isSignUp {
                let started = try await model.auth.signUp(email: email, password: password)
                guard started else {
                    note = "Check your email to confirm, then sign in."
                    isSignUp = false
                    return
                }
            } else {
                try await model.auth.signIn(email: email, password: password)
            }
            await model.didAuthenticate()
        } catch {
            self.error = error.localizedDescription
            errorShake += 1
            Haptics.warning()
        }
    }
}

#Preview {
    AccountCreationView().environmentObject(AppModel())
}
