import SwiftUI

/// Full-text search across every channel the viewer can read. Tapping a result
/// opens its channel (when it's a known, accessible channel).
struct ChatSearchView: View {
    @EnvironmentObject private var model: AppModel
    let channels: [ChatChannel]

    @State private var query = ""
    @State private var results: [ChatMessage] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var openedChannel: ChatChannel?

    var body: some View {
        List {
            if !query.isEmpty && results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            ForEach(results) { msg in
                let channel = channels.first { $0.id == msg.channelId }
                Button { openedChannel = channel } label: { row(msg, channel: channel) }
                    .buttonStyle(.plain)
                    .disabled(channel == nil)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search messages")
        .onChange(of: query) { _, q in debounce(q) }
        .navigationDestination(item: $openedChannel) { ChannelView(channel: $0) }
    }

    private func row(_ msg: ChatMessage, channel: ChatChannel?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ChatAvatar(url: msg.author.avatarUrl, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(msg.author.username).font(.subheadline.bold())
                    if let channel { Text("#\(channel.name)").font(.caption2).foregroundStyle(.secondary) }
                }
                Text(msg.body).font(.subheadline).lineLimit(2)
            }
        }
    }

    private func debounce(_ q: String) {
        searchTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            results = (try? await model.api.chatSearch(query: trimmed)) ?? []
        }
    }
}
