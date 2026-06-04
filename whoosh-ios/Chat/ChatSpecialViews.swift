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

/// Starboard channel — the most-starred messages.
struct StarboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var messages: [ChatMessage] = []
    @State private var loaded = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(messages) { msg in
                    VStack(alignment: .leading, spacing: 6) {
                        Label("\(msg.starCount)", systemImage: "star.fill")
                            .font(.caption.bold()).foregroundStyle(.brandOrange)
                        MessageRow(message: msg, onReact: { _ in })
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                if messages.isEmpty && loaded {
                    ContentUnavailableView("No starred messages", systemImage: "star",
                                           description: Text("Star great messages to feature them here."))
                        .padding(.top, 40)
                }
            }
            .padding(14)
        }
        .navigationTitle("Starboard")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !loaded { messages = (try? await model.api.chatStarboard()) ?? []; loaded = true } }
        .refreshable { messages = (try? await model.api.chatStarboard()) ?? [] }
    }
}
