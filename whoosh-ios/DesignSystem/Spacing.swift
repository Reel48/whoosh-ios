import CoreGraphics

/// The app's spacing scale (the values already used ad-hoc across views, now
/// named). Prefer `Spacing.lg` over a bare `16` so padding stays consistent.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32

    /// Standard corner radius for cards/controls.
    static let radius: CGFloat = 14
    static let radiusSmall: CGFloat = 9
}
