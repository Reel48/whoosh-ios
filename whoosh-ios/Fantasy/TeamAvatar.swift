import SwiftUI

/// Circular team/owner avatar — loads `url` or falls back to a monogram.
struct TeamAvatar: View {
    let url: String?
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let urlStr = url, let u = URL(string: urlStr) {
                AsyncImage(url: u) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else { monogram }
                }
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var monogram: some View {
        ZStack {
            Color.whooshLime.opacity(0.5)
            Text(initials).font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(Color.whooshInk)
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.first ?? " ") }.joined().uppercased()
    }
}
