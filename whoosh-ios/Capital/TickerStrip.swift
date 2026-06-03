import SwiftUI

/// Horizontal market-quote strip (public data). Scrolls; each chip shows symbol
/// + price + day change %, color-coded.
struct TickerStrip: View {
    let quotes: [TickerQuote]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(quotes) { q in
                    HStack(spacing: 6) {
                        Text(q.symbol).font(.caption.bold())
                        Text(Money.wb(q.priceCents)).font(.caption).foregroundStyle(.secondary)
                        Text(Money.percent(q.changePct / 100))
                            .font(.caption2.bold())
                            .foregroundStyle(q.changePct >= 0 ? Color.whooshGreen : .red)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }
}
