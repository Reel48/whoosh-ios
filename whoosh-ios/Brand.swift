import SwiftUI

/// Whoosh brand colors. The full system lives in `DesignSystem/Palette.swift`
/// (brand vs. semantic). These are kept as aliases so existing call sites still
/// compile — prefer `.brandLime` (identity) and `.good` (positive state).
extension Color {
    /// Deprecated: the signature lime is now `.brandLime` (identity, never "good").
    static let whooshLime = Color(hex: "#cef932")
    /// Deprecated: gains-green is now `.good` (semantic positive state).
    static let whooshGreen = Color(hex: "#009640")
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
