import SwiftUI

/// XP Leaderboard channel — ranks members by chat XP.
struct ChatLeaderboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var rows: [ChatLeaderboardRow] = []
    @State private var loaded = false

    var body: some View {
        List {
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    Text("#\(row.rank)").font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(row.rank <= 3 ? Color.whooshGreen : .secondary)
                        .frame(width: 38, alignment: .leading)
                    ChatAvatar(url: row.user.avatarUrl, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.user.username).font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: row.user.roleColor))
                        Text("\(row.messageCount) messages").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("LVL \(row.level)").font(.caption.bold())
                        Text("\(row.xp) XP").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            if rows.isEmpty && loaded {
                ContentUnavailableView("No ranks yet", systemImage: "trophy", description: Text("Send messages to earn XP."))
            }
        }
        .navigationTitle("XP Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !loaded { rows = (try? await model.api.chatLeaderboard()) ?? []; loaded = true } }
        .refreshable { rows = (try? await model.api.chatLeaderboard()) ?? [] }
    }
}

/// Starboard — swipe to Boost/Meh the most-starred messages, plus an all-time
/// Top leaderboard of the most-boosted.
struct StarboardView: View {
    @EnvironmentObject private var model: AppModel
    private enum Mode: String, CaseIterable { case swipe = "Swipe", top = "Top" }
    @State private var mode: Mode = .swipe
    @State private var deck: [ChatMessage] = []
    @State private var leaders: [ChatMessage] = []
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).padding()

            switch mode {
            case .swipe: swipe
            case .top: leaderboard
            }
        }
        .navigationTitle("Starboard")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: mode) { await load() }
    }

    private var swipe: some View {
        SwipeDeck(
            items: $deck,
            rightLabel: "BOOST", leftLabel: "MEH",
            rightColor: .brandOrange, rightIcon: "bolt.fill",
            emptyTitle: "All caught up", emptySubtitle: "New starred messages show up here to rate.",
            onDecide: { msg, direction in
                _ = try? await model.api.starboardBoost(messageId: msg.id, direction: direction == "right" ? "boost" : "meh")
            },
            onUndo: { msg in _ = try? await model.api.starboardBoost(messageId: msg.id, direction: nil) },
            card: { StarboardCard(message: $0) }
        )
    }

    private var leaderboard: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(leaders.enumerated()), id: \.element.id) { i, msg in
                    HStack(alignment: .top, spacing: 12) {
                        Text("#\(i + 1)").font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(i < 3 ? Color.brandOrange : .secondary)
                            .frame(width: 32, alignment: .leading)
                        ChatAvatar(url: msg.author.avatarUrl, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg.author.username).font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: msg.author.roleColor))
                            Text(msg.body).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                        }
                        Spacer(minLength: 6)
                        Label("\(msg.boostCount ?? 0)", systemImage: "bolt.fill")
                            .font(.caption.bold()).foregroundStyle(Color.brandOrange)
                            .labelStyle(.titleAndIcon)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                if leaders.isEmpty && loaded {
                    ContentUnavailableView("No boosts yet", systemImage: "bolt",
                                           description: Text("Boost great messages in Swipe to build the board."))
                        .padding(.top, 40)
                }
            }
            .padding(14)
        }
        .refreshable { leaders = (try? await model.api.starboardLeaderboard()) ?? [] }
    }

    private func load() async {
        switch mode {
        case .swipe: if deck.isEmpty { deck = (try? await model.api.starboardDeck()) ?? [] }
        case .top: leaders = (try? await model.api.starboardLeaderboard()) ?? []
        }
        loaded = true
    }
}
