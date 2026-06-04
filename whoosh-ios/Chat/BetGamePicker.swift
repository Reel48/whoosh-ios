import SwiftUI

/// Picks an open game to share into chat as a bet card. Opened by `/bets`
/// (optionally pre-filtered by the text after the command). Reuses the Bet
/// page's data (`events()` + `BetMarketCatalog.groupByGame`).
struct BetGamePicker: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    /// Text typed after `/bets` — narrows the list by matchup.
    var prefilter: String = ""
    var onPick: (BetGame) -> Void

    @State private var query = ""
    @State private var games: [BetGame] = []
    @State private var loaded = false

    private var filtered: [BetGame] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return games }
        return games.filter { $0.matchup.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if games.isEmpty && loaded {
                    ContentUnavailableView("No open games", systemImage: "dice")
                } else {
                    List(filtered) { game in
                        Button { onPick(game) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(game.matchup).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                HStack(spacing: 6) {
                                    Text(BetMarketCatalog.sportTitle(game.sportKey))
                                    if let t = gameTime(game.commenceTime) { Text("· \(t)") }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $query)
            .navigationTitle("Share a bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task {
                if !loaded {
                    query = prefilter
                    games = BetMarketCatalog.groupByGame((try? await model.api.events()) ?? [])
                    loaded = true
                }
            }
        }
    }

    private func gameTime(_ iso: String?) -> String? {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}
