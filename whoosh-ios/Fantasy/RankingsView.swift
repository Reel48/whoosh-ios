import SwiftUI

/// Cross-league power rankings — every team ranked by power score.
struct RankingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var board: CrossLeagueScoreboard?
    @State private var loaded = false
    @State private var chat: ChatChannel?
    @State private var openingChat = false
    @State private var chatError: String?

    var body: some View {
        List {
            if let rows = board?.rows, !rows.isEmpty {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        Text("\(row.rank)").font(.headline.monospacedDigit())
                            // Medal colors: gold / silver / bronze, then neutral.
                            .foregroundStyle(row.rank == 1 ? Color.warning
                                : row.rank == 2 ? Color.secondary
                                : row.rank == 3 ? Color.brandOrange : Color.secondary)
                            .frame(width: 26)
                        TeamAvatar(url: row.avatarUrl, name: row.teamName, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.teamName).font(.ck(.body, .medium)).lineLimit(1)
                            Text("\(row.leagueName) · \(row.record)").font(.ck(.caption2)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(row.powerScore, specifier: "%.1f")").font(.ck(.callout, .bold))
                            Text("power").font(.ck(.caption2)).foregroundStyle(.tertiary)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await openChat() } } label: {
                    if openingChat { ProgressView() }
                    else { Image(systemName: "bubble.left.and.bubble.right.fill") }
                }
                .disabled(openingChat)
            }
        }
        .navigationDestination(item: $chat) { ChannelView(channel: $0) }
        .alert("Power Rankings chat", isPresented: Binding(get: { chatError != nil }, set: { if !$0 { chatError = nil } })) {
            Button("OK") { chatError = nil }
        } message: { Text(chatError ?? "") }
        .task { if !loaded { board = try? await model.api.fantasyRankings(); loaded = true } }
        .refreshable { board = try? await model.api.fantasyRankings() }
    }

    private func openChat() async {
        openingChat = true; defer { openingChat = false }
        do { chat = try await model.api.openRankingsChat() }
        catch let e as APIError {
            chatError = e.code == "forbidden" ? "The Power Rankings chat is for league members." : e.message
        } catch { chatError = "Couldn't open chat." }
    }
}
