import SwiftUI

/// The chat hub: the user's level/rank header, then categories → channels they
/// can access (role-gated ones are simply absent). The app's primary tab.
struct ChatHomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var overview: ChatOverview?
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let overview {
                    List {
                        meHeader(overview.me)
                        ForEach(overview.categories) { category in
                            Section(category.name.uppercased()) {
                                ForEach(category.channels) { channel in
                                    NavigationLink {
                                        destination(channel)
                                    } label: {
                                        channelRow(channel)
                                    }
                                }
                            }
                        }
                    }
                } else if loaded {
                    ContentUnavailableView("Chat unavailable", systemImage: "bubble.left.and.bubble.right",
                                           description: Text(error ?? "Try again later."))
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Whoosh Chat")
            .task { if !loaded { await load() } }
            .refreshable { await load() }
        }
    }

    private func meHeader(_ me: ChatMe) -> some View {
        Section {
            HStack(spacing: 12) {
                LevelBadge(level: me.level)
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(model.currentUsername)").font(.headline)
                    Text("Rank #\(me.rank) · \(me.xp) XP").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !me.roles.isEmpty {
                    Text(me.roles.first!.name)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.whooshInk)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(hex: me.roles.first!.color), in: Capsule())
                }
            }
        }
    }

    private func channelRow(_ c: ChatChannel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon(for: c))
                .foregroundStyle(.secondary).frame(width: 22)
            Text(c.name)
            Spacer()
            if c.requiredRoleId != nil {
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func icon(for c: ChatChannel) -> String {
        switch c.kind {
        case "leaderboard": return "trophy.fill"
        case "starboard": return "star.fill"
        case "media": return "photo.fill"
        default: return "number"
        }
    }

    @ViewBuilder
    private func destination(_ c: ChatChannel) -> some View {
        switch c.kind {
        case "leaderboard": ChatLeaderboardView()
        case "starboard": StarboardView()
        default: ChannelView(channel: c)
        }
    }

    private func load() async {
        do { overview = try await model.api.chatOverview(); error = nil }
        catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
        loaded = true
    }
}

/// A small circular level chip.
struct LevelBadge: View {
    let level: Int
    var body: some View {
        Text("\(level)")
            .font(.subheadline.bold().monospacedDigit())
            .foregroundStyle(Color.whooshInk)
            .frame(width: 38, height: 38)
            .background(Color.whooshLime, in: Circle())
            .overlay(alignment: .bottom) {
                Text("LVL").font(.system(size: 7, weight: .heavy)).foregroundStyle(Color.whooshInk.opacity(0.6)).offset(y: -3)
            }
    }
}
