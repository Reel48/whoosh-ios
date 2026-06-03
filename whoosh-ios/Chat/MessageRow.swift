import SwiftUI

/// A single chat message, Discord-style (flat, not bubbles). The first message
/// in a run from an author shows the avatar + name + level + time; consecutive
/// messages (`showsHeader == false`) hide that and indent under the gutter.
struct MessageRow: View {
    let message: ChatMessage
    var showsHeader: Bool = true
    var onReact: (String) -> Void
    var canEdit: Bool = false
    var onEdit: () -> Void = {}
    var canDelete: Bool = false
    var onDelete: () -> Void = {}

    private let gutter: CGFloat = 44

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if showsHeader {
                ChatAvatar(url: message.author.avatarUrl, size: 36)
            } else {
                Color.clear.frame(width: 36, height: 1)
            }
            VStack(alignment: .leading, spacing: 3) {
                if showsHeader {
                    HStack(spacing: 6) {
                        Text(message.author.username)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: message.author.roleColor))
                        Text("lvl \(message.author.level)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                        Text(ChatTime.timeOfDay(message.createdAt)).font(.caption2).foregroundStyle(.tertiary)
                        if message.editedAt != nil { Text("(edited)").font(.caption2).foregroundStyle(.tertiary) }
                    }
                }
                if !message.body.isEmpty {
                    Text(Self.styledBody(message.body)).font(.body).tint(Color.whooshGreen)
                }
                if let link = Self.firstLink(in: message.body) {
                    LinkPreview(url: link)
                }
                if let urlStr = message.imageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                        Color(.secondarySystemBackground)
                    }
                    .frame(maxWidth: 240, maxHeight: 240).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if !message.reactions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.reactions) { r in
                            Button { onReact(r.emoji) } label: {
                                Text("\(r.emoji) \(r.count)")
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(r.mine ? Color.whooshLime.opacity(0.30) : Color(.secondarySystemBackground), in: Capsule())
                                    .overlay(Capsule().stroke(r.mine ? Color.whooshGreen.opacity(0.5) : .clear, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, showsHeader ? 6 : 1)
        .contentShape(Rectangle())
        .contextMenu {
            Button { onReact("⭐") } label: { Label("Star", systemImage: "star") }
            Button { onReact("🔥") } label: { Label("🔥", systemImage: "flame") }
            Button { onReact("😂") } label: { Label("😂", systemImage: "face.smiling") }
            Button { onReact("👍") } label: { Label("👍", systemImage: "hand.thumbsup") }
            if canEdit { Button { onEdit() } label: { Label("Edit", systemImage: "pencil") } }
            if canDelete { Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") } }
        }
    }

    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private static let mentionRegex = try? NSRegularExpression(pattern: "@[A-Za-z0-9_]{3,20}")

    private enum Token { case link(URL), mention }

    /// Build the message body as an `AttributedString`, tinting `@mentions` and
    /// turning URLs into tappable `.link` runs (links open via the system). Done
    /// by concatenating styled segments — no String↔AttributedString index
    /// casting, and link ranges take precedence over overlapping mentions.
    private static func styledBody(_ text: String) -> AttributedString {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var tokens: [(NSRange, Token)] = []
        linkDetector?.matches(in: text, range: full).forEach { m in
            if let u = m.url { tokens.append((m.range, .link(u))) }
        }
        mentionRegex?.matches(in: text, range: full).forEach { tokens.append(($0.range, .mention)) }
        guard !tokens.isEmpty else { return AttributedString(text) }
        tokens.sort { $0.0.location < $1.0.location }

        var result = AttributedString()
        var idx = 0
        for (range, token) in tokens {
            if range.location < idx { continue } // skip overlap (link already consumed it)
            if range.location > idx {
                result += AttributedString(ns.substring(with: NSRange(location: idx, length: range.location - idx)))
            }
            var seg = AttributedString(ns.substring(with: range))
            switch token {
            case .link(let u):
                seg.link = u
                seg.foregroundColor = Color.whooshGreen
            case .mention:
                seg.foregroundColor = Color.whooshGreen
                seg.font = .body.weight(.semibold)
            }
            result += seg
            idx = range.location + range.length
        }
        if idx < ns.length { result += AttributedString(ns.substring(from: idx)) }
        return result
    }

    /// The first URL in the message body, for the rich preview card.
    static func firstLink(in text: String) -> URL? {
        let ns = text as NSString
        return linkDetector?.firstMatch(in: text, range: NSRange(location: 0, length: ns.length))?.url
    }
}

/// Round avatar with an SF-symbol fallback.
struct ChatAvatar: View {
    let url: String?
    var size: CGFloat = 36
    var body: some View {
        Group {
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: {
                    Color(.secondarySystemBackground)
                }
            } else {
                ZStack { Color(.secondarySystemBackground); Image(systemName: "person.fill").foregroundStyle(.secondary) }
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
    }
}

/// Robust ISO8601 parsing (with/without fractional seconds) + chat formatting.
enum ChatTime {
    private static let withFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()

    static func date(_ s: String) -> Date? { withFrac.date(from: s) ?? plain.date(from: s) }

    static func timeOfDay(_ iso: String) -> String {
        guard let d = date(iso) else { return "" }
        return d.formatted(date: .omitted, time: .shortened)
    }

    /// "Today" / "Yesterday" / "Mon, Jun 3" for a day divider.
    static func dayLabel(_ iso: String) -> String {
        guard let d = date(iso) else { return "" }
        if Calendar.current.isDateInToday(d) { return "Today" }
        if Calendar.current.isDateInYesterday(d) { return "Yesterday" }
        return d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
