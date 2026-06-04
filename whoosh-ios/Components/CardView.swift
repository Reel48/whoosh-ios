import SwiftUI

/// Consistent card container: padding, secondary background, rounded corners.
/// Use to replace ad-hoc `.padding().background(...).clipShape(...)` blocks.
struct CardView<Content: View>: View {
    var padding: CGFloat = Spacing.lg
    var alignment: HorizontalAlignment = .leading
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Spacing.radius))
    }
}
