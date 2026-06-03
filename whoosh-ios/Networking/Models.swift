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
struct BonusStatus: Decodable, Sendable { let available: Bool; let streak: Int }
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

// Stock detail (GET /wb/symbol)
struct Candle: Decodable, Sendable, Identifiable {
    let time: Int            // unix epoch seconds
    let closeCents: Int
    var id: Int { time }
    var date: Date { Date(timeIntervalSince1970: Double(time)) }
}

struct StockSnapshot: Decodable, Sendable {
    let symbol: String
    let longName: String?
    let exchange: String?
    let regularMarketPriceCents: Int?
    let regularMarketDayHighCents: Int?
    let regularMarketDayLowCents: Int?
    let fiftyTwoWeekHighCents: Int?
    let fiftyTwoWeekLowCents: Int?
    let regularMarketVolume: Int?
    let candles: [Candle]
}

struct CompanyProfile: Decodable, Sendable {
    let symbol: String
    let name: String
    let industry: String?
    let exchange: String?
    let marketCap: Double?       // dollars
    let logoUrl: String?
}

struct SymbolDetail: Decodable, Sendable {
    let snapshot: StockSnapshot
    let profile: CompanyProfile?
    let quote: Quote?
}

struct Order: Decodable, Sendable, Identifiable {
    let id: Int
    let symbol: String
    let side: String
    let shares: Double
    let priceCents: Int
    let totalCents: Int
    let createdAt: String
}

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
    /// Shared across a game's markets (Moneyline/Spread/Total) when synced.
    let externalEventId: String?
    let sportKey: String?
    let market: String?            // "h2h" | "spreads" | "totals"
}

/// A game = one matchup with its markets grouped (mirrors the web's `groupSyncedByGame`).
struct BetGame: Identifiable {
    let key: String
    let matchup: String
    let sportKey: String?
    let commenceTime: String?
    let markets: [BetEvent]        // ordered Moneyline → Spread → Total
    var id: String { key }
}

enum BetMarketCatalog {
    static func label(_ market: String?) -> String {
        switch market {
        case "h2h": return "Moneyline"
        case "spreads": return "Spread"
        case "totals": return "Total"
        default: return "Bet"
        }
    }
    static let order = ["h2h", "spreads", "totals"]
    static let sportTitles: [String: String] = [
        "americanfootball_nfl": "NFL",
        "americanfootball_ncaaf": "College Football",
        "basketball_nba": "NBA",
        "baseball_mlb": "MLB",
        "soccer_epl": "Premier League",
        "soccer_uefa_champs_league": "Champions League",
    ]
    static func sportTitle(_ key: String?) -> String {
        guard let key else { return "Sports" }
        return sportTitles[key] ?? key
    }

    /// Fold per-market events into games, markets ordered ML→spread→total, games by time.
    static func groupByGame(_ events: [BetEvent]) -> [BetGame] {
        var byGame: [String: [BetEvent]] = [:]
        var keyOrder: [String] = []
        for e in events {
            let key = e.externalEventId ?? String(e.id)
            if byGame[key] == nil { keyOrder.append(key) }
            byGame[key, default: []].append(e)
        }
        let games = keyOrder.map { key -> BetGame in
            let markets = byGame[key]!.sorted {
                (order.firstIndex(of: $0.market ?? "h2h") ?? 0) < (order.firstIndex(of: $1.market ?? "h2h") ?? 0)
            }
            let first = markets[0]
            return BetGame(key: key, matchup: first.title, sportKey: first.sportKey,
                           commenceTime: first.commenceTime, markets: markets)
        }
        return games.sorted { ($0.commenceTime ?? "~") < ($1.commenceTime ?? "~") }
    }
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

// MARK: - News

struct Article: Decodable, Sendable, Identifiable {
    let title: String
    let description: String
    let link: String
    let pubDate: String?
    let author: String?
    let guid: String
    let images: [String]
    var id: String { guid }
    var imageUrl: String? { images.first }
}

struct WhooshEntry: Decodable, Sendable, Identifiable {
    let espnId: String
    let sport: String
    let title: String
    let description: String?
    let link: String
    let author: String?
    let imageUrl: String?
    let pubDate: String?
    let points: Int
    var id: String { espnId }
}

/// GET /api/v1/news/feed — `mode` discriminates whoosh-feed vs sport deck.
struct NewsFeed: Decodable, Sendable {
    let mode: String                 // "whoosh" | "sport"
    let entries: [WhooshEntry]?      // whoosh
    let sport: String?               // sport
    let articles: [Article]?         // sport
}

/// POST /api/v1/news/swipe body.
struct SwipeBody: Encodable {
    let action: String               // "swipe" | "undo"
    let sport: String?
    let direction: String?           // "left" | "right"
    let guid: String?
    let article: ArticlePayload?
    struct ArticlePayload: Encodable {
        let guid: String; let title: String; let description: String
        let link: String; let author: String?; let image: String?; let pubDate: String?
    }
}

/// The catalog of sports for the swipe-deck picker (mirrors the web SPORTS).
struct NewsSport: Identifiable, Hashable { let key: String; let label: String; var id: String { key } }
enum NewsCatalog {
    static let sports: [NewsSport] = [
        .init(key: "nfl", label: "NFL"),
        .init(key: "nba", label: "NBA"),
        .init(key: "mlb", label: "MLB"),
        .init(key: "nhl", label: "NHL"),
        .init(key: "ncf", label: "CFB"),
        .init(key: "ncb", label: "CBB"),
        .init(key: "soccer", label: "Soccer"),
        .init(key: "golf", label: "Golf"),
        .init(key: "tennis", label: "Tennis"),
        .init(key: "mma", label: "UFC/MMA"),
        .init(key: "boxing", label: "Boxing"),
        .init(key: "racing", label: "Racing"),
    ]
}
