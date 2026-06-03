import SwiftUI

/// Whoosh Bucks ledger history.
struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var entries: [LedgerEntry] = []
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        List {
            if entries.isEmpty && loaded {
                ContentUnavailableView("No activity yet", systemImage: "list.bullet.rectangle")
            }
            ForEach(entries) { e in
                HStack {
                    Image(systemName: Self.icon(e.kind))
                        .frame(width: 28).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.label(e.kind)).font(.body)
                        Text(e.memo ?? Self.relativeDate(e.createdAt))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(Money.wb(e.amountCents, signed: true))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Money.tint(e.amountCents))
                }
            }
        }
        .navigationTitle("Activity")
        .task { if !loaded { await load() } }
        .overlay { if let error { Text(error).foregroundStyle(.red).font(.footnote) } }
    }

    private func load() async {
        do { entries = try await model.api.activity(); loaded = true }
        catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }

    private static func label(_ kind: String) -> String {
        switch kind {
        case "purchase": return "Bought Whoosh Bucks"
        case "premium_match": return "Premium match"
        case "fantasy_match": return "Fantasy match"
        case "interest": return "Interest"
        case "transfer_in": return "Received transfer"
        case "transfer_out": return "Sent transfer"
        case "bet_stake": return "Wager placed"
        case "bet_payout": return "Wager payout"
        case "invest_buy": return "Bought investment"
        case "invest_sell": return "Sold investment"
        case "invest_dividend": return "Dividend"
        case "daily_bonus": return "Daily bonus"
        case "referral_reward": return "Referral reward"
        case "adjustment": return "Adjustment"
        default: return kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func icon(_ kind: String) -> String {
        switch kind {
        case "purchase", "premium_match": return "creditcard"
        case "interest", "invest_dividend": return "percent"
        case "transfer_in": return "arrow.down.left"
        case "transfer_out": return "arrow.up.right"
        case "bet_stake", "bet_payout": return "dice"
        case "invest_buy", "invest_sell": return "chart.line.uptrend.xyaxis"
        case "daily_bonus", "referral_reward": return "gift"
        default: return "circle"
        }
    }

    private static func relativeDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }
        return date.formatted(.relative(presentation: .named))
    }
}
