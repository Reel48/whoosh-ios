import SwiftUI
import UIKit

/// Quote + buy/sell + watchlist toggle for a single symbol.
struct SymbolView: View {
    @EnvironmentObject private var model: AppModel
    let symbol: String

    @State private var quote: Quote?
    @State private var side = "buy"
    @State private var amountText = ""
    @State private var watched = false
    @State private var busy = false
    @State private var message: String?
    @State private var isError = false

    private var amount: Double? { Double(amountText) }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Price")
                    Spacer()
                    if let q = quote {
                        VStack(alignment: .trailing) {
                            Text(Money.wb(q.priceCents)).font(.body.bold())
                            if let day = q.dayChangeCents {
                                Text(Money.wb(day, signed: true)).font(.caption).foregroundStyle(Money.tint(day))
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
            }

            Section("Order") {
                Picker("Side", selection: $side) {
                    Text("Buy").tag("buy"); Text("Sell").tag("sell")
                }.pickerStyle(.segmented)
                TextField("Amount in WB", text: $amountText).keyboardType(.decimalPad)
                Button(side == "buy" ? "Buy \(symbol)" : "Sell \(symbol)") {
                    Task { await submit() }
                }
                .disabled((amount ?? 0) <= 0 || busy)
            }

            if let message {
                Section { Text(message).foregroundStyle(isError ? .red : .green).font(.footnote) }
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
            quote = try? await model.api.quote(symbol)
            watched = ((try? await model.api.watchlist()) ?? []).contains { $0.symbol == symbol }
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
        catch { watched = !target }   // revert on failure
    }
}
