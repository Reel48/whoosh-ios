import SwiftUI

/// Picks a game (or the day's top events) to share into chat as a score card.
/// Opened by `/score`. Reuses the live ESPN scoreboard (`model.api.scores()`),
/// filterable by league. Returns `(games, scope)` where scope is "game" (one)
/// or "top" (the day's top up-to-5).
struct ScorePicker: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var onPick: (_ games: [Game], _ scope: String) -> Void

    @State private var games: [Game] = []
    @State private var league: String? = nil   // nil = Top (all sports)
    @State private var loaded = false

    private var leagues: [String] {
        var seen: [String] = []
        for g in games where !seen.contains(g.league) { seen.append(g.league) }
        return seen
    }
    private var filtered: [Game] { league == nil ? games : games.filter { $0.league == league } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("Top", active: league == nil) { league = nil }
                        ForEach(leagues, id: \.self) { lg in chip(lg, active: league == lg) { league = lg } }
                    }.padding(.horizontal).padding(.vertical, 8)
                }
                List {
                    if league == nil && games.count > 1 {
                        Button { onPick(Array(games.prefix(5)), "top") } label: {
                            Label("Share today's top games", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.brandBlue)
                        }
                    }
                    ForEach(filtered) { g in
                        Button { onPick([g], "game") } label: { row(g) }.buttonStyle(.plain)
                    }
                    if games.isEmpty && loaded {
                        ContentUnavailableView("No games today", systemImage: "sportscourt")
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Share a score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task { if !loaded { games = (try? await model.api.scores()) ?? []; loaded = true } }
        }
    }

    private func chip(_ title: String, active: Bool, _ tap: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); tap() } label: {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(active ? Color.brandBlue : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(active ? .white : .primary)
        }.buttonStyle(.plain)
    }

    private func row(_ g: Game) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                teamLine(g.away); teamLine(g.home)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(g.league).font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                HStack(spacing: 4) {
                    if g.state == "in" { Circle().fill(Color.brandOrange).frame(width: 5, height: 5) }
                    Text(g.detail).font(.caption2).foregroundStyle(g.state == "in" ? Color.brandOrange : .secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func teamLine(_ t: ScoreTeam) -> some View {
        HStack(spacing: 6) {
            Text(t.abbr).font(.subheadline.weight(.semibold))
            if let s = t.score { Text(s).font(.subheadline.weight(.heavy).monospacedDigit()) }
        }
    }
}
