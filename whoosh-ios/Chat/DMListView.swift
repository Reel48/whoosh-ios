import SwiftUI

/// Direct-message inbox: conversations newest-first, plus a "new message" flow
/// that searches members and opens a 1:1. A DM is just a private channel, so the
/// conversation itself reuses `ChannelView`.
struct DMListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var conversations: [ChatDmConversation] = []
    @State private var loaded = false
    @State private var startingNew = false
    @State private var openedChannel: ChatChannel?

    var body: some View {
        List {
            if loaded && conversations.isEmpty {
                ContentUnavailableView("No messages yet", systemImage: "paperplane",
                                       description: Text("Start a conversation with the pencil button."))
            }
            ForEach(conversations) { dm in
                Button { openedChannel = channel(for: dm) } label: { row(dm) }
                    .buttonStyle(.plain)
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { startingNew = true } label: { Image(systemName: "square.and.pencil") }
            }
        }
        .navigationDestination(item: $openedChannel) { ChannelView(channel: $0) }
        .sheet(isPresented: $startingNew) {
            NewDMView { channel in startingNew = false; openedChannel = channel }
        }
        .refreshable { await load() }
        .task { if !loaded { await load() } }
    }

    private func row(_ dm: ChatDmConversation) -> some View {
        HStack(spacing: 12) {
            ChatAvatar(url: dm.other.avatarUrl, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(dm.other.username).font(.headline)
                Text(dm.lastBody ?? "Say hello 👋").font(.subheadline)
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if dm.unread > 0 {
                Text("\(dm.unread)").font(.caption2.bold()).foregroundStyle(Color.whooshInk)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.whooshLime, in: Capsule())
            }
        }
    }

    /// Synthesize a channel for an existing conversation (ChannelView only needs
    /// id/name/post policy — messages load by channel id).
    private func channel(for dm: ChatDmConversation) -> ChatChannel {
        ChatChannel(id: dm.channelId, categoryId: 0, slug: "dm-\(dm.channelId)",
                    name: dm.other.username, description: nil, kind: "dm",
                    postPolicy: "members", requiredRoleId: nil, canPost: true,
                    unread: dm.unread, lastActivityAt: dm.lastAt)
    }

    private func load() async {
        conversations = (try? await model.api.chatDms()) ?? []
        loaded = true
    }
}

/// Username search → open a DM. Reuses the @mention member endpoint.
private struct NewDMView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var onOpen: (ChatChannel) -> Void

    @State private var query = ""
    @State private var results: [ChatMember] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List(results) { member in
                Button { Task { await open(member) } } label: {
                    HStack(spacing: 12) {
                        ChatAvatar(url: member.avatarUrl, size: 36)
                        Text(member.username)
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $query, prompt: "Search people")
            .onChange(of: query) { _, q in debounce(q) }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func debounce(_ q: String) {
        searchTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            results = (try? await model.api.chatMembers(query: trimmed)) ?? []
        }
    }

    private func open(_ member: ChatMember) async {
        guard let channel = try? await model.api.openDm(userId: member.id) else { return }
        onOpen(channel)
    }
}
