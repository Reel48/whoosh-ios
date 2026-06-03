import SwiftUI

/// Auto-scrolling market-quote marquee (public data). The quote row is duplicated
/// so the leftward scroll loops seamlessly — no manual scrolling needed.
struct TickerStrip: View {
    let quotes: [TickerQuote]
    private let spacing: CGFloat = 10
    private let speed: CGFloat = 40   // points per second

    @State private var offset: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: spacing) {
            row
            row
        }
        .offset(x: offset)
        .background(alignment: .leading) {
            // Measure one row's width.
            row.hidden().background(
                GeometryReader { g in
                    Color.clear.preference(key: WidthKey.self, value: g.size.width)
                }
            )
        }
        .onPreferenceChange(WidthKey.self) { w in
            guard w > 0, w != rowWidth else { return }
            rowWidth = w
            animate()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var row: some View {
        HStack(spacing: spacing) {
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
        .padding(.horizontal, spacing)
    }

    private func animate() {
        let distance = rowWidth + spacing
        offset = 0
        withAnimation(.linear(duration: Double(distance) / Double(speed)).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }

    private struct WidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
}
