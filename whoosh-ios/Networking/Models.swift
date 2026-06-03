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

// MARK: - Capital (wallet dashboard + ticker)

struct Dashboard: Decodable, Sendable {
    let allocation: Allocation
    let returns: Returns
    let positions: [Position]
    let balanceSeries: [BalancePoint]
    let dayChangeCents: Int?
}

struct Allocation: Decodable, Sendable {
    let cashCents: Int
    let investedValueCents: Int
    let openWagersCents: Int
    let totalEquityCents: Int
}

struct Returns: Decodable, Sendable {
    let totalReturnCents: Int
    let totalReturnFraction: Double
}

/// The API's EnrichedPosition (we model the fields the list renders).
struct Position: Decodable, Sendable, Identifiable {
    let symbol: String
    let shares: Double
    let marketValueCents: Int?
    let dayChangeCents: Int?
    var id: String { symbol }
}

struct BalancePoint: Decodable, Sendable, Identifiable {
    let day: String            // "yyyy-MM-dd"
    let balanceCents: Int
    var id: String { day }

    /// Parsed calendar date for the chart x-axis.
    var date: Date {
        BalancePoint.formatter.date(from: day) ?? Date()
    }
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

struct TickerQuote: Decodable, Sendable, Identifiable {
    let symbol: String
    let name: String
    let priceCents: Int
    let changePct: Double
    var id: String { symbol }
}

// MARK: - Wallet actions

struct LedgerEntry: Decodable, Sendable, Identifiable {
    let id: Int
    let amountCents: Int
    let kind: String
    let memo: String?
    let createdAt: String
}

struct TransferResult: Decodable, Sendable { let transferId: Int }
struct BonusResult: Decodable, Sendable { let claimed: Bool; let amountCents: Int; let streak: Int }
struct CheckoutURL: Decodable, Sendable { let url: String }

struct BuyWBBody: Encodable { let amount: Double }
struct TransferBody: Encodable { let recipient: String; let amount: Double; let memo: String? }

// MARK: - Investing

struct SearchResult: Decodable, Sendable, Identifiable {
    let symbol: String
    let name: String
    let kind: String          // "stock" | "crypto"
    var id: String { symbol }
}

struct Quote: Decodable, Sendable {
    let symbol: String
    let priceCents: Int
    let prevCloseCents: Int?
    var dayChangeCents: Int? {
        guard let prev = prevCloseCents else { return nil }
        return priceCents - prev
    }
}

struct InvestOrderResult: Decodable, Sendable { let orderId: Int; let totalCents: Int }

struct WatchEntry: Decodable, Sendable, Identifiable {
    let symbol: String
    let addedAt: String
    var id: String { symbol }
}

struct InvestOrderBody: Encodable {
    let symbol: String
    let side: String          // "buy" | "sell"
    let amount: Double?       // USD amount; or
    let shares: Double?       // explicit share count
}
struct WatchlistMutateBody: Encodable { let symbol: String; let action: String }  // add | remove

// MARK: - House bets / events

struct BetOutcome: Decodable, Sendable, Identifiable {
    let id: Int
    let label: String
    let oddsDecimal: Double
    let point: Double?
}

struct BetEvent: Decodable, Sendable, Identifiable {
    let id: Int
    let title: String
    let status: String
    let homeTeam: String?
    let awayTeam: String?
    let commenceTime: String?
    let outcomes: [BetOutcome]
}

struct UserWager: Decodable, Sendable, Identifiable {
    let id: Int
    let status: String         // open | won | lost | refunded
    let stakeCents: Int
    let payoutCents: Int
    let potentialCents: Int
    let outcomeLabel: String
    let event: EventBrief

    struct EventBrief: Decodable, Sendable { let title: String; let status: String }
}

struct PlaceWagerBody: Encodable { let eventId: Int; let outcomeId: Int; let stake: Double }
