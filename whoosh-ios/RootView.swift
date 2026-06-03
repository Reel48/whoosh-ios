import SwiftUI

/// Top-level router. Shows the launch splash for ~2s, then cross-fades to the
/// account-creation screen. (Next step: this becomes session-aware — splash →
/// sign in / onboarding / home — once Supabase auth is wired in.)
struct RootView: View {
    private enum Phase { case splash, account }

    /// Total time the splash stays up before advancing.
    private let splashDuration: Duration = .seconds(2)

    @State private var phase: Phase = .splash

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .account:
                AccountCreationView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: splashDuration)
            withAnimation(.easeInOut(duration: 0.4)) { phase = .account }
        }
    }
}

#Preview {
    RootView()
}
