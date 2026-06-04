import SwiftUI

/// Sports news: a per-sport **Swipe** deck (keep/pass to build the community
/// feed), the **Community** feed of kept articles, and **My Keeps**.
struct NewsView: View {
    @EnvironmentObject private var model: AppModel

    private enum Mode: String, CaseIterable { case swipe = "Swipe", community = "Community", mine = "My Keeps" }
    @State private var mode: Mode = .swipe
    @State private var sport = "all"
    @State private var deck: [Article] = []
    @State private var loadingDeck = false
    @State private var community: [WhooshEntry] = []
    @State private var mineEntries: [WhooshEntry] = []
    @State private var games: [Game] = []
    @StateObject private var logos = LogoStore()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Sports News")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal).padding(.top, 8).padding(.bottom, 10)

                // Live ESPN scoreboard, pinned across all modes (web parity).
                if !games.isEmpty {
                    ScoreTicker(games: games, logos: logos.images)
                        .padding(.bottom, 10)
                        .transition(.opacity)
                }

                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal).padding(.bottom, 8)

                switch mode {
                case .swipe: swipeMode
                case .community: FeedList(entries: community, empty: "No kept articles yet")
                case .mine: FeedList(entries: mineEntries, empty: "You haven't kept any articles yet")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: mode) { await loadForMode() }
            .task { await refreshScoresLoop() }
        }
    }

    /// Poll live scores every ~45s for the view's lifetime (mirrors web's 45s).
    private func refreshScoresLoop() async {
        while !Task.isCancelled {
            if let g = try? await model.api.scores() {
                withAnimation(.easeInOut) { games = g }
                // Preload logos here (stable parent), not inside the animating
                // marquee — see LogoStore for why.
                let urls = g.flatMap { [$0.away.logo, $0.home.logo].compactMap { $0 } }
                await logos.prefetch(urls)
            }
            try? await Task.sleep(for: .seconds(45))
        }
    }

    // MARK: Swipe

    private var swipeMode: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NewsCatalog.sports) { s in
                        Button { if sport != s.key { sport = s.key; Task { await loadDeck() } } } label: {
                            Text(s.label).font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(sport == s.key ? Color.brandBlue : Color(.secondarySystemBackground))
                                .foregroundStyle(sport == s.key ? Color.white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            if loadingDeck && deck.isEmpty {
                Spacer(); ProgressView(); Spacer()
            } else {
                SwipeDeck(
                    articles: $deck,
                    sportLabel: NewsCatalog.sports.first { $0.key == sport }?.label,
                    onDecide: { article, direction in
                        // On the ALL feed, attribute the keep to the card's own
                        // sport so it counts toward the right chat channel.
                        _ = try? await model.api.swipe(sport: article.sport ?? sport, direction: direction, article: article)
                    },
                    onUndo: { article in
                        _ = try? await model.api.undoSwipe(guid: article.guid)
                    }
                )
            }
        }
    }

    // MARK: Loading

    private func loadForMode() async {
        switch mode {
        case .swipe: if deck.isEmpty { await loadDeck() }
        case .community:
            community = (try? await model.api.newsFeed())?.entries ?? []
        case .mine:
            mineEntries = (try? await model.api.newsFeed(mine: true))?.entries ?? []
        }
    }

    private func loadDeck() async {
        loadingDeck = true
        defer { loadingDeck = false }
        deck = (try? await model.api.newsFeed(sport: sport))?.articles ?? []
    }
}

/// A scrollable list of kept articles (Whoosh feed / My Keeps).
private struct FeedList: View {
    let entries: [WhooshEntry]
    let empty: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        if entries.isEmpty {
            EmptyStateCard(icon: "newspaper", title: empty)
        } else {
            List(entries) { e in
                HStack(spacing: 12) {
                    if let urlStr = e.imageUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: {
                            Color(.tertiarySystemBackground)
                        }
                        .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(e.title).font(.subheadline.weight(.semibold)).lineLimit(3)
                        Label("\(e.points)", systemImage: "hand.thumbsup.fill")
                            .font(.caption2).foregroundStyle(Color.whooshGreen)
                    }
                    Spacer(minLength: 0)
                    if let link = URL(string: e.link) {
                        ShareLink(item: link) { Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary) }
                            .buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { if let link = URL(string: e.link) { openURL(link) } }
            }
            .listStyle(.plain)
        }
    }
}
