import SwiftUI

/// The logged-in tab shell. Chat is the primary tab — it's how the community
/// has always interacted — followed by Capital, Fantasy, News, and Account.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            ChatHomeView().tag(0)
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            CapitalView().tag(1)
                .tabItem { Label("Capital", systemImage: "bolt.fill") }
            FantasyView().tag(2)
                .tabItem { Label("Fantasy", systemImage: "football.fill") }
            NewsView().tag(3)
                .tabItem { Label("News", systemImage: "newspaper.fill") }
            NavigationStack { AccountView() }.tag(4)
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        // Selected tab = interactive state → brand blue (green is reserved for
        // "good", lime is too light for small tab items). Tactile tick on switch.
        .tint(.brandBlue)
        .sensoryFeedback(.selection, trigger: model.selectedTab)
    }
}

#Preview {
    HomeView().environmentObject(AppModel())
}
