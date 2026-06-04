import SwiftUI

/// Navigation routes pushed from the chat hub.
enum ChatRoute: Hashable {
    case channel(ChatChannel)
    case dms
    case search
    case notifications
}

/// Bell icon with an unread dot; observes the shared store so the badge is live.
struct NotificationBell: View {
    @ObservedObject var store: NotificationsStore
    var body: some View {
        Image(systemName: "bell").font(.ck(.title3))
            .overlay(alignment: .topTrailing) {
                if store.unread > 0 {
                    Circle().fill(Color.brandOrange).frame(width: 9, height: 9).offset(x: 5, y: -3)
                }
            }
    }
}

/// In-app notification inbox. New @mentions / DMs arrive here (and via APNs push
/// in the background). Opening the inbox clears the unread badge; tapping a chat
/// notification deep-links into its channel.
struct NotificationsView: View {
    @EnvironmentObject private var model: AppModel
    /// Accessible channels (from the overview) to resolve a notification's target.
    let channels: [ChatChannel]
    @ObservedObject var store: NotificationsStore

    var body: some View {
        List {
            if store.items.isEmpty {
                ContentUnavailableView("No notifications", systemImage: "bell.slash")
            }
            ForEach(store.items) { n in
                if let channel = target(for: n) {
                    NavigationLink(value: ChatRoute.channel(channel)) { row(n) }
                } else {
                    row(n)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.markAllRead() }
        .refreshable { await store.refresh() }
    }

    private func row(_ n: AppNotification) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(n.kind)).font(.ck(.title3))
                .foregroundStyle(Color.whooshGreen).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(n.title).font(.ck(.subheadline, .bold))
                if let body = n.body, !body.isEmpty {
                    Text(body).font(.ck(.caption)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if n.readAt == nil { Circle().fill(Color.whooshLime).frame(width: 8, height: 8) }
        }
    }

    private func icon(_ kind: String) -> String {
        switch kind {
        case "chat_mention": return "at"
        case "chat_dm": return "paperplane.fill"
        default: return "bell.fill"
        }
    }

    /// href is "chat:<channelId>:<messageId>".
    private func target(for n: AppNotification) -> ChatChannel? {
        guard let href = n.href, href.hasPrefix("chat:") else { return nil }
        let parts = href.split(separator: ":")
        guard parts.count >= 2, let id = Int(parts[1]) else { return nil }
        return channels.first { $0.id == id }
    }
}
