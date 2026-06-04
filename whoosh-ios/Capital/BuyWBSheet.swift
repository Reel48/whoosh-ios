import SwiftUI

/// Buy Whoosh Bucks. iOS doesn't check out in-app — we fetch a hosted Stripe
/// Checkout URL and open it in the browser (the External Purchase Link flow);
/// the backend webhook credits the WB on completion.
struct BuyWBSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let presets: [Double] = [5, 10, 20, 50, 100]
    @State private var amount: Double = 10
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Buy Whoosh Bucks").font(.title2.weight(.bold))
                    Text("You'll get \(Money.wb(Int(amount * 10 * 100))) WB")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                    ForEach(presets, id: \.self) { p in
                        Button {
                            amount = p
                        } label: {
                            Text("$\(Int(p))").font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(amount == p ? Color.brandBlue : Color(.secondarySystemBackground))
                                .foregroundStyle(amount == p ? Color.white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)

                if let error { Text(error).foregroundStyle(.bad).font(.footnote) }

                Button(action: { Task { await checkout() } }) {
                    Group { if busy { ProgressView() } else { Text("Continue to checkout").bold() } }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.brandBlue).foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(busy)

                Text("Opens secure checkout in your browser.")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func checkout() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            let url = try await model.api.buyWB(amount: amount)
            openURL(url)
            dismiss()
        } catch let e as APIError { error = e.message }
        catch { self.error = error.localizedDescription }
    }
}
