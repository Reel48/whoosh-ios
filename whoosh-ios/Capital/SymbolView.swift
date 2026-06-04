import SwiftUI
import Charts
import UIKit

/// Full stock detail: header (name/price/day change), range-selectable price
/// chart, key stats, buy/sell, and watchlist toggle — parity with the web invest
/// page. Backed by GET /api/v1/wb/symbol.
struct SymbolView: View {
    @EnvironmentObject private var model: AppModel
    let symbol: String

    private let ranges = ["1m", "3m", "6m", "1y", "5y"]
    private let rangeLabels = ["1M", "3M", "6M", "1Y", "5Y"]

    @State private var detail: SymbolDetail?
    @State private var range = "1y"
    @State private var side = "buy"
    @State private var amountText = ""
    @State private var watched = false
    @State private var busy = false
    @State private var loading = true
    @State private var loadFailed = false
    @State private var message: String?
    @State private var isError = false

    private var amount: Double? { Double(amountText) }
    private var priceCents: Int? { detail?.snapshot.regularMarketPriceCents ?? detail?.quote?.priceCents }
    private var dayChangeCents: Int? {
        guard let q = detail?.quote, let prev = q.prevCloseCents else { return nil }
        return q.priceCents - prev
    }

    var body: some View {
        ScrollView {
            if loadFailed && detail == nil {
                failedState
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    chartSection
                    statsSection
                    orderSection
                    if let message {
                        Text(message).foregroundStyle(isError ? Color.bad : Color.good).font(.footnote)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await toggleWatch() } } label: {
                    Image(systemName: watched ? "star.fill" : "star")
                }
            }
        }
        .task {
            watched = ((try? await model.api.watchlist()) ?? []).contains { $0.symbol == symbol }
            await load()
        }
    }

    // MARK: Failed state

    private var failedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(.secondary)
            Text("Couldn't load \(symbol)").font(.headline)
            Text("Market data is taking a moment. Please try again.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button {
                Task { await load() }
            } label: {
                Text("Retry").bold().padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.brandBlue).foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.pressable)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.top, 80)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(detail?.snapshot.longName ?? detail?.profile?.name ?? symbol)
                .font(.headline).foregroundStyle(.secondary).lineLimit(1)
            if let price = priceCents {
                Text(Money.wb(price)).font(.system(size: 34, weight: .bold, design: .rounded))
                if let day = dayChangeCents {
                    Text(Money.wb(day, signed: true)).font(.subheadline.weight(.medium))
                        .foregroundStyle(Money.tint(day))
                }
            } else if loading {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    // MARK: Chart

    private var chartSection: some View {
        VStack(spacing: 8) {
            if let candles = detail?.snapshot.candles, candles.count > 1 {
                let trend = Money.direction(Double(candles.first?.closeCents ?? 0), Double(candles.last?.closeCents ?? 0))
                Chart(candles) { c in
                    LineMark(x: .value("Date", c.date), y: .value("Price", Double(c.closeCents) / 100))
                        .foregroundStyle(trend)
                    AreaMark(x: .value("Date", c.date), y: .value("Price", Double(c.closeCents) / 100))
                        .foregroundStyle(LinearGradient(
                            colors: [trend.opacity(0.45), trend.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom))
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 200).padding(.horizontal)
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground))
                    .frame(height: 200).overlay {
                        if loading { ProgressView() }
                        else { Text("Chart unavailable right now").foregroundStyle(.secondary).font(.footnote) }
                    }
                    .padding(.horizontal)
            }
            Picker("Range", selection: $range) {
                ForEach(Array(ranges.enumerated()), id: \.offset) { i, r in Text(rangeLabels[i]).tag(r) }
            }
            .pickerStyle(.segmented).padding(.horizontal)
            .onChange(of: range) { _, _ in Task { await load() } }
        }
    }

    // MARK: Stats

    private var statsSection: some View {
        Group {
            if let s = detail?.snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Key stats").font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        stat("Day high", s.regularMarketDayHighCents.map { Money.wb($0) })
                        stat("Day low", s.regularMarketDayLowCents.map { Money.wb($0) })
                        stat("52-wk high", s.fiftyTwoWeekHighCents.map { Money.wb($0) })
                        stat("52-wk low", s.fiftyTwoWeekLowCents.map { Money.wb($0) })
                        stat("Volume", s.regularMarketVolume.map(Self.bigNumber))
                        stat("Market cap", detail?.profile?.marketCap.map(Self.bigDollars))
                        stat("Exchange", s.exchange ?? detail?.profile?.exchange)
                        stat("Industry", detail?.profile?.industry)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func stat(_ label: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value ?? "—").font(.callout.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Order

    private var orderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trade").font(.headline)
            Picker("Side", selection: $side) { Text("Buy").tag("buy"); Text("Sell").tag("sell") }
                .pickerStyle(.segmented)
            HStack {
                Text("$")
                TextField("Amount in WB", text: $amountText).keyboardType(.decimalPad)
            }
            .padding(10).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
            Button(action: { Task { await submit() } }) {
                Group { if busy { ProgressView() } else { Text(side == "buy" ? "Buy \(symbol)" : "Sell \(symbol)").bold() } }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.brandBlue).foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity((amount ?? 0) > 0 && !busy ? 1 : 0.5)
            }
            .disabled((amount ?? 0) <= 0 || busy)
        }
        .padding(.horizontal)
    }

    // MARK: Actions

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            detail = try await model.api.symbolDetail(symbol, range: range)
            loadFailed = false
        } catch {
            // Keep any previously-loaded detail (e.g. a range switch that
            // failed) so we don't blank a working screen; only surface the
            // failed state when we have nothing to show.
            if detail == nil { loadFailed = true }
        }
    }

    private func submit() async {
        guard let amount else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            let r = try await model.api.placeOrder(symbol: symbol, side: side, amount: amount, shares: nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isError = false
            message = "\(side == "buy" ? "Bought" : "Sold") \(symbol) — \(Money.wb(r.totalCents))."
            amountText = ""
            await load()
        } catch let e as APIError {
            isError = true; message = e.message
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            isError = true; message = error.localizedDescription
        }
    }

    private func toggleWatch() async {
        let target = !watched
        watched = target
        do { try await model.api.mutateWatchlist(symbol: symbol, add: target) }
        catch { watched = !target }
    }

    // MARK: Formatting

    private static func bigNumber(_ n: Int) -> String {
        let d = Double(n)
        switch d {
        case 1_000_000_000...: return String(format: "%.1fB", d / 1_000_000_000)
        case 1_000_000...: return String(format: "%.1fM", d / 1_000_000)
        case 1_000...: return String(format: "%.1fK", d / 1_000)
        default: return "\(n)"
        }
    }
    private static func bigDollars(_ d: Double) -> String {
        switch d {
        case 1_000_000_000_000...: return String(format: "$%.2fT", d / 1_000_000_000_000)
        case 1_000_000_000...: return String(format: "$%.1fB", d / 1_000_000_000)
        case 1_000_000...: return String(format: "$%.1fM", d / 1_000_000)
        default: return "$\(Int(d))"
        }
    }
}
