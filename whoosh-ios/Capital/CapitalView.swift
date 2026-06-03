import SwiftUI
import UIKit

/// The Capital wallet dashboard — balance, the Swift Charts equity curve,
/// allocation, holdings, and a live market ticker. Read-only this pass.
struct CapitalView: View {
    @EnvironmentObject private var model: AppModel

    @State private var dashboard: Dashboard?
    @State private var ticker: [TickerQuote] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var balanceHidden = false
    @State private var showBuy = false
    @State private var showTransfer = false
    @State private var claimingBonus = false
    @State private var bonusMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !ticker.isEmpty { TickerStrip(quotes: ticker) }
                    balanceHero
                    actionsRow
                    EquityChart(series: dashboard?.balanceSeries ?? [])
                        .padding(.horizontal)
                    allocationStrip
                    VStack(spacing: 10) {
                        navRow("Invest", "chart.line.uptrend.xyaxis") { InvestView() }
                        navRow("House Bets", "dice.fill") { BetsView() }
                    }
                    .padding(.horizontal)
                    positionsSection
                    if let error { Text(error).foregroundStyle(.red).font(.footnote).padding(.horizontal) }
                }
                .padding(.vertical)
            }
            .navigationTitle("Capital")
            .refreshable { await load(haptic: true) }
            .task { if !loaded { await load(); loaded = true } }
            .sheet(isPresented: $showBuy) { BuyWBSheet() }
            .sheet(isPresented: $showTransfer) { TransferSheet(onSent: { Task { await load() } }) }
            .alert("Daily bonus", isPresented: Binding(get: { bonusMessage != nil },
                                                       set: { if !$0 { bonusMessage = nil } })) {
                Button("Nice") { bonusMessage = nil }
            } message: { Text(bonusMessage ?? "") }
        }
    }

    // MARK: Actions row

    private var actionsRow: some View {
        HStack(spacing: 12) {
            actionButton("Add", "plus") { showBuy = true }
            actionButton("Send", "paperplane.fill") { showTransfer = true }
            actionButton("Bonus", "gift.fill", busy: claimingBonus) { Task { await claimBonus() } }
            NavigationLink {
                ActivityView()
            } label: {
                actionLabel("Activity", "list.bullet")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private func actionButton(_ title: String, _ icon: String, busy: Bool = false,
                              _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            if busy { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12)) }
            else { actionLabel(title, icon) }
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private func actionLabel(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.body)
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func navRow<D: View>(_ title: String, _ icon: String,
                                 @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding().background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func claimBonus() async {
        claimingBonus = true
        defer { claimingBonus = false }
        do {
            let r = try await model.api.claimBonus()
            UINotificationFeedbackGenerator().notificationOccurred(r.claimed ? .success : .warning)
            bonusMessage = r.claimed
                ? "You claimed \(Money.wb(r.amountCents)) — \(r.streak)-day streak! 🔥"
                : "You've already claimed today's bonus."
            await load()
        } catch let e as APIError { bonusMessage = e.message }
        catch { bonusMessage = error.localizedDescription }
    }

    // MARK: Balance hero

    private var balanceHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Total balance").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await toggleHidden() }
                } label: {
                    Image(systemName: balanceHidden ? "eye.slash" : "eye").foregroundStyle(.secondary)
                }
            }
            if let d = dashboard {
                Text(balanceHidden ? "••••••" : Money.wb(d.allocation.totalEquityCents))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                if !balanceHidden {
                    HStack(spacing: 10) {
                        if let day = d.dayChangeCents {
                            Label(Money.wb(day, signed: true),
                                  systemImage: day >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(Money.tint(day))
                        }
                        Text("\(Money.percent(d.returns.totalReturnFraction)) all-time")
                            .foregroundStyle(Money.tint(d.returns.totalReturnCents))
                    }
                    .font(.subheadline.weight(.medium))
                }
            } else {
                Text("$—").font(.system(size: 40, weight: .bold, design: .rounded)).redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal)
    }

    // MARK: Allocation

    private var allocationStrip: some View {
        Group {
            if let a = dashboard?.allocation {
                HStack(spacing: 10) {
                    allocationChip("Cash", a.cashCents, "banknote")
                    allocationChip("Invested", a.investedValueCents, "chart.pie")
                    allocationChip("Wagers", a.openWagersCents, "dice")
                }
                .padding(.horizontal)
            }
        }
    }

    private func allocationChip(_ label: String, _ cents: Int, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(balanceHidden ? "••••" : Money.wb(cents)).font(.callout.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Positions

    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Holdings").font(.headline).padding(.horizontal)
            if let positions = dashboard?.positions, !positions.isEmpty {
                ForEach(positions) { p in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(p.symbol).font(.body.bold())
                            Text("\(p.shares, specifier: "%.4g") shares").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(Money.wb(p.marketValueCents ?? 0)).font(.body)
                            if let day = p.dayChangeCents {
                                Text(Money.wb(day, signed: true)).font(.caption).foregroundStyle(Money.tint(day))
                            }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                }
            } else {
                Text("No investments yet").font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
            }
        }
    }

    // MARK: Actions

    private func load(haptic: Bool = false) async {
        error = nil
        async let d = try? model.api.wallet()
        async let t = try? model.api.ticker()
        dashboard = await d
        ticker = await t ?? []
        if dashboard == nil { error = "Couldn't load your wallet." }
        if haptic { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func toggleHidden() async {
        if balanceHidden {
            // Revealing requires Face ID / passcode.
            if await BiometricGate.authenticate() { balanceHidden = false }
        } else {
            balanceHidden = true
        }
    }
}

#Preview {
    CapitalView().environmentObject(AppModel())
}
