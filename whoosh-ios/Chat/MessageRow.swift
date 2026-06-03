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
                    Text(Self.styledBody(message.body)).font(.body)
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

    /// Tint `@mentions` in the brand green by concatenating styled segments
    /// (no String↔AttributedString index casting).
    private static func styledBody(_ text: String) -> AttributedString {
        guard let re = try? NSRegularExpression(pattern: "@[A-Za-z0-9_]{3,20}") else { return AttributedString(text) }
        let ns = text as NSString
        let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return AttributedString(text) }
        var result = AttributedString()
        var idx = 0
        for m in matches {
            if m.range.location > idx {
                result += AttributedString(ns.substring(with: NSRange(location: idx, length: m.range.location - idx)))
            }
            var mention = AttributedString(ns.substring(with: m.range))
            mention.foregroundColor = Color.whooshGreen
            mention.font = .body.weight(.semibold)
            result += mention
            idx = m.range.location + m.range.length
        }
        if idx < ns.length { result += AttributedString(ns.substring(from: idx)) }
        return result
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
