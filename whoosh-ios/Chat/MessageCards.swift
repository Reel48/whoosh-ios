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
