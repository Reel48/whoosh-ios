import Foundation

/// Codable models mirroring `openapi/whoosh-v1.yaml`. Intentionally PARTIAL —
/// `JSONDecoder` ignores keys we don't declare, so we model only what the
/// screens render. The API returns camelCase, matching these names.

struct Envelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
    let error: APIErrorBody?
}

struct APIErrorBody: Decodable, Sendable {
    let code: String
    let message: String
}

struct Account: Decodable, Sendable {
    let id: String
    let username: String
    let avatarUrl: String?
    let onboarded: Bool
}

struct UsernameAvailability: Decodable, Sendable {
    let available: Bool
    let normalized: String
    let reason: String?
}

struct ProfileResult: Decodable, Sendable {
    let id: String
    let username: String
    let avatarUrl: String?
    let onboarded: Bool
}

struct AvatarResult: Decodable, Sendable {
    let avatarUrl: String
}

struct Home: Decodable, Sendable {
    let sections: [HomeSection]
    let topArticle: TopArticle?
}

struct HomeSection: Decodable, Sendable, Identifiable {
    let key: String
    let label: String
    let tagline: String
    let live: Bool
    var id: String { key }
}

struct TopArticle: Decodable, Sendable {
    let title: String
    let link: String
}

struct SetUsernameBody: Encodable { let username: String }
