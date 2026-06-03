import Foundation
import Security

/// A persisted auth session (Supabase GoTrue tokens), stored as a single JSON
/// item in the Keychain so it survives relaunches securely.
struct StoredSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    /// Unix epoch seconds when `accessToken` expires.
    let expiresAt: Double
}

/// Minimal Keychain-backed store for the session. One generic-password item.
enum TokenStore {
    private static let service = "com.reel48.whoosh.session"
    private static let account = "supabase-session"

    static func load() -> StoredSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let session = try? JSONDecoder().decode(StoredSession.self, from: data)
        else { return nil }
        return session
    }

    static func save(_ session: StoredSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
