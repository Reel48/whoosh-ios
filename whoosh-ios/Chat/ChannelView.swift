import SwiftUI
import PhotosUI
import Combine

/// One channel: live message stream (history via api + realtime inserts/edits),
/// a composer with photo + @mentions, reactions, and edit/delete.
struct ChannelView: View {
    @EnvironmentObject private var model: AppModel
    let channel: ChatChannel

    @StateObject private var vm = ChannelModel()
    @State private var draft = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingImage: Data?
    @State private var sending = false
    @State private var editing: ChatMessage?
    @State private var mentionResults: [ChatMember] = []
    @State private var levelToast: Int?

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if !vm.typingNames.isEmpty { typingIndicator }
            if !mentionResults.isEmpty { mentionBar }
            if let data = pendingImage, let img = UIImage(data: data) {
                attachmentPreview(img)
            }
            if channel.postPolicy != "system" && channel.canPost {
                composer
            } else if channel.postPolicy == "admins" {
                footerNote("Only admins can post here.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(channel.name).font(.headline)
                    if vm.onlineCount > 0 {
                        Text("\(vm.onlineCount) online").font(.caption2).foregroundStyle(Color.whooshGreen)
                    } else if let d = channel.description, !d.isEmpty {
                        Text(d).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
        .overlay(alignment: .top) { levelToastView }
        .task { await vm.start(api: model.api, realtime: model.realtime, channel: channel) }
        .onDisappear { Task { await vm.stop() } }
        .onChange(of: photoItem) { _, item in
            Task { pendingImage = try? await item?.loadTransferable(type: Data.self) }
        }
    }

    // MARK: Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(vm.messages.enumerated()), id: \.element.id) { i, msg in
                        let prev = i > 0 ? vm.messages[i - 1] : nil
                        if dayChanged(prev, msg) { DayDivider(label: ChatTime.dayLabel(msg.createdAt)) }
                        MessageRow(
                            message: msg,
                            showsHeader: showsHeader(prev, msg),
                            onReact: { emoji in _ = Task { await vm.react(msg, emoji: emoji) } },
                            canEdit: msg.mine, onEdit: { editing = msg; draft = msg.body },
                            canDelete: msg.mine, onDelete: { _ = Task { await vm.delete(msg) } })
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    /// Show the author header unless this continues a run from the same author
    /// within 5 minutes (and on the same day).
    private func showsHeader(_ prev: ChatMessage?, _ msg: ChatMessage) -> Bool {
        guard let prev else { return true }
        if prev.author.id != msg.author.id { return true }
        if dayChanged(prev, msg) { return true }
        guard let a = ChatTime.date(prev.createdAt), let b = ChatTime.date(msg.createdAt) else { return true }
        return b.timeIntervalSince(a) > 300
    }

    private func dayChanged(_ prev: ChatMessage?, _ msg: ChatMessage) -> Bool {
        guard let prev, let a = ChatTime.date(prev.createdAt), let b = ChatTime.date(msg.createdAt) else { return prev == nil }
        return !Calendar.current.isDate(a, inSameDayAs: b)
    }

    private var typingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text(typingText).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .transition(.opacity)
    }

    private var typingText: String {
        switch vm.typingNames.count {
        case 1: return "\(vm.typingNames[0]) is typing…"
        case 2: return "\(vm.typingNames[0]) and \(vm.typingNames[1]) are typing…"
        default: return "Several people are typing…"
        }
    }

    private var mentionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mentionResults) { m in
                    Button {
                        applyMention(m.username)
                    } label: {
                        Text("@\(m.username)").font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 12).padding(.vertical, 6)
        }
        .background(.bar)
    }

    private func attachmentPreview(_ img: UIImage) -> some View {
        HStack {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Photo attached").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { pendingImage = nil; photoItem = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 14).padding(.vertical, 6).background(.bar)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo").font(.title3).foregroundStyle(.secondary)
            }
            TextField(editing == nil ? "Message #\(channel.slug)" : "Edit message…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                .lineLimit(1...5)
                .onChange(of: draft) { _, v in
                    Task { await refreshMentions(v) }
                    if !v.isEmpty { Task { await vm.noteTyping(username: model.currentUsername) } }
                }
            Button { Task { await submit() } } label: {
                if sending { ProgressView() }
                else { Image(systemName: "arrow.up.circle.fill").font(.title) .foregroundStyle(canSend ? Color.whooshGreen : .secondary) }
            }.disabled(!canSend)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
    }

    private func footerNote(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 10).background(.bar)
    }

    private var canSend: Bool {
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingImage != nil) && !sending
    }

    @ViewBuilder
    private var levelToastView: some View {
        if let lvl = levelToast {
            Label("Level up! You're level \(lvl)", systemImage: "sparkles")
                .font(.subheadline.bold()).foregroundStyle(Color.whooshInk)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.whooshLime, in: Capsule())
                .padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Actions

    private func submit() async {
        sending = true; defer { sending = false }
        if let editing {
            await vm.edit(editing, body: draft)
            self.editing = nil; draft = ""; return
        }
        var imageUrl: String?
        if let data = pendingImage {
            imageUrl = try? await model.api.uploadChatImage(imageData: data).absoluteString
        }
        let leveledTo = await vm.send(body: draft, imageUrl: imageUrl)
        draft = ""; pendingImage = nil; photoItem = nil; mentionResults = []
        if let lvl = leveledTo {
            withAnimation { levelToast = lvl }
            try? await Task.sleep(for: .seconds(2))
            withAnimation { levelToast = nil }
        }
    }

    private func refreshMentions(_ text: String) async {
        guard let frag = trailingMention(text), frag.count >= 1 else { mentionResults = []; return }
        mentionResults = (try? await model.api.chatMembers(query: frag)) ?? []
    }

    private func trailingMention(_ text: String) -> String? {
        guard let at = text.range(of: "@", options: .backwards) else { return nil }
        let after = text[at.upperBound...]
        if after.contains(" ") || after.contains("\n") { return nil }
        return after.isEmpty ? nil : String(after)
    }

    private func applyMention(_ username: String) {
        if let at = draft.range(of: "@", options: .backwards) {
            draft.replaceSubrange(at.lowerBound..., with: "@\(username) ")
        }
        mentionResults = []
    }
}

/// A slim centered date separator between days of messages.
struct DayDivider: View {
    let label: String
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).fixedSize()
            Rectangle().fill(Color(.separator)).frame(height: 0.5)
        }
        .padding(.vertical, 10)
    }
}

/// Owns a channel's messages and the realtime subscription. MainActor-isolated
/// (hence Sendable), so the realtime callback can hop back safely.
@MainActor
final class ChannelModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var onlineCount = 0
    @Published var typingNames: [String] = []
    private var api: WhooshAPI?
    private var realtime: RealtimeClient?
    private var channelId = 0
    private var authors: [String: ChatAuthor] = [:]
    private var typingUsers: [String: String] = [:]            // userId → username
    private var typingExpiry: [String: Task<Void, Never>] = [:]
    private var lastTypingSentAt: Date?
    private var typingStopTask: Task<Void, Never>?

    func start(api: WhooshAPI, realtime: RealtimeClient, channel: ChatChannel) async {
        self.api = api; self.realtime = realtime; self.channelId = channel.id
        if let history = try? await api.chatMessages(channelId: channel.id) {
            messages = history
            for m in history { authors[m.author.id] = m.author }
            if let last = history.last { try? await api.markChatRead(channelId: channel.id, messageId: last.id) }
        }
        await realtime.subscribe(channelId: channel.id) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
    }

    func stop() async { await realtime?.unsubscribe() }

    private func handle(_ event: RealtimeClient.Event) {
        switch event {
        case .messageInsert(let r):
            guard r.deletedAt == nil, !messages.contains(where: { $0.id == r.id }) else { return }
            Task { await appendRecord(r) }
        case .messageUpdate(let r):
            if let idx = messages.firstIndex(where: { $0.id == r.id }) {
                if r.deletedAt != nil { messages.remove(at: idx); return }
                messages[idx].body = r.body
                messages[idx].starCount = r.starCount
                messages[idx].editedAt = r.editedAt
            }
        case .reactionChange:
            break // star_count arrives via the message UPDATE above
        case .presence(let ids):
            onlineCount = ids.count
        case .typing(let userId, let username, let isTyping):
            setTyping(userId: userId, username: username, isTyping: isTyping)
        }
    }

    // MARK: Typing

    /// Call as the composer changes: throttles a "typing" broadcast and schedules
    /// a "stopped" after a short idle.
    func noteTyping(username: String) async {
        let now = Date()
        if lastTypingSentAt == nil || now.timeIntervalSince(lastTypingSentAt!) > 2 {
            lastTypingSentAt = now
            await realtime?.sendTyping(true, username: username)
        }
        typingStopTask?.cancel()
        typingStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.lastTypingSentAt = nil
            await self?.realtime?.sendTyping(false, username: username)
        }
    }

    private func setTyping(userId: String, username: String, isTyping: Bool) {
        typingExpiry[userId]?.cancel()
        if isTyping {
            typingUsers[userId] = username
            typingExpiry[userId] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                self.typingUsers[userId] = nil
                self.typingNames = Array(self.typingUsers.values).sorted()
            }
        } else {
            typingUsers[userId] = nil
        }
        typingNames = Array(typingUsers.values).sorted()
    }

    private func appendRecord(_ r: ChatMessageRecord) async {
        var author = authors[r.userId]
        if author == nil { author = (try? await api?.chatUsers(ids: [r.userId]))?.first; if let a = author { authors[a.id] = a } }
        let msg = ChatMessage(
            id: r.id, channelId: r.channelId,
            author: author ?? ChatAuthor(id: r.userId, username: "unknown", avatarUrl: nil, level: 0, roleColor: "#9aa0a6"),
            body: r.body, imageUrl: r.imageUrl, replyToId: r.replyToId, starCount: r.starCount,
            reactions: [], mine: false, createdAt: r.createdAt, editedAt: r.editedAt)
        if !messages.contains(where: { $0.id == msg.id }) {
            messages.append(msg)
            try? await api?.markChatRead(channelId: channelId, messageId: msg.id) // viewing → caught up
        }
    }

    /// Returns the new level if the author leveled up.
    func send(body: String, imageUrl: String?) async -> Int? {
        guard let api else { return nil }
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let result = try? await api.sendChatMessage(channelId: channelId, body: text.isEmpty ? nil : text, imageUrl: imageUrl) else { return nil }
        authors[result.message.author.id] = result.message.author
        if !messages.contains(where: { $0.id == result.message.id }) { messages.append(result.message) }
        return result.leveledUp ? result.level : nil
    }

    func react(_ message: ChatMessage, emoji: String) async {
        guard let api, let idx = messages.firstIndex(where: { $0.id == message.id }) else { return }
        let existing = messages[idx].reactions.first(where: { $0.emoji == emoji })
        let on = !(existing?.mine ?? false)
        guard let count = try? await api.reactChat(messageId: message.id, emoji: emoji, on: on) else { return }
        var reactions = messages[idx].reactions.filter { $0.emoji != emoji }
        if count > 0 { reactions.append(ChatReactionSummary(emoji: emoji, count: count, mine: on)) }
        messages[idx].reactions = reactions
        if emoji == "⭐" { messages[idx].starCount = count }
    }

    func edit(_ message: ChatMessage, body: String) async {
        guard let api else { return }
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, (try? await api.editChat(messageId: message.id, body: text)) != nil else { return }
        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx].body = text; messages[idx].editedAt = ISO8601DateFormatter().string(from: Date())
        }
    }

    func delete(_ message: ChatMessage) async {
        guard let api else { return }
        try? await api.deleteChat(messageId: message.id)
        messages.removeAll { $0.id == message.id }
    }
}
