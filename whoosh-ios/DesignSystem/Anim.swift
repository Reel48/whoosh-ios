import SwiftUI

/// Named animation curves ported from the web app's motion tokens
/// (`globals.css`). Hybrid personality: `snappy` for core/navigation/Capital,
/// `playful` for chat + rewards.
enum Anim {
    /// Core / navigation / Capital — ease-out, short (web `--ease-out`, ~200ms).
    static let snappy = Animation.spring(response: 0.30, dampingFraction: 0.90)
    /// Chat + rewards — springy with gentle overshoot (web `--ease-spring`).
    static let playful = Animation.spring(response: 0.40, dampingFraction: 0.62)
    /// Quick ease-out for presses / toggles (web `--dur-fast` 120ms).
    static let quick = Animation.easeOut(duration: 0.12)
    /// Standard ease-out (web `--dur-base` 200ms).
    static let base = Animation.easeOut(duration: 0.20)
    /// Number count-up (web Ticker, 600ms cubic ease-out).
    static let count = Animation.easeOut(duration: 0.60)
    /// Per-item stagger step for list/reveal entrances (web Reveal, 60ms).
    static let staggerStep: Double = 0.06

    /// The animation, or `nil` (instant) when Reduce Motion is on.
    static func maybe(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
