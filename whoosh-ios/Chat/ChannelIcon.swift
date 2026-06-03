import Foundation

/// Per-channel emoji icons (client-side, mirroring the Discord server). Keyed by
/// slug with a `kind`-based fallback so new channels still get a sensible glyph.
enum ChannelIcon {
    private static let bySlug: [String: String] = [
        "welcome": "👋",
        "whoosh-philanthropy": "🌎",
        "xp-leaderboard": "🏆",
        "starboard": "⭐",
        "general": "💬",
        "announcements": "📢",
        "nfl-football": "🏈",
        "college-football": "🎓",
        "baseball": "⚾",
        "soccer": "⚽",
        "basketball": "🏀",
        "golf": "⛳",
        "fights": "🥊",
        "tennis": "🎾",
        "pic-of-the-day": "📸",
        "movies-tv": "🎬",
        "music": "🎵",
        "gaming": "🎮",
        "youtube-videos": "▶️",
        "health-fitness": "💪",
        "food-drinks": "🍔",
        "money-rankings": "💰",
        "premium": "💎",
        "sports-betting": "🎲",
        "business": "📈",
        "politics": "🏛️",
        "admin-chat": "🛠️",
        "payments": "💳",
        "security": "🔒",
    ]

    /// The emoji for a channel, falling back to its kind, then a hash glyph.
    static func emoji(slug: String, kind: String) -> String {
        if let e = bySlug[slug] { return e }
        switch kind {
        case "leaderboard": return "🏆"
        case "starboard": return "⭐"
        case "media": return "📸"
        default: return "#️⃣"
        }
    }
}
