import SwiftUI

/// A light typographic scale formalizing the app's existing usage. Optional —
/// use where it improves consistency; system text styles remain fine elsewhere.
extension Font {
    static let wTitle = Font.largeTitle.bold()        // screen titles
    static let wSection = Font.title3.weight(.semibold) // section headers
    static let wHeadline = Font.headline                // row titles
    static let wBody = Font.body                        // body copy
    static let wBodyMedium = Font.body.weight(.medium)
    static let wCaption = Font.caption.weight(.semibold)
    /// Fixed-width digits for tickers / balances / counters.
    static let wNumeric = Font.body.monospacedDigit()
}
