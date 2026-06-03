import SwiftUI

/// Whoosh brand colors (from the web app's globals.css).
extension Color {
    /// `--lime` / `--color-volt-500` = #cef932 — the signature lime green.
    static let whooshLime = Color(red: 206 / 255, green: 249 / 255, blue: 50 / 255)
    /// `--pigment-green` = #009640 — positive / gains.
    static let whooshGreen = Color(red: 0 / 255, green: 150 / 255, blue: 64 / 255)
    /// Near-black ink used for text/marks on bright surfaces.
    static let whooshInk = Color.black
}
