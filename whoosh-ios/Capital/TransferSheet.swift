import SwiftUI
import UIKit

/// Send Whoosh Bucks to another user by @username.
struct TransferSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    /// Called after a successful send so the caller can refresh the balance.
    var onSent: () -> Void = {}

    @State private var recipient = ""
    @State private var amountText = ""
    @State private var memo = ""
    @State private var busy = false
    @State private var error: String?

    private var amount: Double? { Double(amountText) }
    private var canSend: Bool {
        !recipient.trimmingCharacters(in: .whitespaces).isEmpty && (amount ?? 0) > 0 && !busy
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("To") {
                    TextField("@username", text: $recipient)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Amount (WB)") {
                    TextField("0.00", text: $amountText).keyboardType(.decimalPad)
                }
                Section("Note (optional)") {
                    TextField("What's it for?", text: $memo)
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle("Send WB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await send() } }.disabled(!canSend).bold()
                }
            }
        }
    }

    private func send() async {
        guard let amount else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            _ = try await model.api.transfer(
                recipient: recipient.trimmingCharacters(in: .whitespaces),
                amount: amount,
                memo: memo.isEmpty ? nil : memo
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSent()
            dismiss()
        } catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }
}
