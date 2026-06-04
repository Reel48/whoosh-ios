import SwiftUI

/// Fantasy home: link a Sleeper account, then browse leagues (standings +
/// matchups), the cross-league power rankings, and pools.
struct FantasyView: View {
    @EnvironmentObject private var model: AppModel
    @State private var overview: FantasyOverview?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fantasy").font(.largeTitle.bold())
                    if let s = overview?.state {
                        Text("NFL · \(s.label)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.top, 8).padding(.bottom, 8)

                List {
                    if overview?.link == nil {
                        Section { LinkSleeperCard(onLinked: { Task { await load() } }) }
                    }

                    Section {
                        NavigationLink { RankingsView() } label: {
                            Label("Power Rankings", systemImage: "trophy.fill")
                        }
                    }

                    if let leagues = overview?.leagues, !leagues.isEmpty {
                        Section("Leagues") {
                            ForEach(leagues) { lg in
                                NavigationLink {
                                    LeagueDetailView(leagueId: lg.id, title: lg.displayName)
                                } label: { leagueRow(lg) }
                            }
                        }
                    }

                    if let pools = overview?.pools, !pools.isEmpty {
                        Section("Pools") {
                            ForEach(pools) { p in
                                NavigationLink {
                                    PoolDetailView(poolId: p.id, title: p.displayName)
                                } label: { poolRow(p) }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { if !loaded { await load(); loaded = true } }
            .refreshable { await load() }
        }
    }

    private func leagueRow(_ lg: LeagueOverview) -> some View {
        HStack(spacing: 12) {
            TeamAvatar(url: lg.avatarUrl, name: lg.displayName)
            VStack(alignment: .leading, spacing: 2) {
                Text(lg.displayName).font(.body.weight(.semibold)).lineLimit(1)
                Text("\(lg.totalRosters) teams" + (lg.standings.first.map { " · \($0.teamName) leads" } ?? ""))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private func poolRow(_ p: PoolSummary) -> some View {
        HStack(spacing: 12) {
            TeamAvatar(url: p.logoUrl, name: p.displayName)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.displayName).font(.body.weight(.semibold)).lineLimit(1)
                Text(p.kind == "survivor"
                     ? "\(p.aliveCount ?? p.totalEntries) alive · \(p.totalEntries) entries"
                     : "\(p.totalEntries) entries")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(p.kind.capitalized).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func load() async {
        overview = try? await model.api.fantasyOverview()
    }
}

/// Inline "link your Sleeper account" prompt.
private struct LinkSleeperCard: View {
    @EnvironmentObject private var model: AppModel
    var onLinked: () -> Void

    @State private var username = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Link your Sleeper account", systemImage: "link").font(.headline)
            Text("Connect your Sleeper username to see your leagues, matchups, and ranking.")
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                TextField("Sleeper username", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(8).background(Color(.tertiarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
                Button { Task { await link() } } label: {
                    if busy { ProgressView() } else { Text("Link").bold() }
                }
                .buttonStyle(.borderedProminent).tint(Color.whooshLime).foregroundStyle(Color.whooshInk)
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            }
            if let error { Text(error).foregroundStyle(.bad).font(.footnote) }
        }
        .padding(.vertical, 4)
    }

    private func link() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            _ = try await model.api.linkSleeper(username: username.trimmingCharacters(in: .whitespaces))
            onLinked()
        } catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }
}
