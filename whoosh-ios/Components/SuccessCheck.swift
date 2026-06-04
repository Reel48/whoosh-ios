import SwiftUI

/// An animated success checkmark: the stroke draws in while the mark scales and
/// settles on a spring (web SuccessCheck). For level-ups / claims / confirmations.
struct SuccessCheck: View {
    var size: CGFloat = 64
    var color: Color = .whooshGreen

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trim: CGFloat = 0
    @State private var scale: CGFloat = 0.6
    @State private var shown = false

    var body: some View {
        CheckShape()
            .trim(from: 0, to: trim)
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(shown ? 1 : 0)
            .onAppear(perform: animateIn)
    }

    private func animateIn() {
        if reduceMotion { trim = 1; scale = 1; shown = true; return }
        shown = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { scale = 1 }
        withAnimation(.easeOut(duration: 0.45).delay(0.08)) { trim = 1 }
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.20, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.75))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.28))
        return p
    }
}
