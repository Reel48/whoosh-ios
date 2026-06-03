import SwiftUI
import LinkPresentation
import UniformTypeIdentifiers

/// A rich preview for a single URL in a chat message. Direct image links render
/// inline; everything else uses Apple's `LinkPresentation` (so YouTube shows a
/// thumbnail, articles their OG image, X the post, etc.). Metadata is fetched
/// once per URL and cached. Tapping opens the link via the system.
struct LinkPreview: View {
    let url: URL
    @Environment(\.openURL) private var openURL

    private static let imageExts: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp"]
    private var isImage: Bool { Self.imageExts.contains(url.pathExtension.lowercased()) }

    var body: some View {
        if isImage {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color(.secondarySystemBackground)
            }
            .frame(maxWidth: 240, maxHeight: 240)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .onTapGesture { openURL(url) }
            .padding(.top, 4)
        } else {
            LinkMetadataView(url: url)
                .frame(maxWidth: 280, alignment: .leading)
                .padding(.top, 4)
        }
    }
}

/// Wraps `LPLinkView`, driving it from cached/fetched `LPLinkMetadata`. Falls
/// back to a simple tappable chip while loading or if metadata can't be fetched.
private struct LinkMetadataView: View {
    let url: URL
    @State private var metadata: LPLinkMetadata?
    @State private var failed = false

    var body: some View {
        Group {
            if let metadata {
                LPLinkViewRepresentable(metadata: metadata)
            } else if failed {
                LinkChip(url: url)
            } else {
                LinkChip(url: url, loading: true)
            }
        }
        .task(id: url) {
            if let cached = LinkMetadataCache.shared.cached(url) { metadata = cached; return }
            if let fetched = await LinkMetadataCache.shared.fetch(url) { metadata = fetched }
            else { failed = true }
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
                Text(url.host ?? url.absoluteString).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(url.absoluteString).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { openURL(url) }
    }
}

/// `LPLinkView` is self-sizing; we bound its width and let it report height.
private struct LPLinkViewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(metadata: metadata)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LPLinkView, context: Context) -> CGSize? {
        let width = min(proposal.width ?? 280, 280)
        let fit = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        return CGSize(width: width, height: fit.height)
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
                provider.startFetchingMetadata(for: url) { meta, _ in
                    cont.resume(returning: meta)
                }
            }
        }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        if let result { store[url] = result; Self.sync[url] = result }
        return result
    }
}
