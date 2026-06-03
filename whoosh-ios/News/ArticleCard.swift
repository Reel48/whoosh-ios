import SwiftUI

/// A single news card: a league/source/date strip, image, headline, summary,
/// byline + a tap-to-read link.
struct ArticleCard: View {
    let article: Article
    var sportLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let urlStr = article.imageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color(.tertiarySystemBackground)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                // Context strip: league · source · when
                HStack(spacing: 8) {
                    if let sportLabel {
                        Text(sportLabel.uppercased())
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.whooshLime).foregroundStyle(Color.whooshInk)
                            .clipShape(Capsule())
                    }
                    Text("ESPN").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if let date = relativeDate {
                        Label(date, systemImage: "clock").font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                Text(article.title).font(.title3.bold()).lineLimit(4)
                if !article.description.isEmpty {
                    Text(article.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(8)
                }
                Spacer(minLength: 0)
                HStack {
                    if let by = article.author, !by.isEmpty {
                        Label(by, systemImage: "person.fill").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if let link = URL(string: article.link) {
                        Link(destination: link) {
                            Label("Read", systemImage: "safari").font(.footnote.bold())
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private var relativeDate: String? {
        guard let iso = article.pubDate,
              let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        return date.formatted(.relative(presentation: .named))
    }
}
