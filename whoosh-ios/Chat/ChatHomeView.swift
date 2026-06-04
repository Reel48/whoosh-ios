import SwiftUI

/// The chat hub: a pinned header, the user's level/XP hero, then categories →
/// channels they can access (role-gated ones are simply absent). Primary tab.
struct ChatHomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var overview: ChatOverview?
    @State private var loaded = false
    @State private var error: String?
    @State private var path = NavigationPath()
    /// Clears a channel's unread badge locally when opened, ahead of the next load.
    @State private var readOverride: [Int: Int] = [:]
    @ObservedObject private var push = PushManager.shared

    private var allChannels: [ChatChannel] { overview?.categories.flatMap(\.channels) ?? [] }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Group {
                    if let overview {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                // Inside the scroll so it slides away with the
                                // content, like the title on other pages.
                                header
                                hero(overview.me).padding(.horizontal, 16).padding(.bottom, 8)

                                ForEach(overview.categories) { category in
                                    Text(category.name)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .kerning(0.6)
                                        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)

                                    VStack(spacing: 8) {
                                        ForEach(category.channels) { channel in
                                            NavigationLink(value: ChatRoute.channel(channel)) {
                                                channelCard(channel, unread: readOverride[channel.id] ?? channel.unreadCount)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    } else if loaded {
                        ContentUnavailableView("Chat unavailable", systemImage: "bubble.left.and.bubble.right",
                                               description: Text(error ?? "Try again later."))
                    } else {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ChatRoute.self) { routeView($0) }
            .task { if !loaded { await load() } }
            .refreshable { await load() }
            .onChange(of: push.pendingDeepLink) { _, link in routeDeepLink(link) }
        }
    }

    // MARK: Header + routing

    private var header: some View {
        HStack {
            Image("WhooshWordmark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 26)
                .foregroundStyle(.primary)
                .accessibilityLabel("Whoosh")
            Spacer()
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 6)
    }

    @ViewBuilder
    private func routeView(_ route: ChatRoute) -> some View {
        switch route {
        case .channel(let c):
            destination(c).onAppear { readOverride[c.id] = 0 }
        case .dms:
            DMListView()
        case .search:
            ChatSearchView(channels: allChannels)
        case .notifications:
            NotificationsView(channels: allChannels, store: model.notifications)
        }
    }

    /// "chat:<channelId>:<messageId>" from a tapped push → open that channel.
    private func routeDeepLink(_ link: String?) {
        guard let link, link.hasPrefix("chat:") else { return }
        let parts = link.split(separator: ":")
        guard parts.count >= 2, let id = Int(parts[1]),
              let channel = allChannels.first(where: { $0.id == id }) else { return }
        path.append(ChatRoute.channel(channel))
        push.pendingDeepLink = nil
    }

    // MARK: Hero

    private func hero(_ me: ChatMe) -> some View {
        let progress = ChatLevels.progress(xp: me.xp, level: me.level)
        // XP/level visuals take the viewer's top-role color (Member purple,
        // Premium lime, Admin blue); ink text stays readable on all three.
        let topRole = me.roles.max(by: { $0.priority < $1.priority })
        let roleColor = topRole.map { Color(hex: $0.color) } ?? .brandLime
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ChatAvatar(url: me.avatarUrl, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("@\(model.currentUsername)").font(.headline)
                    if let role = topRole {
                        Text(role.name).font(.caption2.weight(.bold))
                            .foregroundStyle(Color.whooshInk)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color(hex: role.color), in: Capsule())
                    }
                }
                Spacer()
                LevelBadge(level: me.level, color: roleColor)
            }

            // Quick actions — search, DMs, notifications (moved off the header).
            HStack(spacing: 10) {
                actionTile(.search, "Search") { Image(systemName: "magnifyingglass") }
                actionTile(.dms, "Messages") { Image(systemName: "paperplane.fill") }
                actionTile(.notifications, "Alerts") { NotificationBell(store: model.notifications) }
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress).tint(roleColor)
                HStack {
                    Text("Level \(me.level)")
                    Spacer()
                    Text("\(me.xp) XP · next lvl \(me.level + 1)")
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    /// A tappable hero tile that routes into search / DMs / notifications.
    private func actionTile<Icon: View>(
        _ route: ChatRoute, _ label: String, @ViewBuilder icon: () -> Icon,
    ) -> some View {
        NavigationLink(value: route) {
            VStack(spacing: 5) {
                icon().font(.title3).frame(height: 22)
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .tint(.primary)
    }

    // MARK: Channel row

    /// A standalone channel card — spaced apart so categories don't read as one
    /// dense block. All icons share the same neutral tint.
    private func channelCard(_ c: ChatChannel, unread: Int) -> some View {
        HStack(spacing: 13) {
            Image(systemName: ChannelIcon.symbol(slug: c.slug, kind: c.kind))
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(c.name).font(.body.weight(unread > 0 ? .semibold : .medium)).foregroundStyle(.primary)
                if let d = c.description, !d.isEmpty {
                    Text(d).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if unread > 0 {
                Text("\(unread)").font(.caption2.bold().monospacedDigit()).foregroundStyle(Color.whooshInk)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.whooshLime, in: Capsule())
            }
            if c.requiredRoleId != nil {
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.tertiary)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
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

/// XP curve shared with the server (`chat_level_for_xp`): xp to *finish* level i
/// is `5i² + 50i + 100`.
enum ChatLevels {
    static func need(for level: Int) -> Int { 5 * level * level + 50 * level + 100 }

    /// Cumulative XP required to *reach* `level`.
    static func cumulative(toReach level: Int) -> Int {
        var total = 0
        for i in 0..<max(level, 0) { total += need(for: i) }
        return total
    }

    /// Fraction (0–1) of progress from `level` toward `level+1`.
    static func progress(xp: Int, level: Int) -> Double {
        let base = cumulative(toReach: level)
        let need = need(for: level)
        guard need > 0 else { return 0 }
        return min(1, max(0, Double(xp - base) / Double(need)))
    }
}

/// A small circular level chip, tinted to the user's top-role color.
struct LevelBadge: View {
    let level: Int
    var color: Color = .brandLime
    var body: some View {
        Text("\(level)")
            .font(.subheadline.bold().monospacedDigit())
            .foregroundStyle(Color.whooshInk)
            .frame(width: 38, height: 38)
            .background(color, in: Circle())
            .overlay(alignment: .bottom) {
                Text("LVL").font(.system(size: 7, weight: .heavy)).foregroundStyle(Color.whooshInk.opacity(0.6)).offset(y: -3)
            }
    }
}
