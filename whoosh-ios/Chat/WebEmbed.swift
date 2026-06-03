import SwiftUI
import WebKit

/// Renders X (Twitter) and Instagram posts using each platform's **official
/// embed** inside a `WKWebView`, so the tweet/post shows its real text, images,
/// and video exactly as the platform renders it. Apple's `LinkPresentation`
/// returns almost nothing for these hosts (they block scrapers), so the stock
/// metadata card can't show their content — this can.
struct SocialEmbed: View {
    enum Kind { case tweet, instagram }
    let url: URL
    let kind: Kind
    @Environment(\.colorScheme) private var scheme
    @State private var height: CGFloat = 220

    var body: some View {
        WebEmbedView(html: Self.html(url: url, kind: kind, dark: scheme == .dark),
                     baseURL: Self.baseURL(kind),
                     height: $height)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.top, 4)
    }

    /// Classify a URL as a tweet/IG post, or nil if it's neither (→ normal card).
    static func kind(for url: URL) -> Kind? {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        if (host.contains("twitter.com") || host.contains("x.com")), path.contains("/status/") { return .tweet }
        if host.contains("instagram.com"), path.contains("/p/") || path.contains("/reel/") || path.contains("/tv/") {
            return .instagram
        }
        return nil
    }

    private static func baseURL(_ kind: Kind) -> URL? {
        switch kind {
        case .tweet: return URL(string: "https://platform.twitter.com")
        case .instagram: return URL(string: "https://www.instagram.com")
        }
    }

    private static func html(url: URL, kind: Kind, dark: Bool) -> String {
        let head = """
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;padding:0;background:transparent;overflow:hidden;}
        .twitter-tweet,.instagram-media{margin:0 auto !important;}</style>
        """
        let resize = """
        <script>
          function _send(){ try { window.webkit.messageHandlers.resize.postMessage(document.body.scrollHeight); } catch(e){} }
          new ResizeObserver(_send).observe(document.body);
          window.addEventListener('load', _send);
          [300,800,1500,3000].forEach(function(t){ setTimeout(_send, t); });
        </script>
        """
        let embed: String
        switch kind {
        case .tweet:
            embed = """
            <blockquote class="twitter-tweet" data-dnt="true" data-theme="\(dark ? "dark" : "light")">
            <a href="\(url.absoluteString)"></a></blockquote>
            <script async src="https://platform.twitter.com/widgets.js"></script>
            """
        case .instagram:
            embed = """
            <blockquote class="instagram-media" data-instgrm-captioned
              data-instgrm-permalink="\(url.absoluteString)" data-instgrm-version="14"
              style="width:100%;min-width:0;margin:0;"></blockquote>
            <script async src="https://www.instagram.com/embed.js"></script>
            """
        }
        return "<!doctype html><html><head>\(head)</head><body>\(embed)\(resize)</body></html>"
    }
}

/// `WKWebView` wrapper that loads embed HTML and reports its content height back
/// (the platform widgets render asynchronously, so we observe size changes).
private struct WebEmbedView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "resize")
        let web = WKWebView(frame: .zero, configuration: config)
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.loadHTMLString(html, baseURL: baseURL)
        context.coordinator.loadedHTML = html
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        // Reload only if the HTML actually changed (e.g. light/dark switch).
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            web.loadHTMLString(html, baseURL: baseURL)
        }
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "resize")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        var loadedHTML: String?
        init(height: Binding<CGFloat>) { _height = height }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let value = message.body as? CGFloat ?? (message.body as? NSNumber).map({ CGFloat(truncating: $0) }) else { return }
            let clamped = min(max(value, 80), 1400)
            if abs(clamped - height) > 1 {
                DispatchQueue.main.async { self.height = clamped }
            }
        }
    }
}
