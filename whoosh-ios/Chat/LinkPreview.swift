import SwiftUI
import LinkPresentation

/// A rich preview for a single URL in a chat message. Direct image links render
/// inline; everything else builds a custom card from `LPLinkMetadata` — the
/// preview image is shown at its **natural aspect ratio**, full message-column
/// width (a YouTube link looks like a 16:9 video, an article shows its full OG
/// image), with a title/host footer. Tapping opens the link via the system.
struct LinkPreview: View {
    let url: URL
    @Environment(\.openURL) private var openURL

    private static let imageExts: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp"]
    private var isImage: Bool { Self.imageExts.contains(url.pathExtension.lowercased()) }

    var body: some View {
        if let kind = SocialEmbed.kind(for: url) {
            SocialEmbed(url: url, kind: kind)
        } else if isImage {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)).frame(height: 160)
            }
            .frame(maxWidth: .infinity, maxHeight: 380, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture { openURL(url) }
            .padding(.top, 4)
        } else {
            LinkCard(url: url)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }
}

/// Custom embed built from fetched metadata: big image at its real aspect ratio
/// + title/host footer. Falls back to a tappable chip while loading / on failure.
private struct LinkCard: View {
    let url: URL
    @State private var metadata: LPLinkMetadata?
    @State private var image: UIImage?
    @State private var failed = false
    @Environment(\.openURL) private var openURL

    private var isVideo: Bool {
        let h = (url.host ?? "").lowercased()
        return ["youtube", "youtu.be", "vimeo", "twitch", "tiktok"].contains { h.contains($0) }
    }

    var body: some View {
        Group {
            if let metadata {
                card(metadata)
            } else if failed {
                LinkChip(url: url)
            } else {
                LinkChip(url: url, loading: true)
            }
        }
        .task(id: url) { await loadMetadata() }
    }

    private func card(_ md: LPLinkMetadata) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
                    if isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.4), radius: 6)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(md.title ?? url.host ?? url.absoluteString)
                    .font(.ck(.subheadline, .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                Text(url.host ?? url.absoluteString).font(.ck(.caption2)).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { openURL(url) }
    }

    private func loadMetadata() async {
        var md = LinkMetadataCache.shared.cached(url)
        if md == nil { md = await LinkMetadataCache.shared.fetch(url) }
        guard let md else { failed = true; return }
        metadata = md
        if let provider = md.imageProvider ?? md.iconProvider {
            image = await Self.loadImage(provider)
        }
    }

    private static func loadImage(_ provider: NSItemProvider) async -> UIImage? {
        guard provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { cont in
            provider.loadObject(ofClass: UIImage.self) { obj, _ in cont.resume(returning: obj as? UIImage) }
        }
    }
}

/// Lightweight fallback: host + truncated URL, tappable.
private struct LinkChip: View {
    let url: URL
    var loading = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: loading ? "link" : "safari")
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(url.host ?? url.absoluteString).font(.ck(.subheadline, .semibold)).lineLimit(1)
                Text(url.absoluteString).font(.ck(.caption2)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { openURL(url) }
    }
}

/// Process-wide metadata cache with in-flight de-duplication.
actor LinkMetadataCache {
    static let shared = LinkMetadataCache()
    private var store: [URL: LPLinkMetadata] = [:]
    private var inFlight: [URL: Task<LPLinkMetadata?, Never>] = [:]

    /// Synchronous cache peek for instant render when already fetched.
    nonisolated func cached(_ url: URL) -> LPLinkMetadata? { Self.sync[url] }
    private nonisolated(unsafe) static var sync: [URL: LPLinkMetadata] = [:]

    func fetch(_ url: URL) async -> LPLinkMetadata? {
        if let hit = store[url] { return hit }
        if let task = inFlight[url] { return await task.value }
        let task = Task<LPLinkMetadata?, Never> {
            await withCheckedContinuation { (cont: CheckedContinuation<LPLinkMetadata?, Never>) in
                let provider = LPMetadataProvider()
                provider.startFetchingMetadata(for: url) { meta, _ in cont.resume(returning: meta) }
            }
        }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        if let result { store[url] = result; Self.sync[url] = result }
        return result
    }
}
