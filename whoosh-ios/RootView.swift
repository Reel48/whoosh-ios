import SwiftUI

/// Top-level router, driven by `AppModel`. The launch splash shows during
/// `.loading` (held ≥2s by `bootstrap()`), then the app routes by auth/onboarding
/// state. There is intentionally **no marketing/landing screen**.
struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            switch model.state {
            case .loading:
                SplashView().transition(.opacity)
            case .unauthenticated:
                AccountCreationView().transition(.opacity)
            case .onboarding:
                OnboardingView().transition(.opacity)
            case .home:
                HomeView().transition(.opacity)
            }
        }
        .task { await model.bootstrap() }
    }
}

#Preview {
    RootView().environmentObject(AppModel())
}
