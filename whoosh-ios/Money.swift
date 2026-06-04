import SwiftUI

/// Whoosh Bucks formatting — cents → "$1,234.56" — mirroring the web `formatWb`.
/// WB is displayed with a `$` and two decimals.
enum Money {
    private static let fmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// e.g. 123456 → "$1,234.56". `signed` prefixes a + for positives.
    static func wb(_ cents: Int, signed: Bool = false) -> String {
        let dollars = Double(cents) / 100
        let body = "$" + (fmt.string(from: NSNumber(value: abs(dollars))) ?? "0.00")
        if cents < 0 { return "-" + body }
        return signed ? "+" + body : body
    }

    /// e.g. 0.1234 → "+12.3%".
    static func percent(_ fraction: Double) -> String {
        let pct = fraction * 100
        let sign = pct > 0 ? "+" : (pct < 0 ? "" : "")  // negatives carry their own -
        return sign + String(format: "%.1f%%", pct)
    }

    /// Semantic color for a gain/loss value: good (up), bad (down), neutral (flat).
    static func tint(_ value: Int) -> Color {
        value > 0 ? .good : (value < 0 ? .bad : .secondary)
    }

    /// Direction color for a series over a period: good if it ended at/above where
    /// it started, bad if it fell. For charts + balance hero (paired with +/-).
    static func direction(_ start: Double, _ end: Double) -> Color {
        end >= start ? .good : .bad
    }
}
