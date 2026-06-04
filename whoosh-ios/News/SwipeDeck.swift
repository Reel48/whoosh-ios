import SwiftUI
import UIKit

/// Tinder-style card deck. Swipe right / left (or use the buttons) to decide the
/// top card; haptics fire on commit. Generic over the item + its card view, so
/// News (keep/pass articles) and the Starboard (boost/meh messages) share it.
/// The parent owns the array and records the decision via `onDecide` ("right" /
/// "left"); `onUndo` re-inserts the last card.
struct SwipeDeck<Item: Identifiable, Card: View>: View {
    @Binding var items: [Item]
    var rightLabel: String = "KEEP"
    var leftLabel: String = "PASS"
    var rightColor: Color = .whooshGreen
    var rightIcon: String = "heart.fill"
    var emptyTitle: String = "You're all caught up"
    var emptySubtitle: String = "Check back later."
    /// `direction` is "right" or "left".
    var onDecide: (Item, String) async -> Void
    var onUndo: (Item) async -> Void
    @ViewBuilder var card: (Item) -> Card

    @State private var drag: CGSize = .zero
    @State private var lastSwiped: Item?

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                if items.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(items.prefix(3).enumerated()).reversed(), id: \.element.id) { idx, item in
                        cardView(item, idx: idx)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls
        }
        .frame(maxHeight: .infinity)
        .padding(.bottom, 12)
    }

    // MARK: Cards

    @ViewBuilder
    private func cardView(_ item: Item, idx: Int) -> some View {
        let isTop = idx == 0
        card(item)
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
            stamp(rightLabel, rightColor, opacity: max(0, drag.width) / threshold)
            Spacer()
            stamp(leftLabel, .bad, opacity: max(0, -drag.width) / threshold)
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
            Text(emptyTitle).font(.headline)
            Text(emptySubtitle).font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 28) {
            roundButton("xmark", .bad) { commit("left") }
            roundButton("arrow.uturn.backward", .secondary) { Task { await undo() } }
                .disabled(lastSwiped == nil)
                .opacity(lastSwiped == nil ? 0.4 : 1)
            roundButton(rightIcon, rightColor) { commit("right") }
        }
        .disabled(items.isEmpty)
        .opacity(items.isEmpty ? 0.4 : 1)
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
        guard let top = items.first else { return }
        UIImpactFeedbackGenerator(style: direction == "right" ? .medium : .light).impactOccurred()
        withAnimation(.easeIn(duration: 0.25)) {
            drag = CGSize(width: direction == "right" ? 700 : -700, height: 0)
        }
        lastSwiped = top
        Task {
            await onDecide(top, direction)
            try? await Task.sleep(for: .milliseconds(220))
            drag = .zero
            if items.first?.id == top.id { items.removeFirst() }
        }
    }

    private func undo() async {
        guard let last = lastSwiped else { return }
        await onUndo(last)
        items.insert(last, at: 0)
        lastSwiped = nil
    }
}
