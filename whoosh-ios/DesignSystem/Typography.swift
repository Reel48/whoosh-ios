import SwiftUI

/// Whoosh type tokens — Clarika Pro (Geometric titles, Grotesque body) via
/// `Font.ck`. Numerals stay on the system font's monospaced digits so data
/// columns align (the Clarika DEMO digits aren't tabular); revisit once licensed
/// Clarika with tabular figures lands.
extension Font {
    static let wTitle = Font.ck(.largeTitle, .black)     // screen titles (Geometric)
    static let wSection = Font.ck(.title3, .bold)        // section headers (Geometric)
    static let wHeadline = Font.ck(.headline, .semibold) // row titles (Grotesque)
    static let wBody = Font.ck(.body)                    // body copy (Grotesque)
    static let wBodyMedium = Font.ck(.body, .medium)
    static let wCaption = Font.ck(.caption, .semibold)
    /// Fixed-width digits for tickers / balances / counters (system, tabular).
    static let wNumeric = Font.body.monospacedDigit()
}
