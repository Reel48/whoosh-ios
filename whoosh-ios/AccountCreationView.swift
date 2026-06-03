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

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && !busy
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image("WhooshBolt")
                    .renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 56, height: 56)
                    .foregroundStyle(Color.whooshInk)
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

                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                if let note { Text(note).foregroundStyle(.secondary).font(.footnote) }

                Button(action: { Task { await submit() } }) {
                    Group {
                        if busy { ProgressView() }
                        else { Text(isSignUp ? "Create account" : "Sign in").bold() }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.whooshLime)
                    .foregroundStyle(Color.whooshInk)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(canSubmit ? 1 : 0.5)
                }
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 24)

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
        }
    }
}

#Preview {
    AccountCreationView().environmentObject(AppModel())
}
