import SwiftUI

/// A pick'em / survivor pool. The app's job here is simple: have you joined
/// (paid)? If so, deep-link straight into the Sleeper app. If not, offer the
/// entry-fee checkout (web Stripe link-out).
struct PoolDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL
    let poolId: String
    let title: String

    @State private var pool: PoolDetail?
    @State private var loaded = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            if let p = pool {
                TeamAvatar(url: p.logoUrl, name: p.displayName, size: 88)
                    .padding(.top, 24)
                VStack(spacing: 4) {
                    Text(p.displayName).font(.title2.bold()).multilineTextAlignment(.center)
                    Text(summary(p)).font(.subheadline).foregroundStyle(.secondary)
                }

                if p.joined {
                    Label("You're in this pool", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.whooshGreen)
                    Button { if let url = p.sleeperOpenURL { openURL(url) } } label: {
                        Label("Open in Sleeper", systemImage: "arrow.up.forward.app.fill")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.whooshLime).foregroundStyle(Color.whooshInk)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Join this pool to play.").font(.subheadline).foregroundStyle(.secondary)
                    Button { Task { await join(p) } } label: {
                        Group {
                            if busy { ProgressView() }
                            else { Text(joinLabel(p)).bold() }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.whooshLime).foregroundStyle(Color.whooshInk)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain).disabled(busy)
                    Text("Opens secure checkout in your browser.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }

                if let error { Text(error).foregroundStyle(.bad).font(.footnote) }
            } else if loaded {
                ContentUnavailableView("Pool unavailable", systemImage: "person.3")
            } else {
                ProgressView()
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if !loaded { await load() } }
    }

    private func summary(_ p: PoolDetail) -> String {
        let kind = p.kind == "survivor" ? "Survivor" : "Pick'em"
        if p.kind == "survivor" {
            return "\(kind) · \(p.aliveCount ?? p.totalEntries) alive of \(p.totalEntries)"
        }
        return "\(kind) · \(p.totalEntries) entries"
    }

    private func joinLabel(_ p: PoolDetail) -> String {
        if let fee = p.config.entryFeeCents, fee > 0 { return "Join — \(Money.wb(fee))" }
        return "Join pool"
    }

    private func load() async {
        pool = try? await model.api.fantasyPool(poolId)
        loaded = true
    }

    private func join(_ p: PoolDetail) async {
        guard let groupKey = p.config.groupKey else { error = "This pool isn't open for sign-up."; return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let url = try await model.api.fantasyCheckout(groupKey: groupKey)
            openURL(url)
        } catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }
}
