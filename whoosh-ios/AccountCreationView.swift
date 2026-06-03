import SwiftUI

/// Account creation — the first screen after the splash. On-brand (lime accent,
/// black ink). The sign-up action is intentionally stubbed for now; the next
/// step wires it to Supabase. Field state and validation are real so the screen
/// behaves like the finished thing.
struct AccountCreationView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && !busy
    }

    var body: some View {
        VStack(spacing: 0) {
            // Brand header
            VStack(spacing: 12) {
                Image("WhooshBolt")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .foregroundStyle(Color.whooshInk)
                Text("Create your account")
                    .font(.title.bold())
                Text("Join Whoosh")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 64)
            .padding(.bottom, 36)

            // Form
            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password (8+ characters)", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: createAccount) {
                    Group {
                        if busy { ProgressView() }
                        else { Text("Create account").bold() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.whooshLime)
                    .foregroundStyle(Color.whooshInk)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(canSubmit ? 1 : 0.5)
                }
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button("Already have an account?  Sign in") {
                // TODO: route to a sign-in screen (next step).
            }
            .font(.footnote)
            .padding(.bottom, 24)
        }
    }

    private func createAccount() {
        // TODO: wire Supabase sign-up here (next step):
        //   try await SupabaseAuth.shared.signUpEmail(email, password: password)
        // then route into onboarding. For now this is a no-op stub.
        busy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { busy = false }
    }
}

#Preview {
    AccountCreationView()
}
