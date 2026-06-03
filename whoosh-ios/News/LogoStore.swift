import SwiftUI
import UIKit
import Combine

/// Loads team-logo images **outside** the scoreboard marquee.
///
/// `ScoreTicker` runs a continuous `.repeatForever` animation; loading images
/// inside it (via `AsyncImage` or a per-cell `.task`) gets disrupted by the
/// constant re-evaluation, so logos flicker or never appear. Instead, the stable
/// `NewsView` parent owns this store, prefetches every logo once, and passes the
/// decoded `UIImage`s into the ticker — which then renders pure static `Image`s
/// that glide exactly like the (already-working) team abbreviations.
@MainActor
final class LogoStore: ObservableObject {
    @Published private(set) var images: [String: UIImage] = [:]

    /// Process-wide cache so logos survive the 45s scores refresh and re-mounts.
    private static let cache = NSCache<NSString, UIImage>()

    /// Load any logos we don't already have. Safe to call repeatedly.
    /// Loads sequentially; each `await` frees the main actor, and each decoded
    /// image is published immediately so the ticker fills in as they arrive.
    func prefetch(_ urls: [String]) async {
        for url in urls where images[url] == nil {
            if let hit = Self.cache.object(forKey: url as NSString) {
                images[url] = hit
                continue
            }
            guard let u = URL(string: url),
                  let (data, _) = try? await URLSession.shared.data(from: u),
                  let img = UIImage(data: data) else { continue }
            Self.cache.setObject(img, forKey: url as NSString)
            images[url] = img
        }
    }
}
