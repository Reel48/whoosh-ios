import Foundation

struct AuthError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Email auth against Supabase GoTrue's REST API (`/auth/v1/*`) — no SDK needed.
/// Persists the session in the Keychain and refreshes the access token on demand.
/// The Supabase Swift SDK can replace this later (e.g. for Sign in with Apple)
/// without touching the rest of the app.
actor SupabaseAuth {
    private var session: StoredSession?

    init() { session = TokenStore.load() }

    func hasSession() -> Bool { session != nil }

    /// A valid access token (the bearer the API client sends), refreshing if it's
    /// within 60s of expiry. Returns nil when signed out / refresh fails.
    func currentAccessToken() async -> String? {
        guard let s = session else { return nil }
        if s.expiresAt - Date().timeIntervalSince1970 > 60 { return s.accessToken }
        try? await refresh()
        return session?.accessToken
    }

    /// Sign up with email/password. Returns true if a session started immediately,
    /// false if email confirmation is required (no session yet).
    @discardableResult
    func signUp(email: String, password: String) async throws -> Bool {
        let body = try await post("/auth/v1/signup", json: ["email": email, "password": password])
        if let started = storeIfSession(body) { return started }
        return false
    }

    func signIn(email: String, password: String) async throws {
        let body = try await post("/auth/v1/token?grant_type=password",
                                  json: ["email": email, "password": password])
        guard storeIfSession(body) == true else {
            throw AuthError(message: "Sign-in did not return a session.")
        }
    }

    func signOut() async {
        if let token = session?.accessToken {
            _ = try? await post("/auth/v1/logout", json: [:], bearer: token)
        }
        session = nil
        TokenStore.clear()
    }

    // MARK: Internals

    private func refresh() async throws {
        guard let refreshToken = session?.refreshToken else { return }
        let body = try await post("/auth/v1/token?grant_type=refresh_token",
                                  json: ["refresh_token": refreshToken])
        _ = storeIfSession(body)
    }

    /// If the GoTrue body carries an access token, persist + cache it. Returns
    /// true if a session was stored, false if not, nil if the body wasn't a session.
    @discardableResult
    private func storeIfSession(_ data: Data) -> Bool? {
        struct Body: Decodable {
            let access_token: String?
            let refresh_token: String?
            let expires_at: Double?
        }
        guard let b = try? JSONDecoder().decode(Body.self, from: data) else { return nil }
        guard let access = b.access_token, let refresh = b.refresh_token else { return false }
        let stored = StoredSession(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: b.expires_at ?? (Date().timeIntervalSince1970 + 3600)
        )
        session = stored
        TokenStore.save(stored)
        return true
    }

    private func post(_ path: String, json: [String: String], bearer: String? = nil) async throws -> Data {
        guard let url = URL(string: path, relativeTo: Config.supabaseURL) else {
            throw AuthError(message: "Bad auth URL.")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: json)

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw AuthError(message: Self.parseError(data))
        }
        return data
    }

    private static func parseError(_ data: Data) -> String {
        struct E: Decodable {
            let error_description: String?
            let msg: String?
            let message: String?
            let error: String?
        }
        if let e = try? JSONDecoder().decode(E.self, from: data) {
            return e.error_description ?? e.msg ?? e.message ?? e.error ?? "Authentication failed."
        }
        return "Authentication failed."
    }
}
