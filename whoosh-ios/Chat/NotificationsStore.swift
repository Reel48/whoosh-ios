import SwiftUI
import Combine

/// The in-app notification feed + unread count, backed by `/api/v1/wb/notifications`.
/// Refreshed on launch, when the app foregrounds, and on pull-to-refresh. Chat
/// uses the `chat_mention` / `chat_dm` kinds; push (APNs) handles background.
@MainActor
final class NotificationsStore: ObservableObject {
    @Published private(set) var items: [AppNotification] = []
    @Published private(set) var unread = 0

    private let api: WhooshAPI

    init(api: WhooshAPI) { self.api = api }

    func refresh() async {
        if let r = try? await api.notifications() {
            items = r.items
            unread = r.unread
        }
    }

    func markAllRead() async {
        unread = 0
        unread = (try? await api.markNotificationsRead()) ?? 0
    }
}
