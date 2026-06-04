import SwiftUI

/// Entrance: fade + 8px move-up with a per-index stagger (web Reveal, 60ms step).
/// Reduce Motion → a quick plain fade, no offset.
private struct RevealModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: (shown || reduceMotion) ? 0 : 8)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    withAnimation(.easeOut(duration: 0.2)) { shown = true }
                } else {
                    withAnimation(.easeOut(duration: 0.45).delay(Double(index) * Anim.staggerStep)) { shown = true }
                }
            }
    }
}

extension View {
    /// Staggered fade-up entrance. Pass the row index for the cascade.
    func reveal(index: Int = 0) -> some View { modifier(RevealModifier(index: index)) }
}
