import SwiftUI

/// House wagers: browse open events to bet on, and review your own bets.
struct BetsView: View {
    @EnvironmentObject private var model: AppModel

    private enum Tab: String, CaseIterable { case open = "Open", mine = "My Bets" }
    @State private var tab: Tab = .open
    @State private var events: [BetEvent] = []
    @State private var bets: [UserWager] = []
    @State private var selection: WagerSelection?
    @State private var loaded = false
    @State private var error: String?

    /// The (event, outcome) being wagered on — drives the sheet.
    struct WagerSelection: Identifiable {
        let event: BetEvent; let outcome: BetOutcome
        var id: Int { outcome.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).padding()

            List {
                if tab == .open { openEvents } else { myBets }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
        }
        .navigationTitle("House Bets")
        .task { if !loaded { await load(); loaded = true } }
        .refreshable { await load() }
        .sheet(item: $selection) { sel in
            PlaceWagerView(event: sel.event, outcome: sel.outcome,
                           onPlaced: { Task { await load() } })
        }
    }

    @ViewBuilder private var openEvents: some View {
        if events.isEmpty && loaded {
            ContentUnavailableView("No open events", systemImage: "dice")
        }
        ForEach(events) { event in
            Section(event.title) {
                ForEach(event.outcomes) { o in
                    Button { selection = WagerSelection(event: event, outcome: o) } label: {
                        HStack {
                            Text(o.label)
                            Spacer()
                            Text(String(format: "%.2f×", o.oddsDecimal))
                                .font(.callout.weight(.semibold)).foregroundStyle(Color.whooshGreen)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var myBets: some View {
        if bets.isEmpty && loaded {
            ContentUnavailableView("No bets yet", systemImage: "ticket")
        }
        ForEach(bets) { w in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.event.title).font(.body).lineLimit(1)
                    Text(w.outcomeLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(statusLabel(w)).font(.caption.bold()).foregroundStyle(statusColor(w.status))
                    Text("\(Money.wb(w.stakeCents)) → \(Money.wb(w.status == "open" ? w.potentialCents : w.payoutCents))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statusLabel(_ w: UserWager) -> String {
        switch w.status {
        case "open": return "OPEN"; case "won": return "WON"
        case "lost": return "LOST"; case "refunded": return "REFUNDED"
        default: return w.status.uppercased()
        }
    }
    private func statusColor(_ s: String) -> Color {
        switch s { case "won": return .whooshGreen; case "lost": return .red
        case "refunded": return .secondary; default: return .primary }
    }

    private func load() async {
        error = nil
        async let e = try? model.api.events()
        async let b = try? model.api.myBets()
        events = await e ?? []
        bets = await b ?? []
    }
}
