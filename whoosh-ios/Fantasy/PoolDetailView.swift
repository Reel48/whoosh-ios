import SwiftUI

/// A pick'em / survivor pool's entries.
struct PoolDetailView: View {
    @EnvironmentObject private var model: AppModel
    let poolId: String
    let title: String

    @State private var pool: PoolDetail?
    @State private var loaded = false

    var body: some View {
        List {
            if let p = pool {
                Section {
                    Text(p.kind == "survivor"
                         ? "\(p.aliveCount ?? p.entries.count) still alive · \(p.totalEntries) entries"
                         : "\(p.totalEntries) entries")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Entries") {
                    ForEach(p.entries) { e in
                        HStack(spacing: 12) {
                            TeamAvatar(url: e.avatarUrl, name: e.name, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.name).font(.body.weight(.medium)).lineLimit(1)
                                Text(e.ownerName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if let eliminated = e.eliminated {
                                Text(eliminated ? "OUT" : "ALIVE")
                                    .font(.caption2.bold())
                                    .foregroundStyle(eliminated ? .red : Color.whooshGreen)
                            }
                        }
                    }
                }
            } else if loaded {
                ContentUnavailableView("Pool unavailable", systemImage: "person.3")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if !loaded { pool = try? await model.api.fantasyPool(poolId); loaded = true } }
    }
}
