import SwiftUI
import UIKit

/// Tinder-style card deck. Swipe right to **keep** (+1 point), left to **pass**.
/// Drag the top card or use the buttons; haptics fire on commit. The parent owns
/// the article array and records the decision via `onDecide`.
struct SwipeDeck: View {
    @Binding var articles: [Article]
    /// Called when the top card is decided. `direction` is "right" (keep) / "left" (pass).
    var onDecide: (Article, String) async -> Void
    /// Undo the most recent decision (re-inserts the card).
    var onUndo: (Article) async -> Void

    @State private var drag: CGSize = .zero
    @State private var lastSwiped: Article?

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                if articles.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(articles.prefix(3).enumerated()).reversed(), id: \.element.id) { idx, article in
                        cardView(article, idx: idx)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)

            controls
        }
    }

    // MARK: Cards

    @ViewBuilder
    private func cardView(_ article: Article, idx: Int) -> some View {
        let isTop = idx == 0
        ArticleCard(article: article)
            .overlay(alignment: .top) { if isTop { decisionStamps } }
            .scaleEffect(isTop ? 1 : 1 - CGFloat(idx) * 0.04)
            .offset(y: isTop ? 0 : CGFloat(idx) * 12)
            .offset(isTop ? drag : .zero)
            .rotationEffect(.degrees(isTop ? Double(drag.width / 18) : 0))
            .gesture(isTop ? dragGesture : nil)
            .padding(.horizontal, 20)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: drag)
            .allowsHitTesting(isTop)
    }

    private var decisionStamps: some View {
        HStack {
            stamp("KEEP", .whooshGreen, opacity: max(0, drag.width) / threshold)
            Spacer()
            stamp("PASS", .red, opacity: max(0, -drag.width) / threshold)
        }
        .padding(20)
    }

    private func stamp(_ text: String, _ color: Color, opacity: Double) -> some View {
        Text(text).font(.title2.bold()).foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(-12))
            .opacity(min(1, opacity))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(Color.whooshGreen)
            Text("You're all caught up").font(.headline)
            Text("Switch sports or check back later.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 28) {
            roundButton("xmark", .red) { commit("left") }
            roundButton("arrow.uturn.backward", .secondary) { Task { await undo() } }
                .disabled(lastSwiped == nil)
                .opacity(lastSwiped == nil ? 0.4 : 1)
            roundButton("heart.fill", .whooshGreen) { commit("right") }
        }
        .disabled(articles.isEmpty)
        .opacity(articles.isEmpty ? 0.4 : 1)
    }

    private func roundButton(_ icon: String, _ color: Color, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
                .frame(width: 58, height: 58)
                .background(Color(.secondarySystemBackground), in: Circle())
                .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Gesture + commit

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if value.translation.width > threshold { commit("right") }
                else if value.translation.width < -threshold { commit("left") }
                else { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = .zero } }
            }
    }

    private func commit(_ direction: String) {
        guard let top = articles.first else { return }
        UIImpactFeedbackGenerator(style: direction == "right" ? .medium : .light).impactOccurred()
        withAnimation(.easeIn(duration: 0.25)) {
            drag = CGSize(width: direction == "right" ? 700 : -700, height: 0)
        }
        lastSwiped = top
        Task {
            await onDecide(top, direction)
            try? await Task.sleep(for: .milliseconds(220))
            drag = .zero
            if articles.first?.id == top.id { articles.removeFirst() }
        }
    }

    private func undo() async {
        guard let last = lastSwiped else { return }
        await onUndo(last)
        articles.insert(last, at: 0)
        lastSwiped = nil
    }
}
