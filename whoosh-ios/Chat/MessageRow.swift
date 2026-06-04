import SwiftUI

/// A single chat message, Discord-style (flat, not bubbles). The first message
/// in a run from an author shows the avatar + name + level + time; consecutive
/// messages (`showsHeader == false`) hide that and indent under the gutter.
struct MessageRow: View {
    let message: ChatMessage
    var showsHeader: Bool = true
    var onReact: (String) -> Void
    var onVote: (String) -> Void = { _ in }
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
                contentBody
                if !message.reactions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.reactions) { r in
                            Button {
                                Haptics.impact(.light)
                                onReact(r.emoji)
                            } label: {
                                HStack(spacing: 3) {
                                    Text(r.emoji)
                                    Text("\(r.count)").contentTransition(.numericText(value: Double(r.count)))
                                }
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(r.mine ? Color.brandBlue.opacity(0.30) : Color(.secondarySystemBackground), in: Capsule())
                                .overlay(Capsule().stroke(r.mine ? Color.brandBlue.opacity(0.5) : .clear, lineWidth: 1))
                                .scaleEffect(r.mine ? 1.04 : 1)
                            }
                            .buttonStyle(.plain)
                            .animation(Anim.playful, value: r.mine)
                            .animation(Anim.playful, value: r.count)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
        }
        // Inter-message spacing is uniform via the list's LazyVStack(spacing:);
        // grouping is conveyed by the header, not by varying the gap.
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

    /// Dispatch on the message kind. Structured kinds render a dedicated card;
    /// everything else (and unknown kinds) falls back to the text/link/image body.
    @ViewBuilder private var contentBody: some View {
        switch message.messageKind {
        case "spoiler": SpoilerCard(message: message)
        case "stock": StockCard(message: message)
        case "bet": BetCard(message: message)
        case "poll": PollCard(message: message, onVote: onVote)
        case "file": FileCard(message: message)
        case "welcome": WelcomeCard(message: message)
        case "score": ScoreShareCard(message: message)
        case "gift": GiftCard(message: message)
        case "rank": RankCard(message: message)
        default: defaultContent
        }
    }

    @ViewBuilder private var defaultContent: some View {
        // The raw URL text is stripped from the body — only the rich embed
        // represents the link. Any surrounding text still shows.
        if !cleanedBody.isEmpty {
            Text(Self.styledMentions(cleanedBody)).font(.body)
        }
        if let link = Self.firstLink(in: message.body) {
            LinkPreview(url: link)
        }
        if let urlStr = message.imageUrl, let url = URL(string: urlStr) {
            if url.pathExtension.lowercased() == "gif" || message.messageKind == "gif" {
                AnimatedGIFView(url: url)
                    .frame(maxWidth: 240, maxHeight: 240).clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                    Color(.secondarySystemBackground)
                }
                .frame(maxWidth: 240, maxHeight: 240).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private static let mentionRegex = try? NSRegularExpression(pattern: "@[A-Za-z0-9_]{3,20}")

    /// The body with all URLs removed and leftover whitespace collapsed — links
    /// are represented solely by the embed, never as raw text.
    private var cleanedBody: String { Self.stripLinks(message.body) }

    private static func stripLinks(_ text: String) -> String {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let matches = linkDetector?.matches(in: text, range: full), !matches.isEmpty else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var out = ""
        var idx = 0
        for m in matches {
            if m.range.location > idx {
                out += ns.substring(with: NSRange(location: idx, length: m.range.location - idx))
            }
            idx = m.range.location + m.range.length
        }
        if idx < ns.length { out += ns.substring(from: idx) }
        // Collapse the gaps left behind by removed URLs.
        let collapsed = out.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Tint `@mentions` in the brand green (segment concatenation — no index casting).
    private static func styledMentions(_ text: String) -> AttributedString {
        guard let re = mentionRegex else { return AttributedString(text) }
        let ns = text as NSString
        let matches = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return AttributedString(text) }
        var result = AttributedString()
        var idx = 0
        for m in matches {
            if m.range.location > idx {
                result += AttributedString(ns.substring(with: NSRange(location: idx, length: m.range.location - idx)))
            }
            var seg = AttributedString(ns.substring(with: m.range))
            seg.foregroundColor = Color.whooshGreen
            seg.font = .body.weight(.semibold)
            result += seg
            idx = m.range.location + m.range.length
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
