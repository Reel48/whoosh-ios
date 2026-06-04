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
    /// Selected sport filter on the Open tab; nil = All.
    @State private var sport: String? = nil

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

            if tab == .open { sportBar }

            List {
                if tab == .open { openEvents } else { myBets }
                if let error { Text(error).foregroundStyle(.bad).font(.footnote) }
            }
        }
        .navigationTitle("Bets")
        .task { if !loaded { await load(); loaded = true } }
        .refreshable { await load() }
        .sheet(item: $selection) { sel in
            PlaceWagerView(event: sel.event, outcome: sel.outcome,
                           onPlaced: { Task { await load() } })
        }
    }

    /// Open games grouped by sport; each game is one expandable card whose markets
    /// (Moneyline / Spread / Total) are consolidated under it.
    @ViewBuilder private var openEvents: some View {
        if events.isEmpty && loaded {
            ContentUnavailableView("No open games", systemImage: "dice")
        }
        ForEach(visibleSections, id: \.sport) { section in
            Section(BetMarketCatalog.sportTitle(section.sport)) {
                ForEach(section.games) { game in
                    GameCard(game: game) { event, outcome in
                        selection = WagerSelection(event: event, outcome: outcome)
                    }
                }
            }
        }
    }

    /// Horizontal sport selector (only when there's more than one sport open).
    @ViewBuilder private var sportBar: some View {
        let sections = sportSections
        if sections.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    sportChip("All", active: sport == nil) { sport = nil }
                    ForEach(sections.compactMap(\.sport), id: \.self) { s in
                        sportChip(BetMarketCatalog.sportTitle(s), active: sport == s) { sport = s }
                    }
                }
                .padding(.horizontal).padding(.bottom, 8)
            }
        }
    }

    private func sportChip(_ title: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Anim.snappy) { tap() }
        } label: {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(active ? Color.brandLime : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(active ? Color.whooshInk : .primary)
        }
        .buttonStyle(.plain)
    }

    /// Open sections filtered to the selected sport (all when nil).
    private var visibleSections: [(sport: String?, games: [BetGame])] {
        guard let sport else { return sportSections }
        return sportSections.filter { $0.sport == sport }
    }

    private var sportSections: [(sport: String?, games: [BetGame])] {
        let games = BetMarketCatalog.groupByGame(events)
        var order: [String?] = []
        var bySport: [String: [BetGame]] = [:]   // key "" for nil
        for g in games {
            let k = g.sportKey ?? ""
            if bySport[k] == nil { order.append(g.sportKey) }
            bySport[k, default: []].append(g)
        }
        return order.map { (sport: $0, games: bySport[$0 ?? ""] ?? []) }
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
        switch s { case "won": return .good; case "lost": return .bad
        case "open": return .warning; case "refunded": return .secondary; default: return .primary }
    }

    private func load() async {
        error = nil
        async let e = try? model.api.events()
        async let b = try? model.api.myBets()
        events = await e ?? []
        bets = await b ?? []
    }
}

/// One game, collapsed by default. Expanding reveals its markets (Moneyline /
/// Spread / Total), each with its tappable outcomes. Mirrors the web EventCard.
private struct GameCard: View {
    let game: BetGame
    var onPick: (BetEvent, BetOutcome) -> Void
    @State private var expanded = false

    private var multiMarket: Bool { game.markets.count > 1 }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(game.markets) { market in
                if multiMarket {
                    Text(BetMarketCatalog.label(market.market))
                        .font(.caption.bold()).foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                ForEach(market.outcomes) { o in
                    Button { onPick(market, o) } label: {
                        HStack {
                            Text(o.label + pointSuffix(o))
                            Spacer()
                            Text(String(format: "%.2f×", o.oddsDecimal))
                                .font(.callout.weight(.semibold)).foregroundStyle(Color.whooshGreen)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.matchup).font(.body.weight(.semibold)).lineLimit(2)
                HStack(spacing: 6) {
                    if let t = gameTime { Text(t) }
                    if multiMarket { Text("· \(game.markets.count) markets") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func pointSuffix(_ o: BetOutcome) -> String {
        guard let p = o.point else { return "" }
        return " \(p > 0 ? "+" : "")\(p.formatted(.number.precision(.fractionLength(0...1))))"
    }

    private var gameTime: String? {
        guard let iso = game.commenceTime,
              let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}
