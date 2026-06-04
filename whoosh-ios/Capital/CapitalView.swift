import SwiftUI
import UIKit

/// The Capital wallet dashboard — balance, the Swift Charts equity curve,
/// allocation, holdings, and a live market ticker. Read-only this pass.
struct CapitalView: View {
    @EnvironmentObject private var model: AppModel

    @State private var dashboard: Dashboard?
    @State private var ticker: [TickerQuote] = []
    @State private var bonus: BonusStatus?
    @State private var error: String?
    @State private var loaded = false
    @State private var showBuy = false
    @State private var showTransfer = false
    @State private var claimingBonus = false
    @State private var bonusMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Whoosh Capital")
                        .font(.largeTitle.bold())
                        .padding(.horizontal)
                    if !ticker.isEmpty { TickerStrip(quotes: ticker) }
                    balanceHero
                    if bonus?.available == true { bonusBanner }
                    actionsRow
                    EquityChart(series: dashboard?.balanceSeries ?? [])
                        .padding(.horizontal)
                        .opacity(dashboard == nil ? 0 : 1)
                    allocationStrip
                    VStack(spacing: 10) {
                        navRow("Invest", "chart.line.uptrend.xyaxis") { InvestView() }
                        navRow("Bets", "dice.fill") { BetsView() }
                    }
                    .padding(.horizontal)
                    positionsSection
                    if let error { Text(error).foregroundStyle(.red).font(.footnote).padding(.horizontal) }
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .toolbar(.hidden, for: .navigationBar)
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
            actionButton("Bonus", "gift.fill", busy: claimingBonus,
                         badge: bonus?.available == true) { Task { await claimBonus() } }
            NavigationLink {
                ActivityView()
            } label: {
                actionLabel("Activity", "list.bullet")
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal)
    }

    private func actionButton(_ title: String, _ icon: String, busy: Bool = false,
                              badge: Bool = false, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            if busy { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12)) }
            else { actionLabel(title, icon, badge: badge) }
        }
        .buttonStyle(.pressable)
        .disabled(busy)
    }

    private func actionLabel(_ title: String, _ icon: String, badge: Bool = false) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.body)
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if badge {
                Circle().fill(Color.red).frame(width: 9, height: 9).padding(6)
            }
        }
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
        .buttonStyle(.pressable)
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
            withAnimation { bonus = BonusStatus(available: false, streak: r.streak) }
            await load()
        } catch let e as APIError { bonusMessage = e.message }
        catch { bonusMessage = error.localizedDescription }
    }

    // MARK: Balance hero

    private var balanceHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Total balance").font(.subheadline).foregroundStyle(.secondary)
            if let d = dashboard {
                CountUpText(value: Double(d.allocation.totalEquityCents), format: { Money.wb(Int($0)) })
                    .font(.system(size: 40, weight: .bold, design: .rounded))
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
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Skeleton(width: 190, height: 40, cornerRadius: 10)
                    Skeleton(width: 140, height: 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    // MARK: Bonus banner

    @State private var bonusPulse = false
    private var bonusBanner: some View {
        Button { Task { await claimBonus() } } label: {
            HStack(spacing: 12) {
                Image(systemName: "gift.fill").font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your daily bonus is ready").font(.subheadline.bold())
                    Text(((bonus?.streak ?? 0) > 0 ? "Keep your \(bonus!.streak)-day streak alive — " : "")
                         + "tap to claim").font(.caption)
                }
                Spacer()
                if claimingBonus { ProgressView() }
                else { Image(systemName: "chevron.right") }
            }
            .padding()
            .foregroundStyle(Color.whooshInk)
            .background(Color.whooshLime)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(bonusPulse ? 1.02 : 1.0)
            .padding(.horizontal)
        }
        .buttonStyle(.pressable)
        .disabled(claimingBonus)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { bonusPulse = true }
        }
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
            Text(Money.wb(cents)).font(.callout.bold())
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
                ForEach(Array(positions.enumerated()), id: \.element.id) { i, p in
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
                    .reveal(index: i)
                }
            } else if dashboard != nil {
                Text("No investments yet").font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
            }
        }
    }

    // MARK: Actions

    private func load(haptic: Bool = false) async {
        error = nil
        async let d = try? model.api.wallet()
        async let t = try? model.api.ticker()
        async let b = try? model.api.bonusStatus()
        let (dash, tick, bon) = await (d, t, b)
        withAnimation(.easeOut(duration: 0.35)) {
            dashboard = dash
            ticker = tick ?? []
            bonus = bon
        }
        if dashboard == nil { error = "Couldn't load your wallet." }
        if haptic { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
}

#Preview {
    CapitalView().environmentObject(AppModel())
}
