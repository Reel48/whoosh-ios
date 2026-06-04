import SwiftUI

/// Browse/search symbols and open one to trade. Empty search shows the
/// watchlist; typing searches stocks + crypto.
struct InvestView: View {
    @EnvironmentObject private var model: AppModel

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var watchlist: [WatchEntry] = []
    @State private var positions: [Position] = []
    @State private var orders: [Order] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            if query.isEmpty {
                if !positions.isEmpty {
                    Section("Your positions") {
                        ForEach(positions) { p in
                            NavigationLink(value: p.symbol) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(p.symbol).font(.ck(.body, .bold))
                                        Text("\(p.shares, specifier: "%.4g") shares").font(.ck(.caption)).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(Money.wb(p.marketValueCents ?? 0)).font(.ck(.body))
                                        if let day = p.dayChangeCents {
                                            Text(Money.wb(day, signed: true)).font(.ck(.caption)).foregroundStyle(Money.tint(day))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Section("Watchlist") {
                    if watchlist.isEmpty {
                        Text("Search to find symbols, then ★ to watch them.")
                            .font(.ck(.footnote)).foregroundStyle(.secondary)
                    }
                    ForEach(watchlist) { w in
                        NavigationLink(value: w.symbol) {
                            Label(w.symbol, systemImage: "star.fill").foregroundStyle(.primary)
                        }
                    }
                }
                if !orders.isEmpty {
                    Section("Recent orders") {
                        ForEach(orders) { o in
                            HStack {
                                Text(o.side.uppercased()).font(.ck(.caption, .bold))
                                    .foregroundStyle(o.side == "buy" ? Color.brandBlue : Color.brandOrange)
                                Text(o.symbol).font(.ck(.body))
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(Money.wb(o.totalCents)).font(.ck(.callout))
                                    Text("\(o.shares, specifier: "%.4g") sh").font(.ck(.caption2)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Section("Results") {
                    ForEach(results) { r in
                        NavigationLink(value: r.symbol) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(r.symbol).font(.ck(.body, .bold))
                                    Text(r.name).font(.ck(.caption)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Text(r.kind).font(.ck(.caption2)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Invest")
        .navigationDestination(for: String.self) { SymbolView(symbol: $0) }
        .searchable(text: $query, prompt: "Search stocks & crypto")
        .onChange(of: query) { _, q in scheduleSearch(q) }
        .task {
            async let wl = try? model.api.watchlist()
            async let dash = try? model.api.wallet()
            async let ord = try? model.api.orders()
            watchlist = await wl ?? []
            positions = await dash?.positions ?? []
            orders = await ord ?? []
        }
    }

    private func scheduleSearch(_ q: String) {
        searchTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            let r = (try? await model.api.searchSymbols(trimmed)) ?? []
            if !Task.isCancelled { results = r }
        }
    }
}
