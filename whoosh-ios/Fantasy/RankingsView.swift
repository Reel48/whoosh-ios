import SwiftUI

/// Cross-league power rankings — every team ranked by power score.
struct RankingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var board: CrossLeagueScoreboard?
    @State private var loaded = false

    var body: some View {
        List {
            if let rows = board?.rows, !rows.isEmpty {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        Text("\(row.rank)").font(.headline.monospacedDigit())
                            .foregroundStyle(row.rank <= 3 ? Color.whooshGreen : .secondary)
                            .frame(width: 26)
                        TeamAvatar(url: row.avatarUrl, name: row.teamName, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.teamName).font(.body.weight(.medium)).lineLimit(1)
                            Text("\(row.leagueName) · \(row.record)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(row.powerScore, specifier: "%.1f")").font(.callout.weight(.bold))
                            Text("power").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            } else if loaded {
                ContentUnavailableView("No rankings yet", systemImage: "trophy")
            }
        }
        .listStyle(.plain)
        .navigationTitle("Power Rankings")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !loaded { board = try? await model.api.fantasyRankings(); loaded = true } }
        .refreshable { board = try? await model.api.fantasyRankings() }
    }
}
