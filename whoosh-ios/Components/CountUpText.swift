import SwiftUI

/// A number that animates to its value (web Ticker). Counts up on appear and
/// rolls on change via the numeric content transition. Inherits the ambient
/// font; digits are tabular so the layout doesn't jitter. Snaps under Reduce Motion.
struct CountUpText: View {
    let value: Double
    var format: (Double) -> String = { String(Int($0.rounded())) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0
    @State private var started = false

    var body: some View {
        Text(format(shown))
            .monospacedDigit()
            .contentTransition(.numericText(value: shown))
            .onAppear {
                guard !started else { return }
                started = true
                if reduceMotion { shown = value }
                else { withAnimation(Anim.count) { shown = value } }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(reduceMotion ? nil : Anim.count) { shown = newValue }
            }
    }
}
