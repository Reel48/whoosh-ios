import SwiftUI

/// The logged-in landing — the app opens straight here (no marketing page).
/// Backed by the single `GET /api/v1/home` aggregate. Section tabs are stubs
/// for now (Capital / Fantasy / Pool / News come next).
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var home: Home?
    @State private var error: String?

    var body: some View {
        TabView {
            NavigationStack { landing }
                .tabItem { Label("Home", systemImage: "house.fill") }
            CapitalView()
                .tabItem { Label("Capital", systemImage: "bolt.fill") }
            FantasyView()
                .tabItem { Label("Fantasy", systemImage: "football.fill") }
            NewsView()
                .tabItem { Label("News", systemImage: "newspaper.fill") }
            NavigationStack { AccountView() }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .task { await load() }
    }

    private var landing: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome, @\(model.currentUsername)").font(.title2.bold())

                if let article = home?.topArticle {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top story").font(.caption).foregroundStyle(.secondary)
                        Text(article.title).font(.headline)
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                ForEach(home?.sections ?? []) { section in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(section.label).font(.headline)
                            Text(section.tagline).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !section.live {
                            Text("Soon").font(.caption2).padding(4)
                                .background(Color(.secondarySystemBackground)).clipShape(Capsule())
                        }
                    }
                    .padding().frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .padding()
        }
        .navigationTitle("Whoosh")
    }

    private func load() async {
        do { home = try await model.api.home() }
        catch let e as APIError { self.error = e.message }
        catch { self.error = error.localizedDescription }
    }
}

#Preview {
    HomeView().environmentObject(AppModel())
}
