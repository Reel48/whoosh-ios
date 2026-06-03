import SwiftUI

/// Browse/search symbols and open one to trade. Empty search shows the
/// watchlist; typing searches stocks + crypto.
struct InvestView: View {
    @EnvironmentObject private var model: AppModel

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var watchlist: [WatchEntry] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            if query.isEmpty {
                Section("Watchlist") {
                    if watchlist.isEmpty {
                        Text("Search to find symbols, then ★ to watch them.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(watchlist) { w in
                        NavigationLink(value: w.symbol) {
                            Label(w.symbol, systemImage: "star.fill").foregroundStyle(.primary)
                        }
                    }
                }
            } else {
                Section("Results") {
                    ForEach(results) { r in
                        NavigationLink(value: r.symbol) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(r.symbol).font(.body.bold())
                                    Text(r.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Text(r.kind).font(.caption2).foregroundStyle(.secondary)
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
        .task { watchlist = (try? await model.api.watchlist()) ?? [] }
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
