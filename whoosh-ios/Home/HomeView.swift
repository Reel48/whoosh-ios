import SwiftUI

/// The logged-in tab shell. Chat is the primary tab — it's how the community
/// has always interacted — followed by Capital, Fantasy, News, and Account.
struct HomeView: View {
    var body: some View {
        TabView {
            ChatHomeView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            CapitalView()
                .tabItem { Label("Capital", systemImage: "bolt.fill") }
            FantasyView()
                .tabItem { Label("Fantasy", systemImage: "football.fill") }
            NewsView()
                .tabItem { Label("News", systemImage: "newspaper.fill") }
            NavigationStack { AccountView() }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    HomeView().environmentObject(AppModel())
}
