import Foundation

/// Fantasy domain models — partial Codable mirrors of the backend's
/// /api/v1/fantasy/* responses.

struct FantasyLink: Decodable, Sendable { let sleeperUserId: String; let sleeperUsername: String }

struct NflState: Decodable, Sendable {
    let week: Int
    let season: String
    let displayWeek: Int?
    enum CodingKeys: String, CodingKey { case week, season; case displayWeek = "display_week" }
    var label: String { "Week \(displayWeek ?? week)" }
}

struct FantasyLeagueConfig: Decodable, Sendable {
    let sleeperLeagueId: String
    let name: String?
    let kind: String                 // "standard" | "pickem" | "survivor"
    let entryFeeCents: Int?
    let joinUrl: String?
    let groupKey: String?
}

struct StandingRow: Decodable, Sendable, Identifiable {
    let rosterId: Int
    let ownerId: String?
    let teamName: String
    let ownerName: String
    let avatarUrl: String?
    let wins: Int
    let losses: Int
    let ties: Int
    let pointsFor: Double
    var id: Int { rosterId }
    var record: String { ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)" }
}

struct LeagueOverview: Decodable, Sendable, Identifiable {
    let config: FantasyLeagueConfig
    let displayName: String
    let season: String
    let avatarUrl: String?
    let totalRosters: Int
    let standings: [StandingRow]
    var id: String { config.sleeperLeagueId }
}

struct CrossLeagueRow: Decodable, Sendable, Identifiable {
    let rank: Int
    let rosterId: Int
    let teamName: String
    let ownerName: String
    let avatarUrl: String?
    let leagueId: String
    let leagueName: String
    let wins: Int
    let losses: Int
    let ties: Int
    let winPct: Double
    let pointsFor: Double
    let powerScore: Double
    var id: String { "\(leagueId)-\(rosterId)" }
    var record: String { ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)" }
}

struct CrossLeagueScoreboard: Decodable, Sendable {
    let rows: [CrossLeagueRow]
    let leagues: [LeagueRef]
    struct LeagueRef: Decodable, Sendable, Identifiable { let id: String; let name: String }
}

struct PoolSummary: Decodable, Sendable, Identifiable {
    let config: FantasyLeagueConfig
    let kind: String                 // "pickem" | "survivor"
    let displayName: String
    let logoUrl: String?
    let totalEntries: Int
    let aliveCount: Int?
    let sleeperUrl: String
    var id: String { config.sleeperLeagueId }
}

struct PoolEntry: Decodable, Sendable, Identifiable {
    let rosterId: Int
    let name: String
    let ownerName: String
    let avatarUrl: String?
    let eliminated: Bool?
    var id: Int { rosterId }
}

struct PoolDetail: Decodable, Sendable {
    let config: FantasyLeagueConfig
    let kind: String
    let displayName: String
    let logoUrl: String?
    let totalEntries: Int
    let aliveCount: Int?
    let season: String
    let status: String?
    let entries: [PoolEntry]
    let sleeperUrl: String
    /// Whether the signed-in user has paid into / joined this pool.
    let joined: Bool
    /// Best link to open the league in the Sleeper app (invite link, else public URL).
    var sleeperOpenURL: URL? { URL(string: config.joinUrl ?? sleeperUrl) }
}

struct MatchupTeam: Decodable, Sendable {
    let rosterId: Int
    let teamName: String
    let avatarUrl: String?
    let points: Double
    let isMine: Bool
}

struct Matchup: Decodable, Sendable, Identifiable {
    let matchupId: Int?
    let home: MatchupTeam
    let away: MatchupTeam?
    var id: Int { matchupId ?? home.rosterId }
}

// Responses

struct FantasyOverview: Decodable, Sendable {
    let state: NflState?
    let link: FantasyLink?
    let board: CrossLeagueScoreboard
    let pools: [PoolSummary]
    let leagues: [LeagueOverview]
}

struct LeagueDetailResponse: Decodable, Sendable {
    let overview: LeagueOverview
    let access: Bool
}

struct MatchupsResponse: Decodable, Sendable {
    let week: Int
    let blocks: [Block]
    struct Block: Decodable, Sendable, Identifiable {
        let leagueId: String
        let leagueName: String
        let season: String
        let matchups: [Matchup]
        var id: String { leagueId }
    }
}

struct LinkSleeperBody: Encodable { let username: String?; let action: String? }
struct FantasyCheckoutBody: Encodable { let groupKey: String }
