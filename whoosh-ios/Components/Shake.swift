import SwiftUI

/// A quick horizontal shake to flag an error (web t-input-shake). Increment
/// `trigger` (e.g. an error counter) to play it. No-op under Reduce Motion.
private struct ShakeModifier: ViewModifier {
    var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: CGFloat(trigger)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: trigger)
    }
}

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        // ~3 oscillations of ±6pt as the value interpolates by 1.
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(animatableData * .pi * 3), y: 0))
    }
}

extension View {
    func shake(trigger: Int) -> some View { modifier(ShakeModifier(trigger: trigger)) }
}
