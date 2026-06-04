import SwiftUI

/// The Whoosh color system. Two groups, strictly separated so every color
/// carries one meaning:
///
/// • **Brand (identity)** — never means good/bad.
///   - `brandBlue`   PRIMARY: CTAs, primary buttons, current selection, links, send/confirm, self.
///   - `brandLime`   highlight/gamification accent: XP/level/progress, Premium, "new"/unread.
///   - `brandOrange` energy/attention accent: streaks/hot, achievements, live, mentions.
///   - `brandPurple` members: the chat Member role color; also a data/identity accent.
///
/// • **Semantic (state)** — only ever means its state.
///   - `good`    gains(+), wins, online/active, success, available, top rank.
///   - `warning` pending/open, push (tie), questionable, checking, caution.
///   - `bad`     losses(−), errors, lost, destructive, down-direction.
///
/// Exposed on both `Color` (e.g. `Color.good`) and `ShapeStyle` (so the leading-dot
/// form works in `.foregroundStyle(.good)`, `.fill(.bad)`, etc. — mirroring `.red`).
///
/// Accessibility: `brandLime` + `warning` are low-contrast on white — use only as
/// fills (with `whooshInk` text) or accent shapes, never as text/icons on light
/// surfaces. Gain/loss color is always paired with a sign (+/−) + arrow.
private enum Pal {
    static let brandLime   = Color(hex: "#cef932")
    static let brandBlue   = Color(hex: "#0381ed")
    static let brandOrange = Color(hex: "#fc7b00")
    static let brandPurple = Color(hex: "#ae78d2")
    static let good        = Color(hex: "#009640")
    static let warning     = Color(hex: "#fbd12c")
    static let bad         = Color(hex: "#ff0c31")
}

extension Color {
    static let brandLime   = Pal.brandLime
    static let brandBlue   = Pal.brandBlue
    static let brandOrange = Pal.brandOrange
    static let brandPurple = Pal.brandPurple
    static let good        = Pal.good
    static let warning     = Pal.warning
    static let bad         = Pal.bad
}

extension ShapeStyle where Self == Color {
    static var brandLime: Color   { Pal.brandLime }
    static var brandBlue: Color   { Pal.brandBlue }
    static var brandOrange: Color { Pal.brandOrange }
    static var brandPurple: Color { Pal.brandPurple }
    static var good: Color        { Pal.good }
    static var warning: Color     { Pal.warning }
    static var bad: Color         { Pal.bad }
}
