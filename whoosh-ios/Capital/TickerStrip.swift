import SwiftUI

/// Auto-scrolling market-quote marquee (public data). The row is duplicated so
/// the leftward scroll loops seamlessly. The whole strip is bounded to the
/// container width via a fixed-height `GeometryReader` + clip, so its (wide)
/// content can never stretch the page layout.
struct TickerStrip: View {
    let quotes: [TickerQuote]
    private let spacing: CGFloat = 10
    private let speed: CGFloat = 40      // points per second
    private let height: CGFloat = 34

    @State private var offset: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: spacing) {
                row
                row
            }
            .fixedSize()                                  // natural (intrinsic) width
            .offset(x: offset)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { measure(g.size.width) }
                        .onChange(of: g.size.width) { _, w in measure(w) }
                }
            )
        }
        .frame(height: height)        // bounds the strip to container width × height
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
                        .foregroundStyle(q.changePct >= 0 ? Color.good : Color.bad)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }
        }
        .padding(.leading, spacing)
    }

    /// `width` is the doubled HStack's width → one row is (width - spacing) / 2.
    private func measure(_ width: CGFloat) {
        let single = (width - spacing) / 2
        guard single > 0, abs(single - rowWidth) > 0.5 else { return }
        rowWidth = single
        animate()
    }

    private func animate() {
        let distance = rowWidth + spacing
        offset = 0
        withAnimation(.linear(duration: Double(distance) / Double(speed)).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}
