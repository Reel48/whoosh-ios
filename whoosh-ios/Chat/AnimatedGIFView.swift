import SwiftUI
import UIKit
import ImageIO

/// Plays an animated GIF from a URL. SwiftUI's `AsyncImage`/`Image` only show a
/// GIF's first frame, so chat GIFs need this: it downloads the data, builds an
/// animated `UIImage` (frames + per-frame delays via ImageIO), and shows it in a
/// `UIImageView`. Decoded images are cached in-memory so they don't re-download
/// while scrolling. Falls back to a static frame for non-animated images.
struct AnimatedGIFView: UIViewRepresentable {
    let url: URL

    private static let cache = NSCache<NSURL, UIImage>()

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        iv.setContentHuggingPriority(.defaultLow, for: .vertical)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        load(into: iv)
        return iv
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}

    private func load(into iv: UIImageView) {
        if let cached = Self.cache.object(forKey: url as NSURL) { iv.image = cached; return }
        let url = self.url
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            let image = Self.animatedImage(data: data) ?? UIImage(data: data)
            guard let image else { return }
            Self.cache.setObject(image, forKey: url as NSURL)
            await MainActor.run { iv.image = image }
        }
    }

    /// Build an animated UIImage from GIF data, honoring per-frame delays.
    static func animatedImage(data: Data) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(src)
        guard count > 1 else { return nil }
        var frames: [UIImage] = []
        var duration = 0.0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            duration += frameDelay(src, i)
            frames.append(UIImage(cgImage: cg))
        }
        guard !frames.isEmpty else { return nil }
        return UIImage.animatedImage(with: frames, duration: duration)
    }

    private static func frameDelay(_ src: CGImageSource, _ index: Int) -> Double {
        let props = CGImageSourceCopyPropertiesAtIndex(src, index, nil) as? [CFString: Any]
        let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
        return delay < 0.02 ? 0.1 : delay   // clamp absurdly fast frames (browser parity)
    }
}
