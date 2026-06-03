import SwiftUI

/// The chat hub: a pinned header, the user's level/XP hero, then categories →
/// channels they can access (role-gated ones are simply absent). Primary tab.
struct ChatHomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var overview: ChatOverview?
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Whoosh Chat")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal).padding(.top, 8).padding(.bottom, 6)

                Group {
                    if let overview {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
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
                                            NavigationLink { destination(channel) } label: { channelCard(channel) }
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
            .task { if !loaded { await load() } }
            .refreshable { await load() }
        }
    }

    // MARK: Hero

    private func hero(_ me: ChatMe) -> some View {
        let progress = ChatLevels.progress(xp: me.xp, level: me.level)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ChatAvatar(url: avatarURL, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("@\(model.currentUsername)").font(.headline)
                    if let role = me.roles.max(by: { $0.priority < $1.priority }) {
                        Text(role.name).font(.caption2.bold())
                            .foregroundStyle(Color.whooshInk)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color(hex: role.color), in: Capsule())
                    }
                }
                Spacer()
                LevelBadge(level: me.level)
            }
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress).tint(Color.whooshLime)
                HStack {
                    Text("Rank #\(me.rank)")
                    Spacer()
                    Text("\(me.xp) XP · next lvl \(me.level + 1)")
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var avatarURL: String? {
        // The overview doesn't carry the viewer's avatar; reuse the account one
        // if the app has it cached on the model in future. For now, nil → glyph.
        nil
    }

    // MARK: Channel row

    /// A standalone channel card — spaced apart so categories don't read as one
    /// dense block. All icons share the same neutral tint.
    private func channelCard(_ c: ChatChannel) -> some View {
        HStack(spacing: 13) {
            Image(systemName: ChannelIcon.symbol(slug: c.slug, kind: c.kind))
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(c.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                if let d = c.description, !d.isEmpty {
                    Text(d).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
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
