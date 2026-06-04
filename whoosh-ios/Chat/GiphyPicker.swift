import SwiftUI

/// Searchable GIF picker backed by the server-side Giphy proxy. Shows trending
/// by default; typing searches (debounced). Tapping a GIF returns its URL to
/// send as a `kind=gif` message. Opened by the composer's GIF button / `/gif`.
struct GiphyPicker: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var initialQuery: String = ""
    var onPick: (URL) -> Void

    @State private var query = ""
    @State private var gifs: [GifResult] = []
    @State private var loaded = false
    @State private var searchTask: Task<Void, Never>?

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if gifs.isEmpty && loaded {
                    ContentUnavailableView("No GIFs", systemImage: "magnifyingglass").padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(gifs) { g in
                            Button {
                                if let url = URL(string: g.url) { onPick(url) }
                            } label: {
                                AnimatedGIFView(url: URL(string: g.previewUrl)!)
                                    .frame(height: 110)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }
            .overlay { if !loaded { ProgressView() } }
            .searchable(text: $query, prompt: "Search GIFs")
            .navigationTitle("GIFs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image("WhooshWordmark").renderingMode(.template).resizable().scaledToFit()
                        .frame(height: 14).foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .task { query = initialQuery; await load() }
            .onChange(of: query) { _, _ in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    if !Task.isCancelled { await load() }
                }
            }
        }
    }

    private func load() async {
        gifs = (try? await model.api.searchGifs(query: query)) ?? []
        loaded = true
    }
}
