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

    /// Brand color for a gain/loss value (lime-ish green up, red down, gray flat).
    static func tint(_ value: Int) -> Color {
        value > 0 ? .whooshGreen : (value < 0 ? .red : .secondary)
    }
}
