import SwiftUI

/// Admin-only: create custom chat roles and assign/remove them for members.
/// (System roles member/premium/admin are managed automatically and aren't
/// assignable here.)
struct ChatRoleAdminView: View {
    @EnvironmentObject private var model: AppModel
    @State private var roles: [ChatRole] = []
    @State private var newKey = ""
    @State private var newName = ""
    @State private var newColor = "#5865F2"
    @State private var error: String?
    @State private var assignTarget: ChatMember?

    var body: some View {
        List {
            Section("Roles") {
                ForEach(roles) { r in
                    HStack {
                        Circle().fill(Color(hex: r.color)).frame(width: 12, height: 12)
                        Text(r.name)
                        Spacer()
                        Text(r.key).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Create role") {
                TextField("key (e.g. vip)", text: $newKey).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Display name", text: $newName)
                TextField("Color hex (#rrggbb)", text: $newColor).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Create role") { Task { await create() } }
                    .disabled(newKey.isEmpty || newName.isEmpty)
            }

            Section("Assign to member") {
                NavigationLink {
                    MemberPickerView { member in assignTarget = member }
                } label: {
                    LabeledContent("Member", value: assignTarget.map { "@\($0.username)" } ?? "Choose…")
                }
                if let target = assignTarget {
                    ForEach(roles) { r in
                        HStack {
                            Circle().fill(Color(hex: r.color)).frame(width: 10, height: 10)
                            Text(r.name)
                            Spacer()
                            Button("Assign") { Task { await assign(target, r, on: true) } }.font(.caption)
                            Button("Remove", role: .destructive) { Task { await assign(target, r, on: false) } }.font(.caption)
                        }
                    }
                }
            }

            if let error { Text(error).foregroundStyle(.red).font(.footnote) }
        }
        .navigationTitle("Chat Roles")
        .navigationBarTitleDisplayMode(.inline)
        .task { roles = (try? await model.api.chatRoles()) ?? [] }
    }

    private func create() async {
        do {
            _ = try await model.api.createChatRole(key: newKey, name: newName, color: newColor, priority: 10)
            newKey = ""; newName = ""; error = nil
            roles = (try? await model.api.chatRoles()) ?? []
        } catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }

    private func assign(_ member: ChatMember, _ role: ChatRole, on: Bool) async {
        do { try await model.api.assignChatRole(userId: member.id, roleId: role.id, on: on); error = nil }
        catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }
}

/// Search members by @handle and pick one.
private struct MemberPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onPick: (ChatMember) -> Void
    @State private var query = ""
    @State private var results: [ChatMember] = []

    var body: some View {
        List(results) { m in
            Button { onPick(m); dismiss() } label: {
                HStack { ChatAvatar(url: m.avatarUrl, size: 28); Text("@\(m.username)") }
            }
        }
        .searchable(text: $query)
        .navigationTitle("Pick member")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: query) {
            guard query.count >= 1 else { results = []; return }
            results = (try? await model.api.chatMembers(query: query)) ?? []
        }
    }
}
