import Foundation

/// Per-channel SF Symbol icons (client-side), keyed by slug with a `kind`-based
/// fallback so new channels still get a sensible glyph.
enum ChannelIcon {
    private static let bySlug: [String: String] = [
        "welcome": "hand.wave.fill",
        "whoosh-philanthropy": "globe.americas.fill",
        "xp-leaderboard": "trophy.fill",
        "starboard": "star.fill",
        "general": "bubble.left.and.bubble.right.fill",
        "announcements": "megaphone.fill",
        "nfl-football": "football.fill",
        "college-football": "graduationcap.fill",
        "baseball": "baseball.fill",
        "soccer": "soccerball",
        "basketball": "basketball.fill",
        "golf": "figure.golf",
        "fights": "figure.boxing",
        "tennis": "tennisball.fill",
        "pic-of-the-day": "photo.fill",
        "movies-tv": "tv.fill",
        "music": "music.note",
        "gaming": "gamecontroller.fill",
        "youtube-videos": "play.rectangle.fill",
        "health-fitness": "figure.run",
        "food-drinks": "fork.knife",
        "money-rankings": "dollarsign.circle.fill",
        "premium": "crown.fill",
        "sports-betting": "dice.fill",
        "business": "chart.line.uptrend.xyaxis",
        "politics": "building.columns.fill",
        "admin-chat": "wrench.and.screwdriver.fill",
        "payments": "creditcard.fill",
        "security": "lock.shield.fill",
    ]

    /// The SF Symbol name for a channel, falling back to its kind, then `number`.
    static func symbol(slug: String, kind: String) -> String {
        if let s = bySlug[slug] { return s }
        switch kind {
        case "leaderboard": return "trophy.fill"
        case "starboard": return "star.fill"
        case "media": return "photo.fill"
        default: return "number"
        }
    }
}
