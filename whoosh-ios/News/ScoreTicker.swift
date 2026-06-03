import SwiftUI

/// A thin, continuously auto-scrolling live-scores strip pinned to the top of
/// the News section (ESPN-style) — the native twin of the web's
/// `components/news/ScoreTicker.tsx`. The row is duplicated so the leftward
/// glide loops seamlessly, and the whole strip is bounded to the container
/// width via a fixed-height `GeometryReader` + clip so its (wide) content can
/// never stretch the page (same technique as `Capital/TickerStrip.swift`).
/// Renders nothing when there are no games.
struct ScoreTicker: View {
    let games: [Game]
    private let spacing: CGFloat = 8
    private let speed: CGFloat = 38       // points per second
    private let height: CGFloat = 66

    @State private var offset: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: spacing) {
                row
                row
            }
            .fixedSize()
            .offset(x: offset)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { measure(g.size.width) }
                        .onChange(of: g.size.width) { _, w in measure(w) }
                }
            )
        }
        .frame(height: height)
        .clipped()
    }

    private var row: some View {
        HStack(spacing: spacing) {
            ForEach(games) { ScoreCard(game: $0) }
        }
        .padding(.leading, spacing)
    }

    /// `width` is the doubled HStack's width → one row is (width - spacing) / 2.
    private func measure(_ width: CGFloat) {
        let single = (width - spacing) / 2
        guard single > 0, abs(single - rowWidth) > 0.5 else { return }
        rowWidth = single
        animate()
    }

    private func animate() {
        let distance = rowWidth + spacing
        offset = 0
        withAnimation(.linear(duration: Double(distance) / Double(speed)).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}

/// A single compact game card: away/home rows (logo · abbr · score) and a
/// footer with the league label + a status line (live → red dot + clock,
/// upcoming → kickoff time, final → "Final" with the loser dimmed).
private struct ScoreCard: View {
    let game: Game
    @Environment(\.openURL) private var openURL

    private var live: Bool { game.state == "in" }
    private var showScores: Bool { game.state != "pre" }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            teamRow(game.away, dim: awayDim)
            teamRow(game.home, dim: homeDim)
            HStack(spacing: 4) {
                Text(game.league)
                    .font(.system(size: 9, weight: .bold)).textCase(.uppercase)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 2)
                if live {
                    Circle().fill(Color.red).frame(width: 5, height: 5)
                }
                Text(status)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(live ? Color.red : .secondary)
                    .lineLimit(1)
            }
            .padding(.top, 1)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(width: 162, height: 60)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { if let s = game.link, let url = URL(string: s) { openURL(url) } }
    }

    private func teamRow(_ t: ScoreTeam, dim: Bool) -> some View {
        HStack(spacing: 5) {
            if let s = t.logo, let url = URL(string: s) {
                AsyncImage(url: url) { img in img.resizable().scaledToFit() } placeholder: { Color.clear }
                    .frame(width: 16, height: 16)
            } else {
                Color.clear.frame(width: 16, height: 16)
            }
            Text(t.abbr).font(.caption.weight(.bold))
            Spacer(minLength: 4)
            if showScores, let score = t.score {
                Text(score).font(.caption.weight(.heavy)).monospacedDigit()
            }
        }
        .foregroundStyle(dim ? Color.secondary : Color.primary)
    }

    /// Upcoming games show the kickoff time; live/final carry ESPN's status line.
    private var status: String {
        if game.state == "pre", let iso = game.startsAt,
           let date = ISO8601DateFormatter().date(from: iso) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return game.detail
    }

    // Dim the loser once the game is final.
    private var awayDim: Bool { game.state == "post" && num(game.home.score) > num(game.away.score) }
    private var homeDim: Bool { game.state == "post" && num(game.away.score) > num(game.home.score) }
    private func num(_ s: String?) -> Int { Int(s ?? "") ?? 0 }
}
