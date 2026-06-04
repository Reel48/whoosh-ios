import SwiftUI

/// A league: standings + this week's matchups. Priced leagues the user hasn't
/// paid into return `not_entitled` → a locked state.
struct LeagueDetailView: View {
    @EnvironmentObject private var model: AppModel
    let leagueId: String
    let title: String

    private enum Tab: String, CaseIterable { case standings = "Standings", matchups = "Matchups" }
    @State private var tab: Tab = .standings
    @State private var detail: LeagueDetailResponse?
    @State private var matchups: [Matchup] = []
    @State private var locked = false
    @State private var loaded = false
    @State private var chat: ChatChannel?
    @State private var openingChat = false
    @State private var chatError: String?

    var body: some View {
        Group {
            if locked {
                ContentUnavailableView {
                    Label("Locked", systemImage: "lock.fill")
                } description: {
                    Text("This league requires a paid entry. Join it on the Whoosh website.")
                }
            } else {
                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).padding()
                    List {
                        if tab == .standings { standings } else { matchupsList }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !locked {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await openChat() } } label: {
                        if openingChat { ProgressView() }
                        else { Image(systemName: "bubble.left.and.bubble.right.fill") }
                    }
                    .disabled(openingChat)
                }
            }
        }
        .navigationDestination(item: $chat) { ChannelView(channel: $0) }
        .alert("League chat", isPresented: Binding(get: { chatError != nil }, set: { if !$0 { chatError = nil } })) {
            Button("OK") { chatError = nil }
        } message: { Text(chatError ?? "") }
        .task { if !loaded { await load(); loaded = true } }
    }

    private func openChat() async {
        openingChat = true; defer { openingChat = false }
        do { chat = try await model.api.openLeagueChat(leagueId: leagueId) }
        catch let e as APIError {
            chatError = e.code == "forbidden" ? "Chat is for members of this league." : e.message
        } catch { chatError = "Couldn't open chat." }
    }

    @ViewBuilder private var standings: some View {
        if let rows = detail?.overview.standings {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                HStack(spacing: 12) {
                    Text("\(i + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 20)
                    TeamAvatar(url: row.avatarUrl, name: row.teamName, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.teamName).font(.body.weight(.medium)).lineLimit(1)
                        Text(row.ownerName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(row.record).font(.callout.weight(.semibold))
                        Text("\(row.pointsFor, specifier: "%.1f") PF").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder private var matchupsList: some View {
        if matchups.isEmpty {
            Text("No matchups this week.").font(.footnote).foregroundStyle(.secondary)
        }
        ForEach(matchups) { m in
            VStack(spacing: 6) {
                teamRow(m.home)
                if let away = m.away { teamRow(away) }
                else { Text("BYE").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            }
            .padding(.vertical, 4)
        }
    }

    private func teamRow(_ t: MatchupTeam) -> some View {
        HStack(spacing: 10) {
            TeamAvatar(url: t.avatarUrl, name: t.teamName, size: 28)
            Text(t.teamName).font(.callout.weight(t.isMine ? .bold : .regular)).lineLimit(1)
                .foregroundStyle(t.isMine ? Color.whooshGreen : .primary)
            Spacer()
            Text("\(t.points, specifier: "%.1f")").font(.callout.monospacedDigit().weight(.semibold))
        }
    }

    private func load() async {
        do {
            detail = try await model.api.fantasyLeague(leagueId)
        } catch let e as APIError where e.code == "not_entitled" {
            locked = true
        } catch { /* leave empty; standings just won't show */ }
        matchups = (try? await model.api.fantasyMatchups())?
            .blocks.first { $0.leagueId == leagueId }?.matchups ?? []
    }
}
