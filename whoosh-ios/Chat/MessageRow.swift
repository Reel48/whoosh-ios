import SwiftUI

/// A single chat message: avatar, role-colored name + level chip, body, optional
/// image, and reaction chips. Long-press for react/edit/delete.
struct MessageRow: View {
    let message: ChatMessage
    var onReact: (String) -> Void
    var canEdit: Bool = false
    var onEdit: () -> Void = {}
    var canDelete: Bool = false
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ChatAvatar(url: message.author.avatarUrl, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(message.author.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: message.author.roleColor))
                    Text("lvl \(message.author.level)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color(.secondarySystemBackground), in: Capsule())
                    Text(Self.time(message.createdAt)).font(.caption2).foregroundStyle(.tertiary)
                    if message.editedAt != nil { Text("(edited)").font(.caption2).foregroundStyle(.tertiary) }
                }
                if !message.body.isEmpty {
                    Text(message.body).font(.body)
                }
                if let urlStr = message.imageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                        Color(.secondarySystemBackground)
                    }
                    .frame(maxWidth: 220, maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if !message.reactions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.reactions) { r in
                            Button { onReact(r.emoji) } label: {
                                Text("\(r.emoji) \(r.count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(r.mine ? Color.whooshLime.opacity(0.4) : Color(.secondarySystemBackground), in: Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button { onReact("⭐") } label: { Label("Star", systemImage: "star") }
            Button { onReact("🔥") } label: { Label("🔥", systemImage: "flame") }
            Button { onReact("😂") } label: { Label("😂", systemImage: "face.smiling") }
            if canEdit { Button { onEdit() } label: { Label("Edit", systemImage: "pencil") } }
            if canDelete { Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") } }
        }
    }

    private static func time(_ iso: String) -> String {
        guard let d = ISO8601DateFormatter().date(from: iso) else { return "" }
        return d.formatted(date: .omitted, time: .shortened)
    }
}

/// Round avatar with an SF-symbol fallback.
struct ChatAvatar: View {
    let url: String?
    var size: CGFloat = 36
    var body: some View {
        Group {
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: {
                    Color(.secondarySystemBackground)
                }
            } else {
                ZStack { Color(.secondarySystemBackground); Image(systemName: "person.fill").foregroundStyle(.secondary) }
            }
        }
        .frame(width: size, height: size).clipShape(Circle())
    }
}
