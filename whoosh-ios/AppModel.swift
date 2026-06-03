import SwiftUI
import Combine

enum AppState: Equatable { case loading, unauthenticated, onboarding, home }

/// Owns auth + the API client and decides which screen to show. Encodes the
/// "skip the marketing page / force first-run onboarding" behavior.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: AppState = .loading
    @Published var currentUsername: String = ""

    let auth = SupabaseAuth()
    lazy var api = WhooshAPI(token: { [auth] in await auth.currentAccessToken() })
    lazy var realtime = RealtimeClient(token: { [auth] in await auth.currentAccessToken() })

    /// Initial launch: keep the splash up for at least 2s while we resolve where
    /// to go (sign-in / onboarding / home).
    func bootstrap() async {
        async let minimumSplash: Void = sleep2s()
        let resolved = await resolveState()
        await minimumSplash
        withAnimation(.easeInOut(duration: 0.4)) { state = resolved }
    }

    /// After a successful sign-up / sign-in.
    func didAuthenticate() async {
        let resolved = await resolveState()
        withAnimation { state = resolved }
    }

    func didFinishOnboarding() { withAnimation { state = .home } }

    func signOut() async {
        await auth.signOut()
        currentUsername = ""
        withAnimation { state = .unauthenticated }
    }

    private func resolveState() async -> AppState {
        guard await auth.hasSession() else { return .unauthenticated }
        do {
            let account = try await api.account()
            currentUsername = account.username
            return account.onboarded ? .home : .onboarding
        } catch let e as APIError where e.code == "unauthorized" {
            return .unauthenticated
        } catch {
            // Network hiccup: if we have a session, assume home rather than
            // bouncing the user out; screens refetch and surface their own errors.
            return await auth.hasSession() ? .home : .unauthenticated
        }
    }

    private func sleep2s() async { try? await Task.sleep(for: .seconds(2)) }
}
