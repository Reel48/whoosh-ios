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
    /// Logos are preloaded by the parent (`LogoStore`) and rendered as static
    /// images here — never loaded inside this animating view.
    var logos: [String: UIImage] = [:]
    private let spacing: CGFloat = 8
    private let speed: CGFloat = 38       // points per second
    private let height: CGFloat = 72

    @State private var rowWidth: CGFloat = 0
    @State private var start = Date()

    var body: some View {
        // The outer GeometryReader bounds the strip to the container width — the
        // doubled, `.fixedSize()` HStack is far wider than the screen, and
        // without this it propagates that width up and stretches the whole page
        // (the title/picker break). Inside, TimelineView drives the scroll
        // per-frame so text AND the static logo images glide together (a
        // `.repeatForever` `.offset` animation moved the text but not the logos).
        GeometryReader { _ in
            TimelineView(.animation) { timeline in
                let period = rowWidth + spacing
                let off: CGFloat = period > 0
                    ? -CGFloat((timeline.date.timeIntervalSince(start) * Double(speed))
                        .truncatingRemainder(dividingBy: Double(period)))
                    : 0
                HStack(spacing: spacing) {
                    row
                    row
                }
                .fixedSize()
                .offset(x: off)
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onAppear { measure(g.size.width) }
                            .onChange(of: g.size.width) { _, w in measure(w) }
                    }
                )
            }
        }
        .frame(height: height)
        .clipped()
    }

    private var row: some View {
        HStack(spacing: spacing) {
            ForEach(games) { ScoreCard(game: $0, logos: logos) }
        }
        .padding(.leading, spacing)
    }

    /// `width` is the doubled HStack's width → one row is (width - spacing) / 2.
    private func measure(_ width: CGFloat) {
        let single = (width - spacing) / 2
        guard single > 0, abs(single - rowWidth) > 0.5 else { return }
        rowWidth = single
    }
}

/// A single compact game card: away/home rows (logo · abbr · score) and a
/// footer with the league label + a status line (live → red dot + clock,
/// upcoming → kickoff time, final → "Final" with the loser dimmed).
private struct ScoreCard: View {
    let game: Game
    let logos: [String: UIImage]
    @Environment(\.openURL) private var openURL

    private var live: Bool { game.state == "in" }
    private var showScores: Bool { game.state != "pre" }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            teamRow(game.away, dim: awayDim)
            teamRow(game.home, dim: homeDim)
            HStack(spacing: 4) {
                Text(game.league)
                    .font(.system(size: 9, weight: .bold)).textCase(.uppercase)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 2)
                if live {
                    Circle().fill(Color.brandOrange).frame(width: 5, height: 5)
                }
                Text(status)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(live ? Color.brandOrange : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(width: 160, alignment: .leading)   // fixed width, intrinsic height (no clipping)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { if let s = game.link, let url = URL(string: s) { openURL(url) } }
    }

    private func teamRow(_ t: ScoreTeam, dim: Bool) -> some View {
        HStack(spacing: 6) {
            TeamLogo(image: t.logo.flatMap { logos[$0] })
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

/// A team logo — purely presentational. The image is preloaded by `LogoStore`
/// in the stable parent and handed in already decoded, so this is a static
/// `Image` (or a placeholder circle while it's still loading). No async loading
/// happens inside the animating marquee, which is what kept the logos from
/// rendering/gliding before.
private struct TeamLogo: View {
    let image: UIImage?
    private let size: CGFloat = 18

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Circle().fill(Color(.tertiarySystemBackground))
            }
        }
        .frame(width: size, height: size)
    }
}
