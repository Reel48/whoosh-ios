import SwiftUI

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
                Image(systemName: "chart.line.uptrend.xyaxis").font(.subheadline.bold())
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
