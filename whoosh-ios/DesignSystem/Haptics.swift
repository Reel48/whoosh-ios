import UIKit

/// Imperative haptics for use inside async actions / callbacks (button styles
/// use SwiftUI `.sensoryFeedback` directly). Generalizes the UIKit feedback the
/// SwipeDeck already uses.
@MainActor
enum Haptics {
    /// Light selection tick — toggles, filters, taps.
    static func tap() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    /// Physical impact — primary actions, reactions.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    /// Completion — send, claim, level up.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    /// Error / rejected input.
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
