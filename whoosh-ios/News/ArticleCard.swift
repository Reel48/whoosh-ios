import SwiftUI

/// A single news card: image, headline, summary, byline + a tap-to-read link.
struct ArticleCard: View {
    let article: Article

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
                .frame(height: 200)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(article.title).font(.title3.bold()).lineLimit(4)
                if !article.description.isEmpty {
                    Text(article.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(6)
                }
                Spacer(minLength: 0)
                HStack {
                    if let by = article.author, !by.isEmpty {
                        Text(by).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if let date = relativeDate { Text(date).font(.caption).foregroundStyle(.tertiary) }
                }
                if let link = URL(string: article.link) {
                    Link(destination: link) {
                        Label("Read", systemImage: "safari").font(.footnote.bold())
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
