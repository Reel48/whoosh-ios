import SwiftUI

/// `/file` attachment card — a document (PDF/Excel/…). Shows a type icon, name,
/// and size; tapping opens it (QuickLook via the system).
struct FileCard: View {
    @Environment(\.openURL) private var openURL
    let message: ChatMessage

    private var url: URL? { (message.data?["url"]?.stringValue).flatMap(URL.init(string:)) }
    private var filename: String { message.data?["filename"]?.stringValue ?? "Attachment" }
    private var sizeBytes: Int { message.data?["sizeBytes"]?.intValue ?? 0 }
    private var icon: String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "xls", "xlsx", "csv": return "tablecells.fill"
        case "doc", "docx": return "doc.text.fill"
        case "ppt", "pptx": return "rectangle.on.rectangle.fill"
        default: return "doc.fill"
        }
    }
    private var sizeLabel: String {
        guard sizeBytes > 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }

    var body: some View {
        Button { if let url { openURL(url) } } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).foregroundStyle(Color.brandBlue)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(filename).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                    if !sizeLabel.isEmpty { Text(sizeLabel).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.down.circle").font(.body).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: 280, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

/// Cards for structured chat messages (`ChatMessage.kind` + `.data`). Each reads
/// the JSON payload defensively and degrades to the message `body` if a field is
/// missing — so a malformed or future-shaped payload never renders broken.

/// `/spoiler` — the text is hidden behind a redaction bar until tapped.
struct SpoilerCard: View {
    let message: ChatMessage
    @State private var revealed = false

    private var text: String { message.data?["text"]?.stringValue ?? "" }

    var body: some View {
        Group {
            if revealed {
                Text(text).font(.body)
                    .transition(.opacity)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash.fill").font(.caption)
                    Text("Spoiler — tap to reveal").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !text.isEmpty { withAnimation(Anim.quick) { revealed = true } } }
    }
}

/// `/stocks` — a compact quote card: symbol, price, and the day's change
/// (direction-tinted via the semantic palette). Tapping does nothing yet; the
/// snapshot is "as of" the time it was shared.
struct StockCard: View {
    let message: ChatMessage

    private var symbol: String { message.data?["symbol"]?.stringValue ?? "—" }
    private var priceCents: Int? { message.data?["priceCents"]?.intValue }
    private var prevCloseCents: Int? { message.data?["prevCloseCents"]?.intValue }
    private var changeCents: Int? {
        guard let p = priceCents, let prev = prevCloseCents else { return nil }
        return p - prev
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.brandBlue.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: "chart.line.uptrend.xyaxis").font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.brandBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol).font(.subheadline.weight(.bold))
                if let p = priceCents { Text(Money.wb(p)).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            if let c = changeCents, let prev = prevCloseCents, prev != 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(c >= 0 ? "▲" : "▼") \(Money.wb(abs(c)))")
                        .font(.caption.weight(.semibold))
                    Text(Money.percent(Double(c) / Double(prev)))
                        .font(.caption2)
                }
                .foregroundStyle(Money.tint(c))
            }
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
    }
}

/// A starboard message rendered as a swipe-deck card: author, the message
/// content, its image (if any), and the ⭐ count that earned its spot.
struct StarboardCard: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ChatAvatar(url: message.author.avatarUrl, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(message.author.username).font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: message.author.roleColor))
                    Label("\(message.starCount)", systemImage: "star.fill")
                        .font(.caption2.weight(.bold)).foregroundStyle(Color.brandOrange)
                }
                Spacer()
            }
            if !message.body.isEmpty {
                Text(message.body).font(.title3).foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let urlStr = message.imageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in img.resizable().scaledToFit() } placeholder: {
                    Color(.tertiarySystemBackground)
                }
                .frame(maxWidth: .infinity).frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

/// A welcome card auto-posted when a member finishes onboarding — the newcomer's
/// avatar + a greeting. Reactable like any message (the @mention notifies them).
struct WelcomeCard: View {
    let message: ChatMessage

    private var username: String { message.data?["username"]?.stringValue ?? "newcomer" }
    private var avatarUrl: String? { message.data?["avatarUrl"]?.stringValue }

    var body: some View {
        HStack(spacing: 12) {
            ChatAvatar(url: avatarUrl, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("🎉 New member!").font(.caption2.weight(.bold)).foregroundStyle(Color.brandLime)
                Text("Welcome @\(username)").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text("Say hi 👋").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: 300, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.brandBlue.opacity(0.14), Color.brandPurple.opacity(0.10)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandBlue.opacity(0.25), lineWidth: 0.5))
    }
}

/// `/poll` — an interactive poll. Each option shows a tappable row with a vote
/// bar + count; the viewer's picks are highlighted. Single- or multi-select per
/// the poll's `multi` flag. Counts come from `data.counts` (kept live by the
/// message UPDATE broadcast); the viewer's picks from `myPollVotes`.
struct PollCard: View {
    let message: ChatMessage
    var onVote: (String) -> Void

    private struct Option: Identifiable { let id: String; let text: String }

    private var question: String { message.data?["question"]?.stringValue ?? "Poll" }
    private var multi: Bool { message.data?["multi"]?.boolValue ?? false }
    private var options: [Option] {
        (message.data?["options"]?.arrayValue ?? []).compactMap { o in
            guard let id = o["id"]?.stringValue, let t = o["text"]?.stringValue else { return nil }
            return Option(id: id, text: t)
        }
    }
    private func count(_ id: String) -> Int { message.data?["counts"]?[id]?.intValue ?? 0 }
    private var total: Int { options.reduce(0) { $0 + count($1.id) } }
    private func mine(_ id: String) -> Bool { message.pollVotes.contains(id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill").font(.caption).foregroundStyle(Color.brandBlue)
                Text(question).font(.subheadline.weight(.bold))
            }
            ForEach(options) { opt in
                let n = count(opt.id)
                let frac = total > 0 ? Double(n) / Double(total) : 0
                Button { Haptics.tap(); onVote(opt.id) } label: {
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(mine(opt.id) ? Color.brandBlue.opacity(0.25) : Color(.tertiarySystemBackground))
                                .frame(width: max(geo.size.width * frac, 0))
                                .frame(maxHeight: .infinity)
                        }
                        HStack {
                            if mine(opt.id) {
                                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.brandBlue)
                            }
                            Text(opt.text).font(.subheadline).foregroundStyle(.primary)
                            Spacer()
                            Text("\(n)").font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                    }
                    .frame(minHeight: 36)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            Text("\(total) vote\(total == 1 ? "" : "s")\(multi ? " · pick any" : "")")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: 300, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
    }
}

/// `/bets` — a shared game with a couple of moneyline odds. Tapping deep-links
/// to the Bet page (switches to the Capital tab and focuses the game).
struct BetCard: View {
    @EnvironmentObject private var model: AppModel
    let message: ChatMessage

    private var gameKey: String? { message.data?["gameKey"]?.stringValue }
    private var matchup: String { message.data?["matchup"]?.stringValue ?? "Game" }
    private var sportKey: String? { message.data?["sportKey"]?.stringValue }
    private var outcomes: [(label: String, odds: Double)] {
        (message.data?["outcomes"]?.arrayValue ?? []).compactMap { o in
            guard let l = o["label"]?.stringValue, let d = o["odds"]?.doubleValue else { return nil }
            return (l, d)
        }
    }

    var body: some View {
        Button {
            guard let key = gameKey else { return }
            Haptics.tap()
            model.openBet(gameKey: key)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "dice.fill").font(.caption).foregroundStyle(Color.brandOrange)
                    Text(matchup).font(.subheadline.weight(.bold)).foregroundStyle(.primary).lineLimit(2)
                }
                if !outcomes.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(outcomes.enumerated()), id: \.offset) { _, o in
                            HStack(spacing: 4) {
                                Text(o.label).lineLimit(1)
                                Text(String(format: "%.2f×", o.odds)).fontWeight(.semibold).foregroundStyle(Color.brandBlue)
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                        }
                    }
                }
                HStack(spacing: 4) {
                    Text(BetMarketCatalog.sportTitle(sportKey)).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Open in Bets").font(.caption2.weight(.semibold)).foregroundStyle(Color.brandBlue)
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.brandBlue)
                }
            }
            .padding(12)
            .frame(maxWidth: 300, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
