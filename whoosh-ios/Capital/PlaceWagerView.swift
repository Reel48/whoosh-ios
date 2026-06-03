import SwiftUI
import UIKit

/// Place a wager on a chosen event outcome.
struct PlaceWagerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let event: BetEvent
    let outcome: BetOutcome
    var onPlaced: () -> Void = {}

    @State private var stakeText = ""
    @State private var busy = false
    @State private var error: String?

    private var stake: Double? { Double(stakeText) }
    private var potentialCents: Int? {
        guard let stake else { return nil }
        return Int(stake * outcome.oddsDecimal * 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(event.title) {
                    LabeledContent("Pick", value: outcome.label)
                    LabeledContent("Odds", value: String(format: "%.2f×", outcome.oddsDecimal))
                }
                Section("Stake (WB)") {
                    TextField("0.00", text: $stakeText).keyboardType(.decimalPad)
                    if let p = potentialCents {
                        LabeledContent("Potential return", value: Money.wb(p))
                    }
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle("Place wager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Place") { Task { await place() } }
                        .disabled((stake ?? 0) <= 0 || busy).bold()
                }
            }
        }
    }

    private func place() async {
        guard let stake else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await model.api.placeWager(eventId: event.id, outcomeId: outcome.id, stake: stake)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onPlaced()
            dismiss()
        } catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }
}
