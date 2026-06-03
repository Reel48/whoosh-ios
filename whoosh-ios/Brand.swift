import SwiftUI

/// Whoosh brand colors (from the web app's globals.css).
extension Color {
    /// `--lime` / `--color-volt-500` = #cef932 — the signature lime green.
    static let whooshLime = Color(red: 206 / 255, green: 249 / 255, blue: 50 / 255)
    /// `--pigment-green` = #009640 — positive / gains.
    static let whooshGreen = Color(red: 0 / 255, green: 150 / 255, blue: 64 / 255)
    /// Near-black ink used for text/marks on bright surfaces.
    static let whooshInk = Color.black

    /// Parse a `#rrggbb` (or `#rgb`) hex string; falls back to gray.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased()
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 3 {
            r = Double((v >> 8) & 0xF) / 15; g = Double((v >> 4) & 0xF) / 15; b = Double(v & 0xF) / 15
        } else if s.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255; b = Double(v & 0xFF) / 255
        } else {
            r = 0.6; g = 0.63; b = 0.65
        }
        self = Color(red: r, green: g, blue: b)
    }
}
