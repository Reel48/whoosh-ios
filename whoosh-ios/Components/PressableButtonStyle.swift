import SwiftUI

/// Generic press feedback for any tappable: scale 0.97 + dim, with a light
/// selection haptic on press-down (web tap-press). Use `.buttonStyle(.pressable)`.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Anim.quick, value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, pressed in pressed ? .selection : nil }
    }
}

/// Primary CTA — full-width blue pill, white text, medium impact on press.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color.brandBlue, in: RoundedRectangle(cornerRadius: Spacing.radius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Anim.quick, value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, pressed in pressed ? .impact(weight: .medium) : nil }
    }
}

/// Secondary neutral fill — same shape, system background.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Spacing.radius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Anim.quick, value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, pressed in pressed ? .selection : nil }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Subtle press scale + haptic for icon/inline buttons.
    static var pressable: PressableButtonStyle { .init() }
}
extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Primary blue CTA.
    static var primaryFill: PrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    /// Secondary neutral fill.
    static var secondaryFill: SecondaryButtonStyle { .init() }
}
