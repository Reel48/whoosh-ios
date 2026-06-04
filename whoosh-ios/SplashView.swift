import SwiftUI

/// Launch splash: a full lime-green screen with the black lightning bolt fading
/// (and gently scaling) in. Shown for ~2s at launch, then `RootView` advances to
/// account creation. Timing constants live here for easy tweaking.
struct SplashView: View {
    /// How long the bolt takes to fade in.
    private let fadeInDuration: Double = 1.0

    @State private var shown = false

    var body: some View {
        ZStack {
            Color.whooshLime
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image("WhooshBolt")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                Image("WhooshWordmark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
            }
            .foregroundStyle(Color.whooshInk)
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.92)
            .accessibilityLabel("Whoosh")
        }
        .onAppear {
            withAnimation(.easeIn(duration: fadeInDuration)) {
                shown = true
            }
        }
    }
}

#Preview {
    SplashView()
}
